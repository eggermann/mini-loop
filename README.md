# Mini Loop Memory Scrum

Mini-Loop is a Codex skill and shell toolkit for GOAL-driven planning, implementation, review, retrospective, and durable project memory.

Project intent lives in an independent sibling Git repository named `.mlms-<canonical-app-folder>`. For `workspace/my-app`, memory lives in `workspace/.mlms-my-app`. Linked worktrees share that repository; application and MLMS histories stay separate.

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

This resolves the canonical app repository and initializes its sibling MLMS Git repository. If embedded `.mlms/` already contains memory, use the safe migration helper:

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

Modes: `auto` (default), `guided`, `review`, and `init`. Autonomous runs remain bounded to five iterations. Child work inherits its execution budget; independently assigned worktrees use separate execution IDs and counters.

The workflow supports explicit branch/worktree subgoal assignments. Agents load shared project vision and accepted decisions plus only their assigned subgoal context. `select-context.sh` selects work; `reconcile-subgoal.sh` records merge evidence under lock. Git ancestry can prove a normal merge; branch deletion is not proof and uncertain squash state remains `unknown`. Reconciliation preserves acceptance criteria and leaves completion decisions to the Mini-Loop review.

Application and MLMS commits are separate and require permission under the configured policy. No automatic push or merge occurs. A Git merge alone never completes a parent GOAL.
