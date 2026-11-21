"""Exercise the worker registry without an agent runtime or model calls."""

import argparse
import io
import json
import os
import runpy
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
        self.call("complete", "Done", "--evidence", "Parent tests", expected=1)
        ticket = self.call("begin", "worker", epoch, ticket)["ticket"]
        self.report("worker", ticket)
        self.call("accept", "worker", ticket, "Independent checks passed")
        self.call("complete", "Done", expected=2)
        self.call("complete", "Done", "--evidence", "Parent tests", expected=1)
        self.call("complete", "Done", "--evidence", "Parent tests passed", "--remaining", "None")
        archived = self.call("status", "--full")
        self.assertEqual(archived["verification"], "Parent tests passed")
        self.assertEqual(archived["workers"]["pending"]["status"], "cancelled")
        self.assertEqual(archived["workers"]["worker"]["review"], "Independent checks passed")

    def test_checkpoint_contention_preserves_both_workers(self):
        first = self.start("first")
        second = self.start("second", "cli")
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
        self.call("complete", "Stopped before integration", "--evidence", "Checks not run",
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
