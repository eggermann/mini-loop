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

In the rules below, **context root** means `.mlms` for the main goal and the
active `.mlms/subgoals/<NNN-slug>` directory for a child goal. Paths described
as `<context-root>/...` must always resolve against that active context.

## Nested Mini-Loops and Linear Subgoals

Do not infer nesting from the existence of `.mlms` alone. Treat a repeated
invocation as a **subgoal** only when all of these are true:

1. The current context records a parent GOAL that is not completed, cancelled,
   or superseded.
2. The new GOAL is narrower than the parent GOAL.
3. Completing the new GOAL directly unblocks or advances that parent GOAL.

Otherwise, resume the existing goal, replace it as explicitly requested, or
ask whether the new GOAL is a replacement or child when intent is ambiguous.
The parent GOAL remains the authority for scope and completion.

Use nested loops only for work that can be completed independently and then
unblocks the parent in a linear order. Do not create sibling subgoals that need
to be worked on in parallel, and do not create a subgoal merely to restate a
normal backlog item.

### Subgoal Layout

Create a transient child context under the current memory root:

```text
.mlms/
  subgoals/
    001-<short-slug>/
      subgoal.md
      projectBrief.md
      AGENTS.md
      memory-bank/
```

For deeper nesting, use the active child context as the current memory root,
so its children live in `.../subgoals/<id>/subgoals/`. Number siblings in
creation order with zero-padded numbers. If one child has status `active`,
resume it first. Otherwise activate only the lowest-numbered `pending` child.
All later siblings remain pending until earlier work is completed or explicitly
skipped.

`subgoal.md` must contain:

```md
# Subgoal
## Parent Goal
<verbatim parent GOAL>
## Goal
<small, independently verifiable subgoal>
## Why Now
<how completion unblocks parent>
## Status
pending | active | completed | skipped | cancelled | superseded
## Acceptance Criteria
- ...
## Handoff to Parent
<result, verification, and next parent action>
```

Initialize the child `projectBrief.md`, `AGENTS.md`, and `memory-bank/*` using
the normal templates, but set its Current Goal to the subgoal and record the
parent GOAL and child path in its active context. Read parent project brief,
parent active context, and preceding sibling handoffs before starting it.

### Execution and Handoff

Run the normal bounded loop inside the active child. A child may finish only
when its acceptance criteria and relevant checks are satisfied. Then:

1. Mark `subgoal.md` as `completed`.
2. Record its result, verification, and recommended next action in `Handoff to Parent`.
3. Copy a concise handoff into the parent `progress.md`, `activeContext.md`,
   and `sprintReview.md`.
4. Resume the next pending sibling, or resume the parent loop.

If a child is blocked, record the blocker in both child and parent contexts and
stop; never silently bypass it. A child cannot mark the parent GOAL complete.

Nested invocations share the root loop budget; creating a child never resets
`max_loops`. Before every parent or child iteration, increment `Used` in the
root `.mlms/memory-bank/activeContext.md` Shared Loop Budget. Never decrement
or replace this counter from a child context. Default maximum nesting depth is
3. At budget or depth limit, preserve all contexts, record the stop reason in
parent and active child, and stop.

### Parent Completion Cleanup

Subgoal folders are transient execution context. When the parent GOAL is
completed, first retain a concise completion/handoff summary in the parent
memory bank. Before cleanup, mark every unfinished child as `cancelled` or
`superseded`, record why it is no longer required, and include that disposition
in the parent summary. Then remove that parent's generated `subgoals/`
directory.

This lifecycle cleanup is the sole exception to `auto_delete: never`. It is
allowed only for subgoal folders generated by this workflow; never remove
user-created files or the parent `.mlms` memory bank. If the parent stops
blocked or incomplete, keep all subgoal folders intact for resumption.

## Core Loop

Always work in this bounded rhythm:

`GOAL -> read context -> build plan -> implement smallest slice -> run tests/build/lint/typecheck -> review diff -> update memory bank -> commit if green and permitted -> continue or stop`

Do not skip review, retrospective, or memory updates.

## Default Autonomous Settings

- `max_loops: 5`
- `max_subgoal_depth: 3`
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

1. Read the current context's `projectBrief.md`.
2. Read all files in the current context's `memory-bank/`.
3. Inspect dirty working tree state.
4. Identify current loop phase from the current context's `memory-bank/activeContext.md`.
5. For a subgoal, also read its parent brief/active context and preceding sibling handoffs.

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

Create or update `<context-root>/projectBrief.md` with:

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

Store the file under `<context-root>/projectBrief.md`.

## Memory Bank Files

`<context-root>/memory-bank/productContext.md`

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

`<context-root>/memory-bank/activeContext.md`

```md
# Active Context
## Current Goal
<current GOAL>
## Current Loop
Loop: 1
Phase: Planning
## Shared Loop Budget
Root Context: .mlms
Used: 0
Maximum: 5
## Current Focus
<what Codex is working on now>
## Assumptions
- ...
## Risks / Unknowns
- ...
## Next Action
<single next action>
```

`<context-root>/memory-bank/progress.md`

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

`<context-root>/memory-bank/decisionLog.md`

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

`<context-root>/memory-bank/systemPatterns.md`

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

`<context-root>/memory-bank/sprintReview.md`

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
1. Resolve the active context root: `.mlms` for main goal or active child directory.
2. Read `<context-root>/projectBrief.md`.
3. Read all files in `<context-root>/memory-bank/`.
4. Identify current loop phase from `<context-root>/memory-bank/activeContext.md`.
During work:
1. Keep changes small.
2. Prefer a vertical slice over broad unfinished edits.
3. Record important architectural or product decisions.
4. Run available tests/checks when possible.
5. Review diff before proposing commit.
After meaningful work:
1. Update `<context-root>/memory-bank/activeContext.md`.
2. Update `<context-root>/memory-bank/progress.md`.
3. Update `<context-root>/memory-bank/decisionLog.md` if a decision was made.
4. Update `<context-root>/memory-bank/sprintReview.md` after review.
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
- Was `<context-root>/memory-bank/activeContext.md` updated?
- Was `<context-root>/memory-bank/progress.md` updated?
- Was `<context-root>/memory-bank/decisionLog.md` updated if needed?
- Was `<context-root>/memory-bank/sprintReview.md` updated?
### Decision
- Commit
- Fix first
- Stop and ask user
```

## Review Format

Append to `<context-root>/memory-bank/sprintReview.md`:

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

- deleting files, except lifecycle cleanup of workflow-generated `subgoals/`
  after the parent GOAL is completed and summarized
- rewriting large existing documents
- changing public APIs
- adding large dependencies
- pushing commits
- merging branches
- deploying
- publishing packages

For normal setup files like `projectBrief.md`, `memory-bank/*`, and `AGENTS.md`, proceed without asking unless user forbids it.
