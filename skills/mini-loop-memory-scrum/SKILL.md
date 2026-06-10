---
name: mini-loop-memory-scrum
description: Initialize a Codex-compatible memory bank from a user GOAL, create a project brief, and run a guarded Scrum/Vibe autonomous mini-loop until goal is reached or blocked.
---

# Mini-Loop Memory Scrum Skill

Use this skill when user wants persistent project memory, Roo Code Memory Bank compatibility, Scrum/Vibe planning-review-retro flow, autonomous build-plan-review loops, or guarded auto-commit after green checks.

Unless user explicitly overrides behavior, treat this file as source of truth for loop rules, safety rules, commit rules, and stopping conditions. Do not require user to restate them in each prompt.

## Mode Flag

Support optional prompt flag:

```text
Mode:
<mode>
```

Available modes:

- `auto`: Default. Run bounded autonomous mini-loop using defaults in this file.
- `guided`: Build plan, implement one smallest useful slice, run checks, review diff, update memory, then stop and ask for direction.
- `review`: Review existing work, run available checks, inspect diff, update memory if useful, and do not run a broad implementation pass.
- `init`: Only initialize `.mlms/projectBrief.md`, `.mlms/AGENTS.md`, and `.mlms/memory-bank/*` in current repo. Do not run implementation loop.

If `Mode:` is omitted, use `auto`.

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

- `.mlms/projectBrief.md`
- `.mlms/AGENTS.md`
- `.mlms/memory-bank/`
- `.mlms/memory-bank/activeContext.md`
- `.mlms/memory-bank/productContext.md`
- `.mlms/memory-bank/progress.md`
- `.mlms/memory-bank/decisionLog.md`
- `.mlms/memory-bank/systemPatterns.md`
- `.mlms/memory-bank/sprintReview.md`

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

These defaults apply even when user prompt contains only:

```text
Use the mini-loop-memory-scrum skill.
GOAL:
<goal>
Mode:
auto
```

## Context Read Order

Before each loop:

1. Read `.mlms/projectBrief.md`.
2. Read all `.mlms/memory-bank/*.md` files.
3. Inspect dirty working tree state.
4. Identify current loop phase from `.mlms/memory-bank/activeContext.md`.

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

Create or update `.mlms/projectBrief.md` with:

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

Store the file under `.mlms/projectBrief.md`.

## Memory Bank Files

`.mlms/memory-bank/productContext.md`

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

`.mlms/memory-bank/activeContext.md`

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

`.mlms/memory-bank/progress.md`

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

`.mlms/memory-bank/decisionLog.md`

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

`.mlms/memory-bank/systemPatterns.md`

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

`.mlms/memory-bank/sprintReview.md`

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
1. Read `.mlms/projectBrief.md`.
2. Read all files in `.mlms/memory-bank/`.
3. Identify current loop phase from `.mlms/memory-bank/activeContext.md`.
During work:
1. Keep changes small.
2. Prefer a vertical slice over broad unfinished edits.
3. Record important architectural or product decisions.
4. Run available tests/checks when possible.
5. Review diff before proposing commit.
After meaningful work:
1. Update `.mlms/memory-bank/activeContext.md`.
2. Update `.mlms/memory-bank/progress.md`.
3. Update `.mlms/memory-bank/decisionLog.md` if a decision was made.
4. Update `.mlms/memory-bank/sprintReview.md` after review.
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
- Was `.mlms/memory-bank/activeContext.md` updated?
- Was `.mlms/memory-bank/progress.md` updated?
- Was `.mlms/memory-bank/decisionLog.md` updated if needed?
- Was `.mlms/memory-bank/sprintReview.md` updated?
### Decision
- Commit
- Fix first
- Stop and ask user
```

## Review Format

Append to `.mlms/memory-bank/sprintReview.md`:

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
