#!/usr/bin/env python3
"""Keep a Mini-Loop run and its worker checkpoints in the shared memory repo."""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path


MAX_PARTICIPANTS = 100  # One coordinator plus all worker reservations for the run.
PARALLEL_WORKERS = 3
LOCK_RETRY_DELAYS = (0.1, 0.2)
SCRIPTS = Path(__file__).resolve().parent
FINISHED = {"accepted", "cancelled"}


def timestamp():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def identifier(value):
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}", value):
        raise argparse.ArgumentTypeError("use 1–80 letters, digits, hyphens or underscores")
    return value


def nonempty(value):
    if not value.strip():
        raise argparse.ArgumentTypeError("provide nonempty text")
    return value


def memory_path(checkout, run_id):
    identity = subprocess.check_output(
        [str(SCRIPTS / "resolve-project.sh"), checkout], text=True
    )
    root = Path(dict(line.split("=", 1) for line in identity.splitlines())["mlms_root"])
    git_root = subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "--show-toplevel"], text=True
    ).rstrip("\n")
    require(root.resolve() == Path(git_root).resolve() and not root.is_symlink(),
            "initialize the independent MLMS repository first")
    state_path = root / "orchestration" / run_id / "run.json"
    require(state_path.resolve() == state_path, "orchestration state must not be a symlink")
    return state_path


def save(path, state):
    write_atomic(path, json.dumps(state, ensure_ascii=False, indent=2) + "\n")


def write_atomic(path, content):
    require(path.resolve() == path, "orchestration files must not be symlinks")
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                     delete=False) as partial:
        try:
            partial.write(content)
            partial.close()
            Path(partial.name).replace(path)
        finally:
            Path(partial.name).unlink(missing_ok=True)


def running(state):
    return [record for record in state["workers"].values() if record["status"] == "running"]


def read_state(path):
    require(path.resolve() == path, "orchestration files must not be symlinks")
    return json.loads(path.read_text(encoding="utf-8"))


def worker_archive(path, worker_id):
    return path.parent / "archive" / "workers" / f"{identifier(worker_id)}.json"


def archive_terminal_work(path, state):
    if state.get("archived"):
        return state

    for worker_id, worker in state["workers"].items():
        if worker["status"] not in FINISHED or worker.get("archived"):
            continue
        save(worker_archive(path, worker_id), worker)
        keep = ("goal", "status", "backend", "host", "handle", "updated", "revision", "ticket")
        state["workers"][worker_id] = {
            **{key: worker[key] for key in keep if key in worker}, "archived": True,
        }

    if state["phase"] != "complete":
        return state

    archive = path.parent / "archive"
    save(archive / "run.json", state)
    lines = ["# " + state["run"], "", "Goal: " + state["goal"], "",
             "Result: " + state["result"], ""]
    if "verification" in state:
        lines.extend(["Verification: " + state["verification"], ""])
    lines.extend(["Open items: " + state.get("remaining", "See result."), "", "## Decisions"])
    for decision in state["decisions"]:
        lines.append(f'- {decision["question"]} → {decision["answer"]}')
    if not state["decisions"]:
        lines.append("- None recorded.")
    write_atomic(archive / "summary.md", "\n".join(lines) + "\n")
    # Keep the run ID, cursor and participant count available without loading its archive.
    keep = ("run", "goal", "phase", "epoch", "revision", "result", "verification")
    return {**{key: state[key] for key in keep if key in state}, "archived": True,
            "chats_counted": 1 + len(state["workers"])}


def status_view(path, state, args):
    revision = state.get("revision", 0)
    workers = state.get("workers", {})
    # Keep the existing count keys for status readers and archived runs.
    counts = {"chat_limit": MAX_PARTICIPANTS, "parallel_workers": PARALLEL_WORKERS,
              "chats_counted": state.get("chats_counted", 1 + len(workers))}
    if args.full or args.worker:
        if state.get("archived"):
            state = read_state(path.parent / "archive" / "run.json")
        workers = state["workers"]
        if args.worker:
            require(args.worker in workers, "unknown worker")
            workers = {args.worker: workers[args.worker]}
        details = {key: read_state(worker_archive(path, key)) if worker.get("archived") else worker
                   for key, worker in workers.items()}
        if args.worker:
            return details[args.worker]
        return {**counts, **state, "cursor": revision, "workers": details}

    if args.since is not None:
        require(0 <= args.since <= revision, "cursor is outside this run's revision range")
        if state.get("archived") and args.since < revision:
            workers = read_state(path.parent / "archive" / "run.json")["workers"]
    result = {**counts, "run": state["run"], "phase": state["phase"],
              "epoch": state["epoch"], "cursor": revision, "workers": {}}
    for field in ("question", "result", "verification"):
        if field in state:
            result[field] = state[field]
    if state["phase"] == "complete":
        result["archive_summary"] = "archive/summary.md" if state.get("archived") else None
    for key, worker in workers.items():
        if args.since is None:
            if worker["status"] in FINISHED:
                continue
        elif worker.get("revision", 0) <= args.since:
            continue
        fields = ("goal", "status", "ticket", "updated", "backend", "host", "handle", "interruption")
        row = {field: worker[field] for field in fields if field in worker}
        if worker.get("checkpoints"):
            row["checkpoint"] = worker["checkpoints"][-1]
        if worker.get("archived"):
            row["archived"] = True
        result["workers"][key] = row
    return result


def read_checkpoint():
    checkpoint = json.load(sys.stdin)
    fields = ("summary", "evidence", "progress", "next", "blocker")
    require(isinstance(checkpoint, dict), "checkpoint must be a JSON object")
    for field in fields:
        require(isinstance(checkpoint.get(field), str) and len(checkpoint[field]) <= 2000,
                f"checkpoint field {field} must be text of at most 2000 characters")
    for field in ("summary", "progress", "next"):
        require(checkpoint[field].strip(), f"checkpoint field {field} cannot be blank")
    return {field: checkpoint[field] for field in fields}


def transition(state, args):
    require(state["phase"] != "complete", "this run is complete")
    command = args.command
    workers = state["workers"]

    if command == "reserve":
        require(state["phase"] == "running", "dispatch paused")
        require(args.worker not in workers, "worker already reserved")
        require(1 + len(workers) < MAX_PARTICIPANTS, "participant limit reached for this run")
        workers[args.worker] = {"goal": args.goal, "status": "reserved",
                                "updated": timestamp(), "ticket": 0}
        return workers[args.worker]

    if command == "pause":
        require(state["phase"] == "running", "pause already requested")
        state.update(phase="paused", question=args.question, paused_at=timestamp())
        return {"awaiting_checkpoint": [key for key, record in workers.items()
                 if record["status"] in {"running", "reserved"}]}

    if command == "resume":
        require(state["phase"] == "paused", "run is not paused")
        require(not running(state) and not any(w["status"] == "reserved" for w in workers.values()),
                "wait for running workers and pending worker setup to settle")
        state["decisions"].append({"question": state.pop("question"),
                                   "paused_at": state.pop("paused_at"),
                                   "answer": args.decision, "at": timestamp()})
        state.update(phase="running", epoch=state["epoch"] + 1)
        return {"epoch": state["epoch"]}

    if command == "complete":
        require(state["phase"] == "running", "resolve the pause first")
        require(all(record["status"] in FINISHED for record in workers.values()),
                "settle all workers before completing the run")
        if any(record["status"] == "cancelled" for record in workers.values()):
            require(args.remaining is not None, "review cancelled work and explicitly record remaining items")
        state.update(phase="complete", result=args.result, verification=args.evidence,
                     remaining=args.remaining or "None recorded.")
        return {"phase": state["phase"]}

    require(args.worker in workers, "unknown worker")
    worker = workers[args.worker]
    status = worker["status"]
    if command == "bind":
        require(status == "reserved", "worker is not awaiting a runtime binding")
        identity = (args.backend, args.host, args.handle)
        require(all((record.get("backend"), record.get("host"), record.get("handle")) != identity
                    for record in workers.values()), "runtime session already bound")
        worker.update(backend=args.backend, host=args.host, handle=args.handle, status="ready")
    elif command == "begin":
        require(state["phase"] == "running" and args.epoch == state["epoch"],
                "dispatch paused or work order is out of date")
        require(status in {"ready", "idle", "blocked", "interrupted"},
                "worker cannot start another slice")
        require(len(running(state)) < PARALLEL_WORKERS, "parallel worker limit reached")
        worker.update(status="running", ticket=worker["ticket"] + 1, started=timestamp())
    elif command in {"guard", "report"}:
        require(status == "running" and worker["ticket"] == args.ticket,
                "worker has no matching active slice")
        if command == "guard":
            require(state["phase"] == "running", "pause requested: report and stop")
            return {"allowed": True, "ticket": args.ticket}
        checkpoint = read_checkpoint()
        if args.outcome == "candidate":
            require(checkpoint["evidence"].strip(), "a completion candidate needs evidence")
        if args.outcome == "blocked":
            require(checkpoint["blocker"].strip(), "a blocked checkpoint needs a reason")
        entry = {"ticket": args.ticket, "at": timestamp(), **checkpoint}
        worker.setdefault("checkpoints", []).append(entry)
        worker["status"] = args.outcome
    elif command == "interrupt":
        require(status == "running" and worker["ticket"] == args.ticket,
                "worker has no matching active slice")
        worker.update(status="interrupted", interruption=args.evidence)
    elif command == "accept":
        require(state["phase"] == "running" and status == "candidate" and worker["ticket"] == args.ticket,
                "accept needs the current candidate ticket and an unpaused run")
        worker.update(status="accepted", review=args.evidence)
    elif command == "rework":
        require(state["phase"] == "running" and status == "candidate" and worker["ticket"] == args.ticket,
                "rework needs the current candidate ticket and an unpaused run")
        worker.update(status="idle", review=args.evidence)
    elif command == "cancel":
        require(status not in FINISHED | {"running"}, "settle active work before cancelling")
        worker.update(status="cancelled", cancellation=args.evidence)
    worker["updated"] = timestamp()
    return worker


def parse(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkout")
    parser.add_argument("run", type=identifier)
    commands = parser.add_subparsers(dest="command", required=True)
    status = commands.add_parser("status")
    view = status.add_mutually_exclusive_group()
    view.add_argument("--since", type=int, metavar="CURSOR")
    view.add_argument("--full", action="store_true")
    view.add_argument("--worker", type=identifier)
    commands.add_parser("clean", help="archive finished work in existing runs")
    commands.add_parser("init").add_argument("goal", type=nonempty)
    commands.add_parser("pause").add_argument("question", type=nonempty)
    commands.add_parser("resume").add_argument("decision", type=nonempty)
    complete = commands.add_parser("complete")
    complete.add_argument("result", type=nonempty)
    complete.add_argument("--evidence", type=nonempty, required=True)
    complete.add_argument("--remaining", type=nonempty)
    for name in ("reserve", "bind", "begin", "guard", "report", "interrupt",
                 "accept", "rework", "cancel"):
        commands.add_parser(name).add_argument("worker", type=identifier)
    commands.choices["reserve"].add_argument("goal", type=nonempty)
    bind = commands.choices["bind"]
    bind.add_argument("backend", type=nonempty, help="runtime label, such as chat, subagent, or cli")
    bind.add_argument("handle", type=nonempty)
    bind.add_argument("--host", default="local")
    commands.choices["begin"].add_argument("epoch", type=int)
    for name in ("guard", "report", "interrupt", "accept", "rework"):
        commands.choices[name].add_argument("ticket", type=int)
    commands.choices["report"].add_argument("outcome", choices=("idle", "blocked", "candidate"))
    for name in ("interrupt", "accept", "rework", "cancel"):
        commands.choices[name].add_argument("evidence", type=nonempty)
    return parser.parse_args(argv)


def run_with_lock(args, argv):
    # Buffer and validate a report before acquiring the shared lock.
    payload = json.dumps(read_checkpoint()) if args.command == "report" else None
    command = [str(SCRIPTS / "mlms-lock.sh"), args.checkout, "--", sys.executable,
               str(Path(__file__).resolve()), "--locked", *argv]
    for delay in (*LOCK_RETRY_DELAYS, None):
        result = subprocess.run(command, input=payload, text=True, stderr=subprocess.PIPE)
        if result.returncode != 75 or delay is None:
            sys.stderr.write(result.stderr)
            return result.returncode
        time.sleep(delay)


def main(argv):
    under_lock = bool(argv and argv[0] == "--locked")
    args = parse(argv[1:] if under_lock else argv)
    read_only = args.command in {"status", "guard"}
    if under_lock:
        require(os.environ.get("MLMS_LOCKED_ROOT"), "internal update requires the MLMS lock")
    path = memory_path(args.checkout, args.run)
    if not under_lock and not read_only:
        return run_with_lock(args, argv)

    if args.command == "init":
        require(not path.exists(), "run already exists; resume it via status")
        state = {"run": args.run, "goal": args.goal, "phase": "running", "epoch": 1, "revision": 0,
                 "workers": {}, "decisions": []}
        result = {"run": args.run, "phase": "running", "epoch": 1, "cursor": 0}
    else:
        require(path.is_file(), "run does not exist")
        state = read_state(path)
        if args.command == "status":
            result = status_view(path, state, args)
        elif args.command == "clean":
            result = {"phase": state["phase"]}
        else:
            result = transition(state, args)
            if not read_only:
                state["revision"] = state.get("revision", 0) + 1
                if hasattr(args, "worker"):
                    worker = state["workers"][args.worker]
                    worker["revision"] = state["revision"]
                    fields = ("status", "ticket")
                    result = {"worker": args.worker, **{key: worker[key] for key in fields}}

    if not read_only:
        state = archive_terminal_work(path, state)
        save(path, state)
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"orchestrate: {error}", file=sys.stderr)
        sys.exit(1)
