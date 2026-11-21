"""Exercise the worker registry without an agent runtime or model calls."""

import argparse
import io
import json
import os
import runpy
import signal
import subprocess
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
CHECKPOINT = json.dumps({"summary": "Slice finished", "evidence": "worker check output",
                         "progress": "ready for review", "next": "review", "blocker": ""})

# Run the real writer under the shared lock and stop at a specific persisted file.
STOP_AFTER_WRITE = """
import os, runpy, sys
script, suffix, *args = sys.argv[1:]
main = runpy.run_path(script)["main"]
original_write = main.__globals__["write_atomic"]
def stop_after_write(path, content):
    original_write(path, content)
    if path.as_posix().endswith(suffix):
        os._exit(97)
main.__globals__["write_atomic"] = stop_after_write
sys.exit(main(["--locked", *args]))
"""


class OrchestrationTest(unittest.TestCase):
    def setUp(self):
        workspace = tempfile.TemporaryDirectory()
        self.addCleanup(workspace.cleanup)
        self.app = Path(workspace.name).resolve() / "app"
        self.app.mkdir()
        subprocess.run(["git", "init", "-q", self.app], check=True)
        subprocess.run([ROOT / "init-project-memory.sh", self.app], check=True, capture_output=True)
        self.memory = self.app.parent / ".mlms-app"
        self.cli = [sys.executable, ROOT / "orchestrate.py"]
        self.call("init", "Parent goal")

    def call(self, *args, expected=0, payload=None, internal=False, locked_root=None):
        flags = ["--locked"] if internal else []
        env = os.environ.copy()
        env.pop("MLMS_LOCKED_ROOT", None)
        if locked_root is not None:
            env["MLMS_LOCKED_ROOT"] = str(locked_root)
        result = subprocess.run([*self.cli, *flags, self.app, "run", *map(str, args)],
                                env=env, input=payload, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, expected, (args, result.stdout, result.stderr))
        return json.loads(result.stdout) if expected == 0 else result.stderr

    def start(self, worker, backend="subagent"):
        self.call("reserve", worker, "Subgoal for " + worker)
        self.call("bind", worker, backend, worker + "-session")
        return self.call("begin", worker, 1, 0)["ticket"]

    def report(self, worker, ticket, outcome="candidate", payload=CHECKPOINT, expected=0):
        return self.call("report", worker, ticket, outcome, payload=payload, expected=expected)

    def close_run(self, *args, cursor=None, expected=0):
        if cursor is None:
            cursor = self.call("status")["cursor"]
        return self.call("complete", *args, "--cursor", cursor, expected=expected)

    def stop_after_write(self, suffix, *args):
        result = subprocess.run([ROOT / "mlms-lock.sh", self.app, "--", sys.executable, "-c",
                                 STOP_AFTER_WRITE, ROOT / "orchestrate.py", suffix,
                                 self.app, "run", *map(str, args)],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 97, (args, result.stdout, result.stderr))

    def test_stale_commands_cannot_change_newer_slices(self):
        first = self.start("worker")
        self.report("worker", first)
        self.call("rework", "worker", first, "Change requested")
        self.call("begin", "worker", 1, 0, expected=1)
        second = self.call("begin", "worker", 1, first)["ticket"]
        self.call("interrupt", "worker", first, "Old slice stopped", expected=1)
        self.call("guard", "worker", first, expected=1)
        self.report("worker", first, expected=1)
        self.call("guard", "worker", second)
        unverified = json.loads(CHECKPOINT)
        unverified["evidence"] = ""
        self.report("worker", second, payload=json.dumps(unverified), expected=1)
        self.report("worker", second)
        self.call("accept", "worker", first, "Old review", expected=1)
        self.call("rework", "worker", first, "Old review", expected=1)
        self.call("accept", "worker", second, "Independent review of current slice")
        record = self.call("status", "--worker", "worker")
        self.assertEqual(record["status"], "accepted")
        self.assertEqual(record["ticket"], second)
        self.assertEqual([item["ticket"] for item in record["checkpoints"]], [first, second])

    def test_pause_resume_and_blocked_completion(self):
        ticket = self.start("worker", "chat")
        self.call("reserve", "pending", "Independent work")
        self.call("pause", 1, "Need approval")
        self.call("guard", "worker", ticket, expected=1)
        self.call("resume", 1, "Approved", expected=1)
        self.call("interrupt", "worker", ticket, "Runtime confirmed stopped")
        self.call("resume", 1, "Approved", expected=1)
        pending_revision = self.call("status")["workers"]["pending"]["revision"]
        self.call("cancel", "pending", pending_revision, "Confirmed setup stopped")
        epoch = self.call("resume", 1, "Approved")["epoch"]
        self.call("pause", 1, "Stale pause", expected=1)
        self.call("pause", epoch, "Second decision")
        self.call("resume", 1, "Stale approval", expected=1)
        epoch = self.call("resume", epoch, "Second approval")["epoch"]
        self.call("begin", "worker", epoch - 1, ticket, expected=1)
        ticket = self.call("begin", "worker", epoch, ticket)["ticket"]
        self.report("worker", ticket, "blocked", expected=1)
        blocked = json.loads(CHECKPOINT)
        blocked["blocker"] = "Environment unavailable"
        self.report("worker", ticket, "blocked", json.dumps(blocked))
        self.close_run("Done", "--evidence", "Parent tests", expected=1)
        ticket = self.call("begin", "worker", epoch, ticket)["ticket"]
        blocked["blocker"] = "Required tool still unavailable"
        self.report("worker", ticket, "blocked", json.dumps(blocked))
        status = self.call("status")["workers"]["worker"]
        self.assertEqual(status["checkpoint"]["blocker"], blocked["blocker"])
        self.close_run("Done", "--evidence", "Parent tests", expected=1)
        ticket = self.call("begin", "worker", epoch, ticket)["ticket"]
        self.report("worker", ticket)
        self.call("accept", "worker", ticket, "Independent checks passed")
        self.close_run("Done", expected=2)
        self.close_run("Done", "--evidence", "Parent tests", expected=1)
        self.close_run("Done", "--evidence", "Parent tests passed", "--remaining", "None")
        archived = self.call("status", "--full")
        self.assertEqual(archived["verification"], "Parent tests passed")
        self.assertEqual(archived["workers"]["pending"]["status"], "cancelled")
        self.assertEqual(archived["workers"]["worker"]["review"], "Independent checks passed")

    def test_checkpoint_contention_preserves_both_workers(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            reservations = [pool.submit(self.call, "reserve", worker, "Work for " + worker)
                            for worker in ("first", "second")]
            for reservation in reservations:
                self.assertEqual(reservation.result()["status"], "reserved")
        self.call("bind", "first", "subagent", "first-session")
        self.call("bind", "second", "cli", "second-session")
        first = self.call("begin", "first", 1, 0)["ticket"]
        second = self.call("begin", "second", 1, 0)["ticket"]
        lock = self.memory.with_name(self.memory.name + ".update-lock")
        lock.mkdir()
        self.report("first", first, expected=75)
        self.assertEqual(self.call("status", "--worker", "first")["status"], "running")
        lock.rmdir()
        with ThreadPoolExecutor(max_workers=2) as pool:
            first_report = pool.submit(self.report, "first", first)
            second_report = pool.submit(self.report, "second", second)
            self.assertEqual(first_report.result()["status"], "candidate")
            self.assertEqual(second_report.result()["status"], "candidate")
        workers = self.call("status", "--full")["workers"]
        self.assertEqual({worker["status"] for worker in workers.values()}, {"candidate"})
        with ThreadPoolExecutor(max_workers=2) as pool:
            reviews = [pool.submit(self.call, "accept", worker, ticket, "Independent review " + worker)
                       for worker, ticket in (("first", first), ("second", second))]
            for review in reviews:
                self.assertEqual(review.result()["status"], "accepted")
        accepted = self.call("status", "--full")["workers"]
        self.assertEqual(set(accepted), {"first", "second"})
        for worker in ("first", "second"):
            self.assertEqual(accepted[worker]["review"], "Independent review " + worker)
            self.assertEqual(accepted[worker]["checkpoints"], workers[worker]["checkpoints"])

    def test_internal_mode_requires_lock_context(self):
        self.call("reserve", "worker", "Subgoal", expected=1, internal=True)
        self.call("reserve", "worker", "Subgoal", expected=1, internal=True, locked_root=self.memory)
        lock = self.memory.with_name(self.memory.name + ".update-lock")
        lock.mkdir()
        (lock / "owner").write_text(f"pid={os.getppid()}\n", encoding="utf-8")
        self.call("reserve", "worker", "Subgoal", expected=1, internal=True, locked_root=self.memory)
        self.assertEqual(self.call("status")["workers"], {})

    def test_cancellation_does_not_apply_to_changed_worker(self):
        reserved = self.call("reserve", "worker", "Prepare workspace")
        bound = self.call("bind", "worker", "cli", "running-session")
        self.call("cancel", "worker", reserved["revision"], "Setup failed", expected=1)
        self.assertEqual(self.call("status", "--worker", "worker")["status"], "ready")
        self.call("cancel", "worker", bound["revision"], "Runtime confirmed stopped")
        self.close_run("Stopped before integration", "--evidence", "Checks not run",
                       "--remaining", "Integration and tests")
        summary = self.call("status")
        self.assertEqual(summary["phase"], "complete")
        self.assertEqual(summary["result"], "Stopped before integration")
        self.assertEqual(summary["remaining"], "Integration and tests")
        self.assertEqual(self.call("status", "--full")["workers"]["worker"]["status"], "cancelled")
        # Older compact records kept remaining work only in the full archive.
        canonical = self.memory / "orchestration" / "run" / "run.json"
        legacy = json.loads(canonical.read_text(encoding="utf-8"))
        del legacy["remaining"]
        canonical.write_text(json.dumps(legacy), encoding="utf-8")
        self.assertEqual(self.call("status")["remaining"], "Integration and tests")

    def test_restart_recovers_lost_replies_and_preserves_accepted_work(self):
        ticket = self.start("worker")
        active = self.call("status", "--worker", "worker")
        self.assertEqual((active["status"], active["ticket"]), ("running", ticket))
        self.report("worker", ticket, payload="{", expected=1)
        self.assertEqual(self.call("status", "--worker", "worker"), active)

        # Discard command responses and recover state through a fresh CLI invocation.
        self.report("worker", ticket)
        candidate = self.call("status", "--worker", "worker")
        self.report("worker", ticket, expected=1)
        self.assertEqual(self.call("status", "--worker", "worker"), candidate)
        self.call("accept", "worker", ticket, "Coordinator checked the output")
        accepted = self.call("status", "--worker", "worker")
        self.call("accept", "worker", ticket, "Duplicate decision", expected=1)
        self.assertEqual(self.call("status", "--worker", "worker"), accepted)
        self.assertEqual(accepted["status"], "accepted")
        self.assertEqual(accepted["checkpoints"], candidate["checkpoints"])
        self.assertEqual(accepted["review"], "Coordinator checked the output")

    def test_completion_requires_the_reviewed_snapshot(self):
        reviewed = self.call("status", "--full")
        self.call("pause", 1, "Additional tests needed")
        self.call("resume", 1, "Tests are unavailable; record as unfinished")
        revision = self.call("reserve", "tests", "Required tests")["revision"]
        self.call("cancel", "tests", revision, "Test environment unavailable")
        current = self.call("status", "--full")
        self.call("complete", "Delivered", "--evidence", "Old coordinator review", expected=2)
        self.close_run("Delivered", "--evidence", "Old coordinator review", "--remaining", "None",
                       cursor=reviewed["cursor"], expected=1)
        self.assertEqual(self.call("status", "--full"), current)
        self.close_run("Delivery unverified", "--evidence", "Tests were not run",
                       "--remaining", "Required tests", cursor=current["cursor"])
        summary = self.call("status")
        self.assertEqual((summary["phase"], summary["verification"], summary["remaining"]),
                         ("complete", "Tests were not run", "Required tests"))

    def test_worker_exit_without_a_checkpoint_keeps_prior_work(self):
        with subprocess.Popen([sys.executable, "-c", "import sys; sys.stdin.read()"],
                              stdin=subprocess.PIPE) as runtime:
            self.call("reserve", "worker", "Work in two slices")
            self.call("bind", "worker", "cli", runtime.pid)
            previous = self.call("begin", "worker", 1, 0)["ticket"]
            self.report("worker", previous, "idle")
            ticket = self.call("begin", "worker", 1, previous)["ticket"]
            runtime.terminate()
            self.assertEqual(runtime.wait(timeout=5), -signal.SIGTERM)

        active = self.call("status")["workers"]["worker"]
        self.assertEqual((active["status"], active["ticket"], active["checkpoint"]["ticket"]),
                         ("running", ticket, previous))
        self.close_run("Delivered", "--evidence", "Prior slice", expected=1)
        interrupted = self.call("interrupt", "worker", ticket, "Observed process exit")
        self.report("worker", ticket, expected=1)
        self.call("cancel", "worker", interrupted["revision"], "No replacement runtime")
        archived = self.call("status", "--worker", "worker")
        self.assertEqual(archived["status"], "cancelled")
        self.assertEqual([checkpoint["ticket"] for checkpoint in archived["checkpoints"]], [previous])

    def test_interrupted_writes_leave_a_recoverable_state(self):
        self.stop_after_write("/run/run.json", "reserve", "worker", "Fix a regression")
        self.call("reserve", "worker", "Duplicate reservation", expected=1)
        self.stop_after_write("/run/run.json", "bind", "worker", "local-agent", "local-session")
        bound = self.call("status", "--worker", "worker")
        self.assertEqual((bound["status"], bound["backend"], bound["handle"]),
                         ("ready", "local-agent", "local-session"))
        self.call("bind", "worker", "local-agent", "other-session", expected=1)
        ticket = self.call("begin", "worker", 1, 0)["ticket"]
        claim = json.loads(CHECKPOINT)
        claim.update(summary="Worker claims completion", evidence="Required tests not run")
        self.report("worker", ticket, payload=json.dumps(claim))
        candidate = self.call("status", "--worker", "worker")
        self.assertEqual(candidate["status"], "candidate")
        self.assertNotIn("review", candidate)
        self.close_run("Delivered", "--evidence", "Worker claim", expected=1)

        self.call("rework", "worker", ticket, "Run the required tests first")
        ticket = self.call("begin", "worker", 1, ticket)["ticket"]
        self.report("worker", ticket)
        candidate = self.call("status", "--worker", "worker")
        self.stop_after_write("/archive/workers/worker.json", "accept", "worker", ticket, "Review")
        self.assertEqual(self.call("status", "--worker", "worker"), candidate)
        self.stop_after_write("/run/run.json", "accept", "worker", ticket, "Independent checks passed")
        reviewed = self.call("status", "--full")
        self.assertEqual(reviewed["workers"]["worker"]["review"], "Independent checks passed")

        args = ("complete", "Delivered", "--cursor", reviewed["cursor"], "--evidence", "Integration checks")
        self.stop_after_write("/archive/summary.md", *args)
        self.assertEqual(self.call("status", "--full"), reviewed)
        self.call(*args)
        completed = self.call("status", "--full")
        self.call(*args, expected=1)
        self.assertEqual(self.call("status", "--full"), completed)
        self.assertEqual(completed["workers"]["worker"], reviewed["workers"]["worker"])


class LockRetryTest(unittest.TestCase):
    def test_validate_input_before_lock_and_resend_on_contention(self):
        run_with_lock = runpy.run_path(str(ROOT / "orchestrate.py"))["run_with_lock"]
        args = argparse.Namespace(checkout="unused", command="report")
        with patch("subprocess.run") as lock, patch("time.sleep"):
            with patch("sys.stdin", io.StringIO("{")), self.assertRaises(ValueError):
                run_with_lock(args, [])
            lock.assert_not_called()
            lock.side_effect = [subprocess.CompletedProcess([], 75, stderr="busy"),
                                subprocess.CompletedProcess([], 0, stderr="")]
            with patch("sys.stdin", io.StringIO(CHECKPOINT)):
                self.assertEqual(run_with_lock(args, []), 0)
            self.assertEqual(lock.call_count, 2)
            for attempt in lock.call_args_list:
                self.assertEqual(json.loads(attempt.kwargs["input"]), json.loads(CHECKPOINT))


if __name__ == "__main__":
    unittest.main()
