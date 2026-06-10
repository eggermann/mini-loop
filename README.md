# Mini Loop Memory Scrum

This project packages a Codex skill plus bootstrap scripts for an autonomous mini-loop workflow built around:

- Roo Code style Memory Bank project context
- Scrum/Vibe planning, review, and retrospective rhythm
- Autonomous build-plan-review loop
- Guarded auto-commit after green checks
- No auto-push by default

## Create Project

```sh
sh mini-loop/create.sh mini-loop
```

## Install Skill

```sh
sh install-skill.sh
```

Installs to:

```sh
${CODEX_HOME:-$HOME/.codex}/skills/mini-loop-memory-scrum
```

Then restart Codex.

## Initialize Memory In Another Repo

From target repo:

```sh
/path/to/mini-loop/init-project-memory.sh .
```

This creates `.mlms/projectBrief.md`, `.mlms/AGENTS.md`, and `.mlms/memory-bank/*` only when missing.

## Start Prompt

```text
Use the mini-loop-memory-scrum skill.
GOAL:
<what we are building, fixing, or improving>
Mode:
auto
```

Available `Mode:` flags:

- `auto` full autonomous mini-loop, default
- `guided` plan and implement one slice, then stop for user input
- `review` inspect, run checks, review diff, update memory if needed, no broad implementation pass
- `init` only initialize `.mlms/projectBrief.md`, `.mlms/AGENTS.md`, and `.mlms/memory-bank/*`

Behavior like context reading, small-slice planning, checks, review-before-commit, memory updates, no auto-push, and 5-loop max is built into the skill.
