# Mini Loop Memory Scrum

Mini-Loop is a Codex skill and shell toolkit for GOAL-driven planning, implementation, review, retrospective, and durable project memory.

Project intent lives in an independent Git repository. By default, `workspace/my-app` uses `workspace/.mlms-my-app`. Linked worktrees share the same MLMS root.

### Choose a shared MLMS path

Set one absolute path outside the application worktrees in the application's local Git config:

```sh
git config --local mlms.root "$HOME/project-memory/my-app"
sh init-project-memory.sh .
```

Linked worktrees read the same setting. Separate clones on the same host can explicitly set the same path. They then share the MLMS repo and its write lock. Set or change the path between runs. If MLMS already exists and you want to move it, move or clone the **whole memory repository**, including its Git history, before pointing the application at the new location. Setting the path does not move existing data. Use `git config --local --unset-all mlms.root` to return to the default. The setting is local to each clone and is not pushed.

## Create Project Package

```sh
sh create.sh mini-loop-package
```

The generated package includes skill, runtime helpers, templates, and installers.

## Install Skill

Local install:

```sh
sh install-skill.sh
```

No-clone install:

```sh
curl -fsSL https://raw.githubusercontent.com/eggermann/mini-loop/main/install-from-github.sh | sh
```

Both install `SKILL.md`, runtime helpers, and templates into:

```sh
${CODEX_HOME:-$HOME/.codex}/skills/mini-loop-memory-scrum
```

Restart Codex after installation.

For another branch/fork, pass its raw base URL:

```sh
sh install-from-github.sh https://raw.githubusercontent.com/<owner>/<repo>/<branch>
```

## Initialize Project Memory

From an application checkout:

```sh
/path/to/mini-loop/init-project-memory.sh .
```

This resolves the canonical app repository and initializes its configured or default MLMS Git repository. If embedded `.mlms/` already contains memory, use the safe migration helper:

```sh
/path/to/mini-loop/migrate-project-memory.sh .
```

Migration preserves original files, refuses conflicting destination content, and never deletes legacy `.mlms/`.

## Start a Mini-Loop

```text
Use the mini-loop-memory-scrum skill.
GOAL:
<what we are building, fixing, or improving>
Mode:
auto
```

Modes: `auto` (default), `guided`, `review`, and `init`. `orchestrate` is an alias for `auto`. Autonomous work continues as long as there is a safe next step that can make verifiable progress. The coordinator manages subgoals when needed and pauses for decisions. There is no fixed five-round limit.

### Coordinate subgoals across workers

Mini-Loop coordinates work, not chats. A subgoal describes the work, a worker ID identifies its assigned participant within the run, and a runtime handle identifies where the worker runs. The execution environment starts workers through an authorized mechanism such as a Codex chat, subagent, CLI process, local agent, or external runtime. Creating or messaging a separate Codex chat still requires explicit user authorization. Workers need access to their assigned checkout and the same MLMS root.

With `Mode: auto`, independent subgoals run in parallel when delegation and isolated worktrees are available. Dependent work runs in order. The worker registry requires Python 3.8 or later. Each run counts one coordinator and up to 99 worker reservations, with up to three active worker slices at once. The coordinator records verified results in the project memory bank.

`status` shows open workers with their latest checkpoints. Use `status --since <cursor>` for subsequent polls and `status --full` for history. Accepted work and completed runs are archived inside MLMS. Archived workers still count toward the run limit.

A pause blocks new work and asks active workers to checkpoint. If a checkpoint is missing, verify the runtime has stopped the worker before recording an interruption. See the [orchestration workflow](skills/mini-loop-memory-scrum/references/orchestration.md).

At closure, read `result`, `verification`, and `remaining` together. A `complete` run has settled worker assignments. Goal success depends on the coordinator's review of the integrated result against the parent criteria.

The workflow supports explicit branch/worktree subgoal assignments. Agents load shared project vision and accepted decisions plus only their assigned subgoal context. `select-context.sh` selects work; `reconcile-subgoal.sh` records merge evidence under lock. Git ancestry can prove a normal merge; branch deletion is not proof and uncertain squash state remains `unknown`. Reconciliation preserves acceptance criteria and leaves completion decisions to the Mini-Loop review.

Application and MLMS commits are separate and require permission under the configured policy. No automatic push or merge occurs. A Git merge alone never completes a parent GOAL.

## Run checks

```sh
sh tests/resolve-project.sh
python3 tests/test_orchestrate.py
```
