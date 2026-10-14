# System Patterns

## Working Pattern

1. Resolve canonical application repository, branch, worktree, sibling MLMS root, and active goal/subgoal.
2. Load shared project vision and accepted decisions plus assigned execution context.
3. Plan smallest useful increment.
4. Implement and verify.
5. Review application diff.
6. Acquire MLMS lock, reload latest state, apply scoped update, validate, release lock.
7. Commit app and MLMS separately only when permitted.

## Quality Pattern

Every loop records acceptance criteria, implementation notes, verification, review, retrospective, and next step. Git is implementation evidence; MLMS owns project meaning. Synchronization is idempotent; uncertain merge state stays unknown.

## Safety Pattern

Never auto-push, auto-merge, rewrite app history, delete legacy `.mlms/` during migration, or silently overwrite concurrent state.
