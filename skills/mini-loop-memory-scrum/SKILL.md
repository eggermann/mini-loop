---
name: mini-loop-memory-scrum
description: Initialize a Roo Code compatible memory bank from a user GOAL, create a project brief, and run a guarded Scrum/Vibe proactive code-control loop until goal is reached or blocked.
---

# Mini-Loop Memory Scrum Skill

Use this skill when user wants to start or continue a project with persistent project memory, Roo Code Memory Bank compatibility, Codex compatibility, Scrum/Vibe workflow, project brief creation, sprint-style reviews, retrospectives, proactive code-control, or guarded auto-commit loops.

## Trigger

Use this skill when user mentions:

- `GOAL:`
- memory bank
- Roo Code Memory Bank
- scrum-vibe-flow
- mini-loop
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

## Core Loop

Always work in this rhythm:

`GOAL -> Project Brief -> Memory Bank Init -> Sprint Plan -> Implement Small Slice -> Run Checks -> Review -> Retrospective -> Update Memory Bank -> Commit if green and permitted -> Next Loop`

Do not skip review, retrospective, or memory updates.

## Repository Setup

At start of a project, inspect repository.

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

## Project Brief

Create or update `projectBrief.md` with:

```md
# Project Brief
## Goal
<user GOAL>
## Problem
<what pain, opportunity, or missing capability this addresses>
## Desired Outcome
<what should be true when the project succeeds>
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
- The requested behavior is implemented.
- Relevant tests or checks pass.
- The memory bank is updated.
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
After meaningful work:
1. Update `memory-bank/activeContext.md`.
2. Update `memory-bank/progress.md`.
3. Update `memory-bank/decisionLog.md` if a decision was made.
4. Update `memory-bank/sprintReview.md` after review.
5. State next recommended action.
```

## Proactive Code-Control Loop

When user asks for autonomous progress, proactive code control, or auto-commit, run this loop until GOAL is reached, blocked, or loop budget is exhausted.

Default budget:

- `max_loops: 5`
- `auto_commit: ask-first`
- `auto_push: never`
- `auto_merge: never`
- `destructive_changes: ask-first`
- `large_dependencies: ask-first`

## Loop Contract

For each iteration:

1. Read `projectBrief.md`.
2. Read all `memory-bank/*.md` files.
3. Select smallest next backlog item.
4. Define acceptance criteria.
5. Implement only that slice.
6. Run available checks:
   - tests
   - lint
   - typecheck
   - build
   - manual verification when no automated checks exist
7. Review diff against GOAL.
8. Update memory bank files.
9. Commit only if slice is coherent, checks pass, and auto-commit permission exists.
10. Continue to next slice.

## Stop Conditions

Stop when any of these is true:

- GOAL is satisfied.
- Required clarification blocks progress.
- Tests/checks fail and cannot be fixed within current loop.
- Change would require destructive action.
- Change would require a large dependency or architecture shift.
- Maximum loop count is reached.
- Repository has unrelated dirty changes that should not be touched.
- Next step requires pushing, deploying, publishing, or merging.

## Auto-Commit Policy

Default: ask before first auto-commit.

If user grants permission:

- Commit after each green vertical slice.
- Never commit failing tests unless user explicitly requested a WIP commit.
- Never include unrelated files.
- Use clear commit messages.
- Update memory bank before committing.
- Include memory-bank updates in same commit when they describe completed slice.
- Never auto-push.

## Commit Message Format

```text
<type>: <short summary>
Goal: <current goal>
Loop: <loop number>
Checks: <tests/lint/build/manual verification>
```

## Mini-Loop Planning Output

Use:

```md
## Mini-Loop Plan
### Sprint Goal
<one sentence>
### Backlog
1. <small task>
2. <small task>
3. <small task>
### Acceptance Criteria
- ...
- ...
### Verification
- Command/check:
- Manual review:
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

## Retrospective Format

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

Use these tags when useful:

- `@vibe` exploratory implementation or prototype
- `@arch` architecture / structure / design decision
- `@control` review, constraints, acceptance criteria, quality gate
- `@debug` investigation or bug loop
- `@ship` release, polish, final checks
- `@retro` retrospective / process improvement

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
