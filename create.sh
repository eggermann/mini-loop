#!/usr/bin/env sh
set -eu

PROJECT_DIR="${1:-mini-loop}"
SKILL_DIR="$PROJECT_DIR/skills/mini-loop-memory-scrum"
TEMPLATES_DIR="$PROJECT_DIR/templates"
MEMORY_DIR="$TEMPLATES_DIR/memory-bank"
SCRIPT_PATH=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")

mkdir -p "$SKILL_DIR" "$MEMORY_DIR"

cp "$SCRIPT_PATH" "$PROJECT_DIR/create.sh"

cat > "$PROJECT_DIR/README.md" <<'EOF'
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

This creates `projectBrief.md`, `AGENTS.md`, and `memory-bank/*` only when missing.

## Start Prompt

```text
Use the mini-loop-memory-scrum skill.
GOAL:
<what we are building, fixing, or improving>
Mode:
autonomous mini-loop
Rules:
- Read projectBrief.md and memory-bank before work.
- Build smallest useful plan.
- Implement one small vertical slice at a time.
- Run tests, lint, typecheck, and build when available.
- Review diff before any commit.
- Update memory bank after meaningful work.
- Do not auto-commit unless I approve.
- Do not push.
- Stop when goal is reached, blocked, unsafe, or after 5 loops.
```
EOF

cat > "$PROJECT_DIR/install-skill.sh" <<'EOF'
#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_DIR="$SCRIPT_DIR/skills/mini-loop-memory-scrum"
TARGET_DIR="${CODEX_HOME:-$HOME/.codex}/skills/mini-loop-memory-scrum"

if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
  echo "Missing source skill: $SOURCE_DIR/SKILL.md" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET_DIR")"
rm -rf "$TARGET_DIR"
cp -R "$SOURCE_DIR" "$TARGET_DIR"

echo "Installed skill to: $TARGET_DIR"
EOF

cat > "$PROJECT_DIR/init-project-memory.sh" <<'EOF'
#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TEMPLATE_DIR="$SCRIPT_DIR/templates"
TARGET_DIR="${1:-.}"

mkdir -p "$TARGET_DIR"

copy_if_missing() {
  src="$1"
  dest="$2"

  if [ -e "$dest" ]; then
    echo "skip $dest"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo "create $dest"
}

copy_if_missing "$TEMPLATE_DIR/projectBrief.md" "$TARGET_DIR/projectBrief.md"
copy_if_missing "$TEMPLATE_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/activeContext.md" "$TARGET_DIR/memory-bank/activeContext.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/productContext.md" "$TARGET_DIR/memory-bank/productContext.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/progress.md" "$TARGET_DIR/memory-bank/progress.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/decisionLog.md" "$TARGET_DIR/memory-bank/decisionLog.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/systemPatterns.md" "$TARGET_DIR/memory-bank/systemPatterns.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/sprintReview.md" "$TARGET_DIR/memory-bank/sprintReview.md"
EOF

cat > "$TEMPLATES_DIR/projectBrief.md" <<'EOF'
# Project Brief

## Goal

<TODO: user GOAL>

## Problem

<TODO: what pain, opportunity, or missing capability this addresses>

## Desired Outcome

<TODO: what should be true when the project succeeds>

## Users / Stakeholders

<TODO>

## Scope

### In Scope

- TODO

### Out of Scope

- TODO

## Constraints

- Technical:
- Product:
- Time:
- Quality:
- Security:

## Definition of Done

- The requested behavior is implemented.
- Relevant tests or checks pass.
- The memory bank is updated.
- Review notes are captured.
- Retrospective notes are captured.
- Next action is clear.

## Open Questions

- TODO
EOF

cat > "$TEMPLATES_DIR/AGENTS.md" <<'EOF'
# AGENTS.md

## Codex Workflow

Before doing implementation work:

1. Read `projectBrief.md`.
2. Read all files in `memory-bank/`.
3. Identify current loop phase from `memory-bank/activeContext.md`.

During work:

1. Keep changes small.
2. Prefer a vertical slice over broad unfinished edits.
3. Record important architectural or product decisions.
4. Run available tests, lint, typecheck, and build checks when possible.
5. Review diff before proposing a commit.
6. Do not push automatically.
7. Do not delete files without explicit user approval.

After meaningful work:

1. Update `memory-bank/activeContext.md`.
2. Update `memory-bank/progress.md`.
3. Update `memory-bank/decisionLog.md` if a decision was made.
4. Update `memory-bank/sprintReview.md` after review.
5. State next recommended action.

## Auto-Commit Policy

Auto-commit is allowed only after user grants permission.

When enabled:

- Commit after each green vertical slice.
- Never commit failing checks unless user explicitly requests a WIP commit.
- Never include unrelated files.
- Update memory bank before committing.
- Do not auto-push.
EOF

cat > "$MEMORY_DIR/productContext.md" <<'EOF'
# Product Context

## Purpose

<TODO>

## Users

<TODO>

## Core Value

<TODO>

## Current Scope

<TODO>

## Non-Goals

<TODO>
EOF

cat > "$MEMORY_DIR/activeContext.md" <<'EOF'
# Active Context

## Current Goal

<TODO: user GOAL>

## Current Loop

Loop: 1
Phase: Planning

## Current Focus

Initialize project brief, memory bank, and first mini-loop.

## Assumptions

- User wants a small iterative workflow.
- Memory bank files should be kept in-repo.
- Auto-push is disabled by default.

## Risks / Unknowns

- Exact implementation stack may be unknown.
- Test/check commands may need discovery.

## Next Action

Create sprint backlog for loop 1.
EOF

cat > "$MEMORY_DIR/progress.md" <<'EOF'
# Progress

## Done

- Memory bank template created.

## In Progress

- Mini-loop planning.

## Next

- Create sprint backlog.
- Implement smallest useful slice.
- Review result.
EOF

cat > "$MEMORY_DIR/decisionLog.md" <<'EOF'
# Decision Log

## Decisions

### D-0001: Use Memory Bank + Scrum/Vibe Mini-Loop

Status: Accepted

Context:
Project needs persistent context across Codex/Roo sessions and repeatable development rhythm.

Decision:
Use a `memory-bank/` directory for durable context and a Scrum/Vibe mini-loop for planning, implementation, review, retrospective, and memory updates.

Consequences:
Codex must read and update `memory-bank/` files during each loop.
EOF

cat > "$MEMORY_DIR/systemPatterns.md" <<'EOF'
# System Patterns

## Working Pattern

Use small vertical slices:

1. Clarify intent.
2. Plan smallest useful increment.
3. Implement.
4. Test or verify.
5. Review.
6. Update memory.
7. Commit if green and permitted.

## Quality Pattern

Every loop should include:

- acceptance criteria
- implementation notes
- verification
- review notes
- retrospective notes
- next step

## Safety Pattern

Ask before:

- deleting files
- rewriting large documents
- changing public APIs
- adding large dependencies
- pushing commits
EOF

cat > "$MEMORY_DIR/sprintReview.md" <<'EOF'
# Sprint Review

## Loop Reviews

No reviews yet.
EOF

cat > "$SKILL_DIR/SKILL.md" <<'EOF'
---
name: mini-loop-memory-scrum
description: Initialize a Codex-compatible memory bank from a user GOAL, create a project brief, and run a guarded Scrum/Vibe autonomous mini-loop until goal is reached or blocked.
---

# Mini-Loop Memory Scrum Skill

Use this skill when user wants persistent project memory, Roo Code Memory Bank compatibility, Scrum/Vibe planning-review-retro flow, autonomous build-plan-review loops, or guarded auto-commit after green checks.

## Trigger

Use this skill when user mentions:

- `GOAL:`
- memory bank
- Roo Code Memory Bank
- scrum-vibe-flow
- mini-loop
- autonomous loop
- proactive code control
- auto-commit loop
- project brief initialization
- sprint review loop

If user did not provide a clear goal, ask:

```text
GOAL:
What are we building, fixing, or improving?
```

If user already provided a clear goal, do not ask again.

## Repository Setup

At start of project, inspect repository.

If missing, create:

- `projectBrief.md`
- `memory-bank/`
- `memory-bank/activeContext.md`
- `memory-bank/productContext.md`
- `memory-bank/progress.md`
- `memory-bank/decisionLog.md`
- `memory-bank/systemPatterns.md`
- `memory-bank/sprintReview.md`
- `AGENTS.md`

Do not overwrite substantial existing files without preserving content.

## Core Loop

Always work in this bounded rhythm:

`GOAL -> read context -> build plan -> implement smallest slice -> run tests/build/lint/typecheck -> review diff -> update memory bank -> commit if green and permitted -> continue or stop`

Do not skip review, retrospective, or memory updates.

## Default Autonomous Settings

- `max_loops: 5`
- `auto_commit: ask-first`
- `auto_push: never`
- `auto_merge: never`
- `auto_delete: never`
- `require_green_checks: true`
- `require_review_before_commit: true`
- `require_memory_update: true`

## Context Read Order

Before each loop:

1. Read `projectBrief.md`.
2. Read all `memory-bank/*.md` files.
3. Inspect dirty working tree state.
4. Identify current loop phase from `memory-bank/activeContext.md`.

## Loop Contract

For each iteration:

1. Restate current GOAL.
2. Select smallest next backlog item.
3. Define acceptance criteria.
4. Implement only that slice.
5. Run available checks:
   - tests
   - lint
   - typecheck
   - build
   - manual verification when no automated checks exist
6. Review diff against GOAL and acceptance criteria.
7. Update memory bank files.
8. Commit only if checks are green, review is coherent, memory is updated, and user permission exists.
9. Continue to next slice or stop.

## Stop Conditions

Stop when any of these is true:

- Goal is satisfied.
- Blocked by missing info.
- Checks fail and cannot be fixed safely.
- Destructive action is required.
- Large dependency is required.
- Unrelated dirty changes exist.
- Max loop count is reached.

## Project Brief

Create or update `projectBrief.md` with:

```md
# Project Brief
## Goal
<user GOAL>
## Problem
<what pain, opportunity, or missing capability this addresses>
## Desired Outcome
<what should be true when project succeeds>
## Users / Stakeholders
<who benefits or uses result>
## Scope
### In Scope
- ...
### Out of Scope
- ...
## Constraints
- Technical:
- Product:
- Time:
- Quality:
- Security:
## Definition of Done
- Requested behavior is implemented.
- Relevant tests or checks pass.
- Memory bank is updated.
- Review notes are captured.
- Retrospective notes are captured.
- Next action is clear.
## Open Questions
- ...
```

Use reasonable assumptions when details are unknown. Label them as assumptions.

## Memory Bank Files

`memory-bank/productContext.md`

```md
# Product Context
## Purpose
<summary of project purpose>
## Users
<target users>
## Core Value
<why this matters>
## Current Scope
<current scope>
## Non-Goals
<what not to build yet>
```

`memory-bank/activeContext.md`

```md
# Active Context
## Current Goal
<current GOAL>
## Current Loop
Loop: 1
Phase: Planning
## Current Focus
<what Codex is working on now>
## Assumptions
- ...
## Risks / Unknowns
- ...
## Next Action
<single next action>
```

`memory-bank/progress.md`

```md
# Progress
## Done
- Initialized project brief.
- Initialized memory bank.
## In Progress
- Mini-loop planning.
## Next
- Create sprint backlog.
- Implement smallest useful slice.
- Review result.
```

`memory-bank/decisionLog.md`

```md
# Decision Log
## Decisions
### D-0001: Use Memory Bank + Scrum/Vibe Mini-Loop
Status: Accepted
Context:
Project needs persistent context across sessions and repeatable development rhythm.
Decision:
Use a memory-bank directory for durable context and a Scrum/Vibe mini-loop for planning, implementation, review, retrospective, and memory updates.
Consequences:
Codex must read and update memory-bank files during each loop.
```

`memory-bank/systemPatterns.md`

```md
# System Patterns
## Working Pattern
Use small vertical slices:
1. Clarify intent.
2. Plan smallest useful increment.
3. Implement.
4. Test or verify.
5. Review.
6. Update memory.
7. Commit if green and permitted.
## Quality Pattern
Every loop should include:
- acceptance criteria
- implementation notes
- verification
- review notes
- retrospective notes
- next step
```

`memory-bank/sprintReview.md`

```md
# Sprint Review
## Loop Reviews
No reviews yet.
```

## AGENTS.md

If missing, create:

```md
# AGENTS.md
## Codex Workflow
Before doing implementation work:
1. Read `projectBrief.md`.
2. Read all files in `memory-bank/`.
3. Identify current loop phase from `memory-bank/activeContext.md`.
During work:
1. Keep changes small.
2. Prefer a vertical slice over broad unfinished edits.
3. Record important architectural or product decisions.
4. Run available tests/checks when possible.
5. Review diff before proposing commit.
After meaningful work:
1. Update `memory-bank/activeContext.md`.
2. Update `memory-bank/progress.md`.
3. Update `memory-bank/decisionLog.md` if a decision was made.
4. Update `memory-bank/sprintReview.md` after review.
5. State next recommended action.
```

## Code-Control Review

Before committing, perform:

```md
## Code-Control Review
### Goal Match
- Does this change move project toward GOAL?
### Diff Scope
- Are only relevant files changed?
### Quality
- Do tests/checks pass?
- Is implementation minimal?
- Is there avoidable complexity?
### Memory
- Was `memory-bank/activeContext.md` updated?
- Was `memory-bank/progress.md` updated?
- Was `memory-bank/decisionLog.md` updated if needed?
- Was `memory-bank/sprintReview.md` updated?
### Decision
- Commit
- Fix first
- Stop and ask user
```

## Review Format

Append to `memory-bank/sprintReview.md`:

```md
## Loop <N> Review
### What Changed
- ...
### Acceptance Criteria Result
- [x] ...
- [ ] ...
### Verification Result
- ...
### Issues / Gaps
- ...
### User Demo Notes
- ...
```

Append after each loop:

```md
## Loop <N> Retrospective
### What Worked
- ...
### What Was Confusing
- ...
### What To Improve Next Loop
- ...
### Process Decision
- Continue / Adjust / Stop
```

## Scrum/Vibe Tags

- `@vibe`
- `@arch`
- `@control`
- `@debug`
- `@ship`
- `@retro`

## Output Style

Always show:

1. What was initialized or changed.
2. Current loop phase.
3. Checks run.
4. Files created or updated.
5. Commit status.
6. Next action.

Be concise and operational.

## Safety Rules

Ask before:

- deleting files
- rewriting large existing documents
- changing public APIs
- adding large dependencies
- pushing commits
- merging branches
- deploying
- publishing packages

For normal setup files like `projectBrief.md`, `memory-bank/*`, and `AGENTS.md`, proceed without asking unless user forbids it.
EOF

chmod +x "$PROJECT_DIR/create.sh" "$PROJECT_DIR/install-skill.sh" "$PROJECT_DIR/init-project-memory.sh"

echo "Created project at $PROJECT_DIR"
