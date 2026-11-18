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

Modes: `auto` (default), `guided`, `review`, `init`, and `orchestrate`. The regular autonomous loop is bounded to five iterations per execution. In `orchestrate`, the main chat reviews subgoal checkpoints and pauses the run for user decisions.

### Coordinate subgoals across chats

Set `Mode:` to `orchestrate` and state whether to create Codex chats for subgoals and send them follow-ups. The mode requires Python 3.8 or later. The run can use up to 100 chats including the main chat, with up to three workers active at once. The main chat records verified results in the project memory bank.

A pause blocks new work through the coordinator and asks workers to checkpoint. Waiting for a checkpoint or manually interrupting a chat may be necessary when its backend cannot stop a running turn directly. See the [orchestration workflow](skills/mini-loop-memory-scrum/references/orchestration.md).

The workflow supports explicit branch/worktree subgoal assignments. Agents load shared project vision and accepted decisions plus only their assigned subgoal context. `select-context.sh` selects work; `reconcile-subgoal.sh` records merge evidence under lock. Git ancestry can prove a normal merge; branch deletion is not proof and uncertain squash state remains `unknown`. Reconciliation preserves acceptance criteria and leaves completion decisions to the Mini-Loop review.

Application and MLMS commits are separate and require permission under the configured policy. No automatic push or merge occurs. A Git merge alone never completes a parent GOAL.
