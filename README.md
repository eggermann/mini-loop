# Mini Loop Memory Scrum

This project packages a ready-to-install Codex skill plus starter templates for a small iterative workflow built around:

- Roo Code style Memory Bank project context
- Scrum/Vibe mini-loop workflow
- Proactive code-control loop
- Guarded auto-commit after green slices
- Project brief initialization
- Sprint review and retrospective memory updates

## Install Skill

```sh
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
cp -R skills/mini-loop-memory-scrum "${CODEX_HOME:-$HOME/.codex}/skills/"
```

Then restart Codex.

## Use Prompt

```text
Use the mini-loop-memory-scrum skill.
GOAL:
<what we are building, fixing, or improving>
Mode:
proactive code-control loop
Rules:
- Initialize projectBrief.md and memory-bank if missing.
- Work in small vertical slices.
- Run checks after each slice.
- Update memory bank after each review.
- Commit each green slice after permission.
- Do not push.
- Stop when the GOAL is reached, blocked, or after 5 loops.
```

## Project Init

```text
Use the mini-loop-memory-scrum skill.
GOAL:
Initialize this repo with projectBrief.md, memory-bank, AGENTS.md, and run loop 1.
```
