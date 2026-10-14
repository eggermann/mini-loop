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
- `init`: Resolve canonical application identity, then initialize sibling MLMS context only when no legacy embedded memory requires migration. Do not run implementation loop.

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

If sibling MLMS is missing and no embedded legacy memory exists, initialize these at `<mlms-root>`:

- `projectBrief.md`
- `AGENTS.md`
- `memory-bank/`
- `memory-bank/activeContext.md`
- `memory-bank/productContext.md`
- `memory-bank/progress.md`
- `memory-bank/decisionLog.md`
- `memory-bank/systemPatterns.md`
- `memory-bank/sprintReview.md`

Do not overwrite substantial existing files without preserving content.

## Canonical Repository and Context Resolution

Installed runtime helpers live in `bin/`; templates live in `bin/templates/`.

Before reading project memory or implementation work:

1. Run installed `bin/resolve-project.sh` against current checkout.
2. Record `application_root`, current `branch` (or `DETACHED`), `worktree_root`, `git_common_dir`, and `mlms_root`.
3. Verify `mlms_root` is independent Git root. If identity is ambiguous, primary worktree missing, or Git roots disagree, stop without creating state.
4. If sibling is absent, inspect `<application_root>/.mlms`. If it contains memory, run `bin/migrate-project-memory.sh <worktree_root>`; otherwise run `bin/init-project-memory.sh <worktree_root>`.
5. Run `bin/select-context.sh <worktree_root>` to get `context_root`, `subgoal_id`, and stable `execution_id`. Never select by folder basename alone.
6. Load shared project vision and accepted decisions, then parent GOAL, assigned subgoal, relevant handoffs/dependencies, and that execution's budget. Do not load unrelated branch execution chatter.
7. Before each iteration, call `bin/loop-budget.sh <worktree_root> <execution-id> increment`. Nested work keeps inherited execution ID.

Application Git owns implementation history. Sibling MLMS Git owns project intent and Scrum state. They are separate repositories; never stage files across them. Use `bin/mlms-lock.sh <worktree-root> -- <update-command>` around MLMS mutations. Reconciliation uses `bin/reconcile-subgoal.sh <worktree-root> <subgoal-id> <target-branch>`. After meaningful MLMS changes, commit only with permission and explicit paths using `bin/mlms-commit.sh <worktree-root> <message> <mlms-relative-path>...`; it creates no commit for unchanged content.

In these rules, **MLMS root** means the resolver-provided sibling `.mlms-<canonical-repository-folder-name>`. **Context root** means that MLMS root for project-level work or the assigned `<mlms-root>/subgoals/<NNN-slug>` for a child. Every context path resolves from the selected root, never from the application checkout.

## Nested Mini-Loops and Subgoals

Do not infer nesting from the existence of an MLMS repository alone. Treat a repeated
invocation as a **subgoal** only when all of these are true:

1. The current context records a parent GOAL that is not completed, cancelled,
   or superseded.
2. The new GOAL is narrower than the parent GOAL.
3. Completing the new GOAL directly unblocks or advances that parent GOAL.

Otherwise, resume the existing goal, replace it as explicitly requested, or
ask whether the new GOAL is a replacement or child when intent is ambiguous.
The parent GOAL remains the authority for scope and completion.

Sibling subgoals may run in parallel only when each is intentionally assigned to an independent application branch/worktree. Record assignment in each existing `subgoal.md`; keep parent GOAL and accepted global decisions shared. An execution must select the unique active subgoal matching its current branch/worktree. If assignment is ambiguous or multiple subgoals match, stop and report conflict. Unassigned active subgoals do not become the default for every worktree.

Keep nested depth capped at 3. A child may create deeper children only within its own assigned work context. Preserve sibling creation order and linear activation for unassigned work.

### Subgoal Layout

Create child context under the active MLMS context root:

```text
<mlms-root>/
  subgoals/
    001-<short-slug>/
      subgoal.md
      projectBrief.md
      AGENTS.md
      memory-bank/
```

For deeper nesting, use active child context as current root, so children live in `.../subgoals/<id>/subgoals/`. Number siblings in creation order with zero-padded numbers. Unassigned sequential work resumes active child first, else lowest pending child. Explicitly assigned parallel children may both be active when branch/worktree assignments are distinct and non-conflicting.

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
## Git Assignment
- Application repository: ...
- Branch: ...
- Worktree: ...
- Base / target branch: ...
- Relevant commits: ...
- Merge status: not merged | merged | unknown
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

Each Mini-Loop execution has a stable execution ID and a separate budget record at `<mlms-root>/executions/<execution-id>/activeContext.md`. Independent branch/worktree executions use distinct records; a child inherits its parent execution ID and cannot reset `Used`. Before each iteration, acquire MLMS update lock, reload latest record, increment `Used`, validate, and release lock. `max_loops` stays 5; nesting depth stays 3. At budget/depth limit, preserve contexts and record stop reason in parent and active child.

### Parent Completion Cleanup

Subgoal folders are execution context. When the parent GOAL is
completed, first retain a concise completion/handoff summary in the parent
memory bank. Before cleanup, mark every unfinished child as `cancelled` or
`superseded`, record why it is no longer required, and include that disposition
in the parent summary. Then remove that parent's generated `subgoals/`
directory.

This lifecycle cleanup is the sole exception to `auto_delete: never`. It is
allowed only for subgoal folders generated by this workflow; never remove
user-created files or the parent MLMS memory bank. If parent stops blocked or
incomplete, keep all subgoal folders intact for resumption.


## Git Evidence and Decision Scope

Use Git as evidence for implementation association and merge state. Record relevant app repository, branch, worktree, commits, base/target branch, review, and merge evidence on the existing subgoal. Merge status is `merged`, `not merged`, or `unknown`. Use ancestry for normal merges. Branch deletion is never proof. A squash merge without reliable local evidence remains `unknown`.

At loop start, before planning after a successful implementation commit, and during review, run `bin/reconcile-subgoal.sh <worktree-root> <subgoal-id> <target-branch>` when local evidence is available. It updates existing subgoal evidence, progress, and sprint review idempotently under lock. Preserve handoff and acceptance criteria. Reconciliation leaves subgoal status active: evaluate criteria and verification yourself, then mark completed only if all conditions are met. Reevaluate parent GOAL; required remaining child work keeps it open. Merge never completes a subgoal or parent GOAL by itself.

Decision log keeps existing accepted decisions. Mark decisions as project-wide accepted, goal/subgoal scoped, branch proposal, or superseded. Preserve conflicting proposals and expose conflict; do not promote either to project-wide accepted until explicitly resolved. Accepted global decisions remain visible to every execution.

## Core Loop

Always work in this bounded rhythm:

`GOAL -> resolve app/worktree/MLMS -> read scoped context -> plan -> implement smallest slice -> run checks -> review diff -> lock/reload/update MLMS -> separately commit if permitted -> continue or stop`

Do not skip review, retrospective, or memory updates.

## Default Autonomous Settings

- `max_loops: 5`
- `max_subgoal_depth: 3`
- `auto_commit: ask-first` (legacy alias for application commits)
- `application_auto_commit: ask-first`
- `mlms_auto_commit: ask-first` (separate permission/policy)
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
7. Acquire MLMS update lock; reload latest state; apply only scoped changes; validate; release lock.
8. Commit application and MLMS repositories separately, only when each policy permits and checks/review are green. Never push or merge automatically.
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

The `Shared Loop Budget` section identifies the execution. Authoritative `Used` count lives at `<mlms-root>/executions/<execution-id>/activeContext.md`; child contexts inherit its ID and never reset it.

```md
# Active Context
## Current Goal
<current GOAL>
## Current Loop
Loop: 1
Phase: Planning
## Shared Loop Budget
MLMS Root: <resolved-sibling-mlms-root>
Execution ID: <stable-execution-id>
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
1. Resolve app root, branch, worktree, canonical sibling MLMS root, and active GOAL/subgoal.
2. Read `<mlms-root>/projectBrief.md`, shared accepted decisions, assigned parent/subgoal, relevant handoffs, and execution budget.
3. Identify current loop phase from active execution context.
4. Load only relevant branch/worktree execution detail; retain visibility of global accepted decisions.
During work:
1. Keep changes small.
2. Prefer a vertical slice over broad unfinished edits.
3. Record important architectural or product decisions.
4. Run available tests/checks when possible.
5. Review diff before proposing commit.
After meaningful work:
1. Under update lock, refresh relevant `<context-root>/memory-bank/*` files from latest state.
2. Update execution-scoped budget/context record.
3. Update decision log without silently promoting conflicting proposals.
4. Update sprint review after review.
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
- Was `<mlms-root>/executions/<execution-id>/activeContext.md` updated under lock?
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
