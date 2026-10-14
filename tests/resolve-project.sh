#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d)
TMP_ROOT=$(CDPATH= cd -- "$TMP_ROOT" && pwd -P)
trap 'rm -rf "$TMP_ROOT"' EXIT INT TERM

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

APP_ROOT="$TMP_ROOT/workspace with spaces/my-app"
FEATURE_ROOT="$TMP_ROOT/workspace/api-checkout-with-another-name"
mkdir -p "$APP_ROOT"
git -C "$APP_ROOT" init -q
git -C "$APP_ROOT" config user.name "Mini Loop Test"
git -C "$APP_ROOT" config user.email "mini-loop@example.invalid"
printf 'source\n' > "$APP_ROOT/source.txt"
git -C "$APP_ROOT" add source.txt
git -C "$APP_ROOT" commit -qm "initial"

main_output=$(cd "$APP_ROOT" && "$SCRIPT_DIR/resolve-project.sh")
case "$main_output" in
  *"application_root=$APP_ROOT"*"mlms_root=$TMP_ROOT/workspace with spaces/.mlms-my-app"*) ;;
  *) fail "normal repository identity incorrect: $main_output" ;;
esac

main_branch=$(git -C "$APP_ROOT" branch --show-current)
case "$main_output" in
  *"branch=$main_branch"*) ;;
  *) fail "normal branch incorrect: $main_output" ;;
esac

git -C "$APP_ROOT" worktree add -qb feature/api "$FEATURE_ROOT"
linked_output=$(cd "$FEATURE_ROOT" && "$SCRIPT_DIR/resolve-project.sh")
case "$linked_output" in
  *"application_root=$APP_ROOT"*"worktree_root=$FEATURE_ROOT"*"branch=feature/api"*"mlms_root=$TMP_ROOT/workspace with spaces/.mlms-my-app"*) ;;
  *) fail "linked worktree identity differs: $linked_output" ;;
esac

git -C "$FEATURE_ROOT" checkout -q --detach
detached_output=$(cd "$FEATURE_ROOT" && "$SCRIPT_DIR/resolve-project.sh")
case "$detached_output" in
  *"application_root=$APP_ROOT"*"branch=DETACHED"*"mlms_root=$TMP_ROOT/workspace with spaces/.mlms-my-app"*) ;;
  *) fail "detached HEAD identity incorrect: $detached_output" ;;
esac
git -C "$FEATURE_ROOT" checkout -q feature/api

if (cd "$TMP_ROOT" && "$SCRIPT_DIR/resolve-project.sh") >/dev/null 2>&1; then
  fail "outside-Git invocation unexpectedly succeeded"
fi
[ ! -e "$TMP_ROOT/workspace with spaces/.mlms-my-app" ] || fail "read-only resolver created MLMS state"

# Migration preserves legacy content, initializes independent history, and is repeatable.
LEGACY_FILE="$APP_ROOT/.mlms/keep.txt"
mkdir -p "$(dirname "$LEGACY_FILE")"
printf 'legacy memory\n' > "$LEGACY_FILE"
NEWLINE_FILE="$APP_ROOT/.mlms/file with newline
name.md"
printf 'newline path preserved\n' > "$NEWLINE_FILE"
mkdir -p "$APP_ROOT/.mlms/subgoals/001-auth/memory-bank"
printf 'handoff stays\n' > "$APP_ROOT/.mlms/subgoals/001-auth/memory-bank/handoff.md"
APP_HEAD_BEFORE=$(git -C "$APP_ROOT" rev-parse HEAD)
APP_STATUS_BEFORE=$(git -C "$APP_ROOT" status --porcelain)
if "$SCRIPT_DIR/init-project-memory.sh" "$APP_ROOT" >/dev/null 2>&1; then
  fail "initializer silently created new context over embedded memory"
fi
"$SCRIPT_DIR/migrate-project-memory.sh" "$APP_ROOT" >/dev/null
MLMS_ROOT="$TMP_ROOT/workspace with spaces/.mlms-my-app"
[ -d "$MLMS_ROOT/.git" ] || fail "sibling MLMS is not a Git repository"
[ "$(git -C "$MLMS_ROOT" rev-parse --show-toplevel)" = "$MLMS_ROOT" ] || fail "MLMS Git root is not independent"
[ "$(git -C "$APP_ROOT" rev-parse HEAD)" = "$APP_HEAD_BEFORE" ] || fail "migration changed application history"
[ "$(cat "$LEGACY_FILE")" = "legacy memory" ] || fail "migration changed embedded memory"
[ "$(cat "$MLMS_ROOT/keep.txt")" = "legacy memory" ] || fail "migration did not preserve legacy content"
[ "$(cat "$MLMS_ROOT/file with newline
name.md")" = "newline path preserved" ] || fail "migration did not preserve unusual filename"
[ "$(cat "$MLMS_ROOT/subgoals/001-auth/memory-bank/handoff.md")" = "handoff stays" ] || fail "migration lost nested handoff"
if git -C "$MLMS_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  fail "migration created an MLMS commit automatically"
fi
"$SCRIPT_DIR/migrate-project-memory.sh" "$FEATURE_ROOT" >/dev/null
[ "$(git -C "$APP_ROOT" status --porcelain)" = "$APP_STATUS_BEFORE" ] || fail "migration changed application working tree"
cat > "$MLMS_ROOT/subgoals/001-auth/subgoal.md" <<'DOC'
# Subgoal
## Status
active
## Acceptance Criteria
- [ ] legacy active child resumes
DOC
legacy_context=$("$SCRIPT_DIR/select-context.sh" "$APP_ROOT")
case "$legacy_context" in *"subgoal_id=001-auth"*"execution_id=001-auth"*) ;; *) fail "legacy active subgoal did not resume: $legacy_context" ;; esac

# Commits stay in their own repositories in both directions.
git -C "$APP_ROOT" config user.name "Mini Loop Test"
git -C "$APP_ROOT" config user.email "mini-loop@example.invalid"
printf 'app-only\n' > "$APP_ROOT/app-only.txt"
git -C "$APP_ROOT" add app-only.txt
git -C "$APP_ROOT" commit -qm "app-only commit"
APP_HEAD_AFTER=$(git -C "$APP_ROOT" rev-parse HEAD)
git -C "$MLMS_ROOT" config user.name "Mini Loop Test"
git -C "$MLMS_ROOT" config user.email "mini-loop@example.invalid"
"$SCRIPT_DIR/mlms-commit.sh" "$APP_ROOT" "test-only MLMS commit" projectBrief.md keep.txt subgoals/001-auth/memory-bank/handoff.md >/dev/null
MLMS_HEAD_AFTER=$(git -C "$MLMS_ROOT" rev-parse HEAD)
"$SCRIPT_DIR/mlms-commit.sh" "$APP_ROOT" "no-op MLMS commit" projectBrief.md keep.txt subgoals/001-auth/memory-bank/handoff.md | grep -q 'no material changes'
[ "$(git -C "$MLMS_ROOT" rev-parse HEAD)" = "$MLMS_HEAD_AFTER" ] || fail "no-op created MLMS commit"
printf 'meaningful change\n' >> "$MLMS_ROOT/projectBrief.md"
printf 'unrelated staged\n' > "$MLMS_ROOT/memory-bank/unrelated.md"
git -C "$MLMS_ROOT" add -f memory-bank/unrelated.md
"$SCRIPT_DIR/mlms-commit.sh" "$APP_ROOT" "scoped MLMS commit" projectBrief.md >/dev/null
[ "$(git -C "$MLMS_ROOT" diff --cached --name-only)" = "memory-bank/unrelated.md" ] || fail "MLMS commit staged/committed unrelated path"
git -C "$MLMS_ROOT" reset -q -- memory-bank/unrelated.md
[ "$(git -C "$APP_ROOT" rev-parse HEAD)" = "$APP_HEAD_AFTER" ] || fail "MLMS commit changed app history"
if git -C "$MLMS_ROOT" ls-files | grep -q 'app-only.txt'; then fail "application file entered MLMS history"; fi
if git -C "$APP_ROOT" ls-files | grep -q 'projectBrief.md'; then fail "MLMS file entered application history"; fi

# Destination conflict aborts before copying other files and leaves source intact.
CONFLICT_APP="$TMP_ROOT/workspace with spaces/conflict-app"
mkdir -p "$CONFLICT_APP/.mlms" "$TMP_ROOT/workspace with spaces/.mlms-conflict-app"
git -C "$CONFLICT_APP" init -q
git -C "$CONFLICT_APP" config user.name "Mini Loop Test"
git -C "$CONFLICT_APP" config user.email "mini-loop@example.invalid"
printf 'legacy value\n' > "$CONFLICT_APP/.mlms/projectBrief.md"
printf 'existing value\n' > "$TMP_ROOT/workspace with spaces/.mlms-conflict-app/projectBrief.md"
if "$SCRIPT_DIR/migrate-project-memory.sh" "$CONFLICT_APP" >/dev/null 2>&1; then
  fail "migration overwrote conflicting destination"
fi
[ "$(cat "$CONFLICT_APP/.mlms/projectBrief.md")" = "legacy value" ] || fail "migration changed conflicting source"
[ "$(cat "$TMP_ROOT/workspace with spaces/.mlms-conflict-app/projectBrief.md")" = "existing value" ] || fail "migration changed conflicting destination"
[ ! -e "$TMP_ROOT/workspace with spaces/.mlms-conflict-app/memory-bank/progress.md" ] || fail "migration copied before conflict preflight completed"

# Lock is exclusive; stale lock is reported and never removed automatically.
LOCK_DIR="${MLMS_ROOT}.update-lock"
"$SCRIPT_DIR/mlms-lock.sh" "$APP_ROOT" -- sh -c 'sleep 1' &
LOCK_PID=$!
tries=0
while [ ! -d "$LOCK_DIR" ] && [ "$tries" -lt 30 ]; do sleep 0.05; tries=$((tries + 1)); done
[ -d "$LOCK_DIR" ] || fail "lock holder did not acquire lock"
if "$SCRIPT_DIR/mlms-lock.sh" "$FEATURE_ROOT" -- true >/dev/null 2>&1; then
  fail "concurrent lock acquisition unexpectedly succeeded"
fi
wait "$LOCK_PID"
[ ! -e "$LOCK_DIR" ] || fail "lock was not released"
UPDATE_LOG="$MLMS_ROOT/concurrent-update-log.md"
"$SCRIPT_DIR/mlms-lock.sh" "$APP_ROOT" -- sh -c 'printf "agent-a\n" >> "$1"; sleep 0.5' sh "$UPDATE_LOG" &
LOCK_PID=$!
tries=0
while [ ! -d "$LOCK_DIR" ] && [ "$tries" -lt 30 ]; do sleep 0.05; tries=$((tries + 1)); done
if "$SCRIPT_DIR/mlms-lock.sh" "$FEATURE_ROOT" -- sh -c 'printf "agent-b\n" >> "$1"' sh "$UPDATE_LOG" >/dev/null 2>&1; then
  fail "competing update unexpectedly bypassed lock"
fi
wait "$LOCK_PID"
"$SCRIPT_DIR/mlms-lock.sh" "$FEATURE_ROOT" -- sh -c 'printf "agent-b\n" >> "$1"' sh "$UPDATE_LOG"
grep -q '^agent-a$' "$UPDATE_LOG" || fail "first locked update was lost"
grep -q '^agent-b$' "$UPDATE_LOG" || fail "retried locked update was lost"
rm -f "$UPDATE_LOG"
mkdir "$LOCK_DIR"
printf 'pid=stale\n' > "$LOCK_DIR/owner"
if "$SCRIPT_DIR/mlms-lock.sh" "$APP_ROOT" -- true >/dev/null 2>&1; then
  fail "stale lock unexpectedly acquired"
fi
[ "$(cat "$LOCK_DIR/owner")" = "pid=stale" ] || fail "stale lock metadata changed"
rm -rf "$LOCK_DIR"

# Different worktrees select distinct assigned subgoals and execution budgets.
mkdir -p "$MLMS_ROOT/subgoals/001-api" "$MLMS_ROOT/subgoals/002-web"
cat > "$MLMS_ROOT/subgoals/001-api/subgoal.md" <<DOC
# Subgoal
## Status
active
## Git Assignment
- Application repository: $APP_ROOT
- Branch: feature/api
- Worktree: $FEATURE_ROOT
DOC
cat > "$MLMS_ROOT/subgoals/002-web/subgoal.md" <<DOC
# Subgoal
## Status
active
## Git Assignment
- Application repository: $APP_ROOT
- Branch: $main_branch
- Worktree: $APP_ROOT
DOC
mkdir -p "$MLMS_ROOT/subgoals/001-api/subgoals/001-api-child"
cat > "$MLMS_ROOT/subgoals/001-api/subgoals/001-api-child/subgoal.md" <<DOC
# Subgoal
## Status
active
## Acceptance Criteria
- [ ] legacy nested child inherits parent assignment
DOC
api_context=$("$SCRIPT_DIR/select-context.sh" "$FEATURE_ROOT")
main_context=$("$SCRIPT_DIR/select-context.sh" "$APP_ROOT")
case "$api_context" in *"subgoal_id=001-api-child"*"execution_id=001-api"*) ;; *) fail "feature worktree selected wrong nested context/budget: $api_context" ;; esac
case "$main_context" in *"subgoal_id=002-web"*"execution_id=002-web"*) ;; *) fail "main worktree selected wrong context: $main_context" ;; esac
MEMORY_BEFORE_SWITCH=$(cksum "$MLMS_ROOT/projectBrief.md")
git -C "$APP_ROOT" checkout -qb feature/switch
switch_root=$("$SCRIPT_DIR/resolve-project.sh" "$APP_ROOT" | sed -n 's/^mlms_root=//p')
[ "$switch_root" = "$MLMS_ROOT" ] || fail "application branch switch changed MLMS root"
[ "$(cksum "$MLMS_ROOT/projectBrief.md")" = "$MEMORY_BEFORE_SWITCH" ] || fail "application branch switch changed project memory"
git -C "$APP_ROOT" checkout -q main

api_budget=$("$SCRIPT_DIR/loop-budget.sh" "$FEATURE_ROOT" 001-api increment)
main_budget=$("$SCRIPT_DIR/loop-budget.sh" "$APP_ROOT" 002-web increment)
api_nested_budget=$("$SCRIPT_DIR/loop-budget.sh" "$FEATURE_ROOT" 001-api increment)
case "$api_budget" in *"used=1"*"maximum=5"*) ;; *) fail "initial API budget incorrect: $api_budget" ;; esac
case "$main_budget" in *"used=1"*) ;; *) fail "main budget incorrect: $main_budget" ;; esac
case "$api_nested_budget" in *"used=2"*) ;; *) fail "nested execution failed to inherit budget: $api_nested_budget" ;; esac
"$SCRIPT_DIR/loop-budget.sh" "$FEATURE_ROOT" 001-api increment >/dev/null
"$SCRIPT_DIR/loop-budget.sh" "$FEATURE_ROOT" 001-api increment >/dev/null
"$SCRIPT_DIR/loop-budget.sh" "$FEATURE_ROOT" 001-api increment >/dev/null
if "$SCRIPT_DIR/loop-budget.sh" "$FEATURE_ROOT" 001-api increment >/dev/null 2>&1; then
  fail "execution exceeded five-iteration budget"
fi

# Parallel active subgoals assigned to same worktree are ambiguous and fail closed.
mkdir -p "$MLMS_ROOT/subgoals/003-api-duplicate"
cat > "$MLMS_ROOT/subgoals/003-api-duplicate/subgoal.md" <<DOC
# Subgoal
## Status
active
## Git Assignment
- Application repository: $APP_ROOT
- Branch: feature/api
- Worktree: $FEATURE_ROOT
DOC
if "$SCRIPT_DIR/select-context.sh" "$FEATURE_ROOT" >/dev/null 2>&1; then
  fail "ambiguous active subgoal assignment unexpectedly succeeded"
fi

# Reconciliation records ancestry conservatively and is idempotent.
RECON_APP="$TMP_ROOT/workspace with spaces/reconcile-app"
mkdir -p "$RECON_APP"
git -C "$RECON_APP" init -q
git -C "$RECON_APP" branch -M main
git -C "$RECON_APP" config user.name "Mini Loop Test"
git -C "$RECON_APP" config user.email "mini-loop@example.invalid"
printf 'base\n' > "$RECON_APP/file.txt"
git -C "$RECON_APP" add file.txt
git -C "$RECON_APP" commit -qm base
"$SCRIPT_DIR/init-project-memory.sh" "$RECON_APP" >/dev/null
RECON_MLMS="$TMP_ROOT/workspace with spaces/.mlms-reconcile-app"

make_subgoal() {
  id=$1
  branch=$2
  commit=$3
  mkdir -p "$RECON_MLMS/subgoals/$id/memory-bank"
  cat > "$RECON_MLMS/subgoals/$id/subgoal.md" <<DOC
# Subgoal
## Parent Goal
Keep parent open.
## Goal
Test reconciliation.
## Status
active
## Git Assignment
- Application repository: $RECON_APP
- Branch: $branch
- Worktree: $RECON_APP
- Base / target branch: main
- Relevant commits: $commit
## Acceptance Criteria
- [ ] Manual acceptance remains required.
## Handoff to Parent
Pending.
DOC
  printf '# Progress\n' > "$RECON_MLMS/subgoals/$id/memory-bank/progress.md"
  printf '# Sprint Review\n' > "$RECON_MLMS/subgoals/$id/memory-bank/sprintReview.md"
}

git -C "$RECON_APP" checkout -qb feature/normal
printf 'normal\n' >> "$RECON_APP/file.txt"
git -C "$RECON_APP" commit -qam normal
NORMAL_COMMIT=$(git -C "$RECON_APP" rev-parse HEAD)
git -C "$RECON_APP" checkout -q main
git -C "$RECON_APP" merge --no-ff -qm 'merge normal' feature/normal
make_subgoal 001-normal feature/normal "$NORMAL_COMMIT"
PARENT_CONTEXT_BEFORE=$(cat "$RECON_MLMS/memory-bank/activeContext.md")
normal_result=$("$SCRIPT_DIR/reconcile-subgoal.sh" "$RECON_APP" 001-normal main)
case "$normal_result" in *"merge_status=merged"*) ;; *) fail "normal ancestry not reconciled as merged: $normal_result" ;; esac
[ "$(sed -n '/^## Status$/,+1p' "$RECON_MLMS/subgoals/001-normal/subgoal.md" | tail -n 1)" = active ] || fail "merge incorrectly completed subgoal"
[ "$(cat "$RECON_MLMS/memory-bank/activeContext.md")" = "$PARENT_CONTEXT_BEFORE" ] || fail "merge incorrectly changed parent goal context"
"$SCRIPT_DIR/reconcile-subgoal.sh" "$RECON_APP" 001-normal main >/dev/null
marker_count=$(grep -Fc '<!-- mlms-reconcile:001-normal:' "$RECON_MLMS/memory-bank/progress.md")
[ "$marker_count" -eq 1 ] || fail "reconciliation duplicated same progress evidence"

# Target remains ancestor of live implementation branch: proven not merged.
git -C "$RECON_APP" checkout -qb feature/not-merged main
printf 'not merged\n' >> "$RECON_APP/file.txt"
git -C "$RECON_APP" commit -qam not-merged
NOT_MERGED_COMMIT=$(git -C "$RECON_APP" rev-parse HEAD)
git -C "$RECON_APP" checkout -q main
make_subgoal 002-not-merged feature/not-merged "$NOT_MERGED_COMMIT"
not_merged_result=$("$SCRIPT_DIR/reconcile-subgoal.sh" "$RECON_APP" 002-not-merged main)
case "$not_merged_result" in *"merge_status=not merged"*) ;; *) fail "unmerged branch result incorrect: $not_merged_result" ;; esac

# Deletion alone and squash merge remain unknown.
git -C "$RECON_APP" checkout -qb feature/deleted main
printf 'deleted\n' >> "$RECON_APP/file.txt"
git -C "$RECON_APP" commit -qam deleted
DELETED_COMMIT=$(git -C "$RECON_APP" rev-parse HEAD)
git -C "$RECON_APP" checkout -q main
git -C "$RECON_APP" branch -D feature/deleted >/dev/null
make_subgoal 003-deleted feature/deleted "$DELETED_COMMIT"
deleted_result=$("$SCRIPT_DIR/reconcile-subgoal.sh" "$RECON_APP" 003-deleted main)
case "$deleted_result" in *"merge_status=unknown"*) ;; *) fail "branch deletion incorrectly implied merge: $deleted_result" ;; esac

git -C "$RECON_APP" checkout -qb feature/squash main
printf 'squash\n' >> "$RECON_APP/file.txt"
git -C "$RECON_APP" commit -qam squash-work
SQUASH_COMMIT=$(git -C "$RECON_APP" rev-parse HEAD)
git -C "$RECON_APP" checkout -q main
git -C "$RECON_APP" merge --squash feature/squash >/dev/null
git -C "$RECON_APP" commit -qm 'squash integration'
make_subgoal 004-squash feature/squash "$SQUASH_COMMIT"
squash_result=$("$SCRIPT_DIR/reconcile-subgoal.sh" "$RECON_APP" 004-squash main)
case "$squash_result" in *"merge_status=unknown"*) ;; *) fail "squash state falsely claimed certain: $squash_result" ;; esac

# Generation and both installer paths package every runtime dependency and template.
GENERATED="$TMP_ROOT/generated package"
"$SCRIPT_DIR/create.sh" "$GENERATED" >/dev/null
for file in resolve-project.sh mlms-lock.sh init-project-memory.sh migrate-project-memory.sh select-context.sh loop-budget.sh reconcile-subgoal.sh mlms-commit.sh install-skill.sh install-from-github.sh skills/mini-loop-memory-scrum/SKILL.md templates/AGENTS.md templates/projectBrief.md templates/memory-bank/activeContext.md templates/memory-bank/productContext.md templates/memory-bank/progress.md templates/memory-bank/decisionLog.md templates/memory-bank/systemPatterns.md templates/memory-bank/sprintReview.md; do
  [ -f "$GENERATED/$file" ] || fail "generated package missing $file"
done
grep -q 'Scope: Project-wide' "$GENERATED/templates/memory-bank/decisionLog.md" || fail "generated decision template lacks global scope"
grep -q '^## Proposals' "$GENERATED/templates/memory-bank/decisionLog.md" || fail "generated decision template lacks proposal handling"
GENERATED_APP="$TMP_ROOT/workspace with spaces/generated-app"
mkdir -p "$GENERATED_APP"
git -C "$GENERATED_APP" init -q
"$GENERATED/init-project-memory.sh" "$GENERATED_APP" >/dev/null
[ -d "$TMP_ROOT/workspace with spaces/.mlms-generated-app/.git" ] || fail "generated initializer did not create sibling MLMS"

LOCAL_CODEX_HOME="$TMP_ROOT/codex local"
CODEX_HOME="$LOCAL_CODEX_HOME" "$SCRIPT_DIR/install-skill.sh" >/dev/null
for file in SKILL.md bin/resolve-project.sh bin/mlms-lock.sh bin/init-project-memory.sh bin/migrate-project-memory.sh bin/select-context.sh bin/loop-budget.sh bin/reconcile-subgoal.sh bin/mlms-commit.sh bin/templates/AGENTS.md bin/templates/projectBrief.md bin/templates/memory-bank/activeContext.md bin/templates/memory-bank/productContext.md bin/templates/memory-bank/progress.md bin/templates/memory-bank/decisionLog.md bin/templates/memory-bank/systemPatterns.md bin/templates/memory-bank/sprintReview.md; do
  [ -f "$LOCAL_CODEX_HOME/skills/mini-loop-memory-scrum/$file" ] || fail "local install missing $file"
done
LOCAL_APP="$TMP_ROOT/workspace with spaces/local-installed-app"
mkdir -p "$LOCAL_APP"
git -C "$LOCAL_APP" init -q
"$LOCAL_CODEX_HOME/skills/mini-loop-memory-scrum/bin/init-project-memory.sh" "$LOCAL_APP" >/dev/null
[ -d "$TMP_ROOT/workspace with spaces/.mlms-local-installed-app/.git" ] || fail "local installed initializer cannot find installed templates"
RAW_CODEX_HOME="$TMP_ROOT/codex raw"
CODEX_HOME="$RAW_CODEX_HOME" "$SCRIPT_DIR/install-from-github.sh" "file://$SCRIPT_DIR" >/dev/null
for file in SKILL.md bin/resolve-project.sh bin/mlms-lock.sh bin/init-project-memory.sh bin/migrate-project-memory.sh bin/select-context.sh bin/loop-budget.sh bin/reconcile-subgoal.sh bin/mlms-commit.sh bin/templates/AGENTS.md bin/templates/projectBrief.md bin/templates/memory-bank/activeContext.md bin/templates/memory-bank/productContext.md bin/templates/memory-bank/progress.md bin/templates/memory-bank/decisionLog.md bin/templates/memory-bank/systemPatterns.md bin/templates/memory-bank/sprintReview.md; do
  [ -f "$RAW_CODEX_HOME/skills/mini-loop-memory-scrum/$file" ] || fail "raw installer missing $file"
done
RAW_APP="$TMP_ROOT/workspace with spaces/raw-installed-app"
mkdir -p "$RAW_APP"
git -C "$RAW_APP" init -q
"$RAW_CODEX_HOME/skills/mini-loop-memory-scrum/bin/init-project-memory.sh" "$RAW_APP" >/dev/null
[ -d "$TMP_ROOT/workspace with spaces/.mlms-raw-installed-app/.git" ] || fail "raw installed initializer cannot find installed templates"

echo "PASS: normal, renamed linked worktree, detached HEAD, and fail-closed checks"
