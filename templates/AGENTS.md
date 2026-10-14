# AGENTS.md

## Codex Workflow

Before implementation:

1. Resolve application root, branch, worktree, canonical sibling MLMS root, and active GOAL/subgoal.
2. Read `<mlms-root>/projectBrief.md`, shared accepted decisions, assigned parent/subgoal, relevant handoffs, dependencies, and execution budget.
3. Identify current phase from the active execution context. Load only relevant branch/worktree detail; global accepted decisions remain visible.

During work:

1. Keep changes small; preserve the Markdown memory and subgoal model.
2. Record Git assignment and evidence on the existing subgoal.
3. Acquire the MLMS update lock, reload latest state, apply scoped changes, validate, then release lock.
4. Run relevant checks and review the diff.
5. Keep application and MLMS commits separate. Never push or merge automatically.

## Nested Mini-Loops and Subgoals

Do not infer nesting from MLMS existence alone. A repeated GOAL is a child only when its parent is unfinished, the goal is narrower, and completion advances the parent. Record parent GOAL, child GOAL, status, acceptance criteria, and handoff in `subgoal.md`.

Sequential children resume the active child, else the lowest pending child. Parallel active siblings are allowed only with explicit, distinct application branch/worktree assignments. Select the unique assigned child for current checkout; fail on ambiguity. Child execution inherits its parent's execution ID and budget. Maximum nested depth is 3; default execution budget remains 5 iterations.

On child completion, preserve result, verification, and next action in parent progress, active context, and sprint review. A child cannot complete its parent GOAL. After parent completion, summarize first, mark unfinished generated children cancelled/superseded with reason, then remove only workflow-generated subgoal folders. Keep them when parent remains blocked or incomplete.

## Memory Updates and Commits

After meaningful work, update active context, progress, decision log, sprint review, retrospective, and handoff as appropriate. Preserve conflicting decision proposals; do not silently promote them. Merge evidence alone does not complete a subgoal or parent.

Application and MLMS commits use separate permissions. Commit only after green checks and review, with explicit relevant paths. Do not create empty commits. No automatic push or merge. Never delete embedded `.mlms/` during migration.
