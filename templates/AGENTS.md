# AGENTS.md

## Codex Workflow

Before doing implementation work:

1. Resolve context root: `.mlms` for main goal or active child directory.
2. Read `<context-root>/projectBrief.md`.
3. Read all files in `<context-root>/memory-bank/`.
4. Identify current loop phase from `<context-root>/memory-bank/activeContext.md`.

During work:

1. Keep changes small.
2. Prefer a vertical slice over broad unfinished edits.
3. Record important architectural or product decisions.
4. Run available tests/checks when possible.
5. Do not push automatically.
6. Do not delete files without explicit user approval, except workflow-generated
   `subgoals/` folders after their parent GOAL is completed and summarized.

## Nested Mini-Loops

Do not infer a child from `.mlms` existence alone. A repeated invocation is a
child only when parent is unfinished and new GOAL is narrower and directly
advances it. Create linear child context under
`<context-root>/subgoals/<NNN-slug>/`. Resume existing `active` child first;
otherwise start lowest-numbered `pending` child.

Each child records parent goal, subgoal, status, acceptance criteria, and
handoff in `subgoal.md`. On child completion, copy its concise result and
verification to the parent memory bank before continuing. On parent-goal
completion, mark unfinished children `cancelled` or `superseded`, preserve a
concise summary in parent memory, then remove only workflow-generated
`subgoals/`. Keep it when parent goal is blocked or incomplete. Parent and
children share one five-iteration budget; nesting depth may not exceed 3.
Before every iteration, increment `Used` in root
`.mlms/memory-bank/activeContext.md`; children never reset this counter.

After meaningful work:

1. Update `<context-root>/memory-bank/activeContext.md`.
2. Update `<context-root>/memory-bank/progress.md`.
3. Update `<context-root>/memory-bank/decisionLog.md` if a decision was made.
4. Update `<context-root>/memory-bank/sprintReview.md` after review.
5. State next recommended action.

## Auto-Commit Policy

Auto-commit is allowed only after user grants permission.

When enabled:

- Commit after each green vertical slice.
- Never commit failing checks unless user explicitly requests a WIP commit.
- Never include unrelated files.
- Update memory bank before committing.
- Do not auto-push.
