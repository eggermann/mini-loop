#!/usr/bin/env python3
"""Keep a Mini-Loop run and its worker checkpoints in the shared memory repo."""

import argparse
import json
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


MAX_CHATS = 100  # Includes the coordinator. Reservations count for the whole run.
PARALLEL_WORKERS = 3
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
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                     delete=False) as partial:
        try:
            json.dump(state, partial, ensure_ascii=False, indent=2)
            partial.write("\n")
            partial.close()
            Path(partial.name).replace(path)
        finally:
            Path(partial.name).unlink(missing_ok=True)


def running(state):
    return [record for record in state["workers"].values() if record["status"] == "running"]


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
    command = args.command
    workers = state["workers"]
    if command == "status":
        return {"chat_limit": MAX_CHATS, "chats_counted": 1 + len(workers),
                "parallel_workers": PARALLEL_WORKERS, **state}

    require(state["phase"] != "complete", "this run is complete")
    if command == "reserve":
        require(state["phase"] == "running", "dispatch paused")
        require(args.worker not in workers, "worker already reserved")
        require(1 + len(workers) < MAX_CHATS, "chat limit reached for this run")
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
                "wait for running workers and pending chat creation to settle")
        state["decisions"].append({"question": state.pop("question"),
                                   "paused_at": state.pop("paused_at"),
                                   "answer": args.decision, "at": timestamp()})
        state.update(phase="running", epoch=state["epoch"] + 1)
        return {"epoch": state["epoch"]}

    if command == "complete":
        require(state["phase"] == "running", "resolve the pause first")
        require(all(record["status"] in FINISHED for record in workers.values()),
                "settle all workers before completing the run")
        state.update(phase="complete", result=args.result)
        return {"phase": state["phase"]}

    require(args.worker in workers, "unknown worker")
    worker = workers[args.worker]
    status = worker["status"]
    if command == "bind":
        require(status == "reserved", "worker is not awaiting a chat")
        identity = (args.backend, args.host, args.handle)
        require(all((record.get("backend"), record.get("host"), record.get("handle")) != identity
                    for record in workers.values()), "chat already bound")
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
        recent = worker.get("checkpoints", [])
        worker.update(status=args.outcome, checkpoints=[*recent[-2:], entry])
    elif command == "interrupt":
        require(status == "running", "worker has no active slice")
        worker.update(status="interrupted", interruption=args.evidence)
    elif command == "accept":
        require(state["phase"] == "running" and status == "candidate",
                "a completion candidate can only be accepted while running")
        worker.update(status="accepted", review=args.evidence)
    elif command == "rework":
        require(state["phase"] == "running" and status == "candidate",
                "only a completion candidate can be sent back for rework")
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
    commands.add_parser("status")
    commands.add_parser("init").add_argument("goal", type=nonempty)
    commands.add_parser("pause").add_argument("question", type=nonempty)
    commands.add_parser("resume").add_argument("decision", type=nonempty)
    commands.add_parser("complete").add_argument("result", type=nonempty)
    for name in ("reserve", "bind", "begin", "guard", "report", "interrupt",
                 "accept", "rework", "cancel"):
        commands.add_parser(name).add_argument("worker", type=identifier)
    commands.choices["reserve"].add_argument("goal", type=nonempty)
    bind = commands.choices["bind"]
    bind.add_argument("backend", choices=("chat", "subagent"))
    bind.add_argument("handle", type=nonempty)
    bind.add_argument("--host", default="local")
    commands.choices["begin"].add_argument("epoch", type=int)
    commands.choices["guard"].add_argument("ticket", type=int)
    commands.choices["report"].add_argument("ticket", type=int)
    commands.choices["report"].add_argument("outcome", choices=("idle", "blocked", "candidate"))
    for name in ("interrupt", "accept", "rework", "cancel"):
        commands.choices[name].add_argument("evidence", type=nonempty)
    return parser.parse_args(argv)


def main(argv):
    under_lock = bool(argv and argv[0] == "--locked")
    args = parse(argv[1:] if under_lock else argv)
    path = memory_path(args.checkout, args.run)
    read_only = args.command in {"status", "guard"}
    if not under_lock and not read_only:
        return subprocess.call([str(SCRIPTS / "mlms-lock.sh"), args.checkout, "--",
                                sys.executable, str(Path(__file__).resolve()), "--locked", *argv])

    if args.command == "init":
        require(not path.exists(), "run already exists; resume it via status")
        state = {"run": args.run, "goal": args.goal, "phase": "running", "epoch": 1,
                 "workers": {}, "decisions": []}
        result = state
    else:
        require(path.is_file(), "run does not exist")
        state = json.loads(path.read_text(encoding="utf-8"))
        result = transition(state, args)

    if not read_only:
        save(path, state)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"orchestrate: {error}", file=sys.stderr)
        sys.exit(1)
