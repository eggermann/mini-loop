#!/usr/bin/env sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
if [ "${1:-}" != --unlocked ]; then
  TARGET_DIR=${1:-.}
  SUBGOAL_ID=${2:-}
  TARGET_BRANCH=${3:-}
  [ -n "$SUBGOAL_ID" ] && [ -n "$TARGET_BRANCH" ] || {
    echo "usage: reconcile-subgoal.sh <app-checkout> <subgoal-id> <target-branch>" >&2
    exit 2
  }
  exec "$SCRIPT_DIR/mlms-lock.sh" "$TARGET_DIR" -- "$SCRIPT_DIR/reconcile-subgoal.sh" --unlocked "$TARGET_DIR" "$SUBGOAL_ID" "$TARGET_BRANCH"
fi
TARGET_DIR=${2:-.}
SUBGOAL_ID=${3:-}
TARGET_BRANCH=${4:-}
case "$SUBGOAL_ID" in ''|*[!A-Za-z0-9._-]*|*..*) echo "reconcile-subgoal: unsafe subgoal ID" >&2; exit 2 ;; esac
RESOLVED=$("$SCRIPT_DIR/resolve-project.sh" "$TARGET_DIR") || exit $?
APPLICATION_ROOT=$(printf '%s\n' "$RESOLVED" | sed -n 's/^application_root=//p')
MLMS_ROOT=$(printf '%s\n' "$RESOLVED" | sed -n 's/^mlms_root=//p')
TARGET_COMMIT=$(git -C "$APPLICATION_ROOT" rev-parse --verify "$TARGET_BRANCH^{commit}" 2>/dev/null) || {
  echo "reconcile-subgoal: target branch/ref does not resolve locally: $TARGET_BRANCH" >&2
  exit 1
}

SUBGOAL_FILE=
FILE_LIST=$(mktemp "${TMPDIR:-/tmp}/mlms-subgoals.XXXXXX")
trap 'rm -f "$FILE_LIST"' EXIT INT TERM
if [ -d "$MLMS_ROOT/subgoals" ]; then
  find "$MLMS_ROOT/subgoals" -type f -name subgoal.md -print | sort > "$FILE_LIST"
fi
while IFS= read -r candidate; do
  candidate_context=${candidate%/subgoal.md}
  if [ "${candidate_context##*/}" = "$SUBGOAL_ID" ]; then
    [ -z "$SUBGOAL_FILE" ] || { echo "reconcile-subgoal: duplicate subgoal ID: $SUBGOAL_ID" >&2; exit 1; }
    SUBGOAL_FILE=$candidate
  fi
done < "$FILE_LIST"
[ -n "$SUBGOAL_FILE" ] || { echo "reconcile-subgoal: subgoal not found: $SUBGOAL_ID" >&2; exit 1; }

field() {
  field_name=$1
  field_file=$2
  sed -n "/^## Git Assignment/,/^## /{ /^- $field_name:/s/^- $field_name: *//p; }" "$field_file" | head -n 1
}
ASSIGNED_APP=$(field 'Application repository' "$SUBGOAL_FILE")
IMPL_BRANCH=$(field Branch "$SUBGOAL_FILE")
RELEVANT_COMMITS=$(field 'Relevant commits' "$SUBGOAL_FILE")
[ "$ASSIGNED_APP" = "$APPLICATION_ROOT" ] || { echo "reconcile-subgoal: subgoal belongs to another application repository" >&2; exit 1; }
[ -n "$IMPL_BRANCH" ] || { echo "reconcile-subgoal: subgoal has no implementation branch assignment" >&2; exit 1; }

BRANCH_REF="refs/heads/$IMPL_BRANCH"
BRANCH_EXISTS=false
BRANCH_TIP=
if git -C "$APPLICATION_ROOT" show-ref --verify --quiet "$BRANCH_REF"; then
  BRANCH_EXISTS=true
  BRANCH_TIP=$(git -C "$APPLICATION_ROOT" rev-parse --verify "$BRANCH_REF^{commit}")
fi

case "$RELEVANT_COMMITS" in none|"none yet"|-) RELEVANT_COMMITS= ;; esac
STATUS=unknown
EVIDENCE=
if [ -n "$RELEVANT_COMMITS" ]; then
  set -f
  RELEVANT_COMMITS=$(printf '%s' "$RELEVANT_COMMITS" | tr ',' ' ')
  all_merged=true
  any_missing=false
  for commit in $RELEVANT_COMMITS; do
    commit=${commit%,}
    if ! git -C "$APPLICATION_ROOT" rev-parse --verify "$commit^{commit}" >/dev/null 2>&1; then
      any_missing=true
      all_merged=false
      break
    fi
    if ! git -C "$APPLICATION_ROOT" merge-base --is-ancestor "$commit^{commit}" "$TARGET_COMMIT"; then
      all_merged=false
    fi
  done
  if [ "$all_merged" = true ]; then
    STATUS=merged
    EVIDENCE="all recorded implementation commits are ancestors of target"
  elif [ "$any_missing" = true ]; then
    STATUS=unknown
    EVIDENCE="one or more recorded implementation commits are unavailable locally"
  elif [ "$BRANCH_EXISTS" = true ] && git -C "$APPLICATION_ROOT" merge-base --is-ancestor "$TARGET_COMMIT" "$BRANCH_TIP"; then
    STATUS='not merged'
    EVIDENCE="target is ancestor of assigned branch and recorded commits are not in target"
  else
    STATUS=unknown
    EVIDENCE="recorded commits are not ancestors of target; squash or other integration cannot be proven"
  fi
  set +f
elif [ "$BRANCH_EXISTS" = false ]; then
  STATUS=unknown
  EVIDENCE="assigned branch is absent and no recorded commit evidence proves integration"
elif git -C "$APPLICATION_ROOT" merge-base --is-ancestor "$BRANCH_TIP" "$TARGET_COMMIT"; then
  STATUS=merged
  EVIDENCE="assigned branch tip is an ancestor of target"
elif git -C "$APPLICATION_ROOT" merge-base --is-ancestor "$TARGET_COMMIT" "$BRANCH_TIP"; then
  STATUS='not merged'
  EVIDENCE="target is an ancestor of assigned branch tip"
else
  STATUS=unknown
  EVIDENCE="branches diverged; squash or other integration cannot be proven"
fi

EVIDENCE_HASH=$(printf %s "$EVIDENCE" | cksum | awk '{print $1}')
MARKER="<!-- mlms-reconcile:$SUBGOAL_ID:$TARGET_COMMIT:$STATUS:$EVIDENCE_HASH -->"
TEMP_FILE="$SUBGOAL_FILE.tmp.$$"
awk '/^## Git Reconciliation$/ { skipping=1; next } /^## / { skipping=0 } !skipping { print }' "$SUBGOAL_FILE" > "$TEMP_FILE"
cat >> "$TEMP_FILE" <<DOC

## Git Reconciliation
- Status: $STATUS
- Implementation branch: $IMPL_BRANCH
- Target branch: $TARGET_BRANCH
- Target commit: $TARGET_COMMIT
- Evidence: $EVIDENCE
$MARKER
DOC
if ! cmp -s "$SUBGOAL_FILE" "$TEMP_FILE"; then mv "$TEMP_FILE" "$SUBGOAL_FILE"; else rm -f "$TEMP_FILE"; fi

CHILD_ROOT=${SUBGOAL_FILE%/subgoal.md}
append_once() {
  target_file=$1
  title=$2
  [ -f "$target_file" ] || return 0
  if ! grep -Fq "$MARKER" "$target_file"; then
    cat >> "$target_file" <<DOC

## $title
- Subgoal: $SUBGOAL_ID
- Status: $STATUS
- Target: $TARGET_BRANCH ($TARGET_COMMIT)
- Evidence: $EVIDENCE
$MARKER
DOC
  fi
}
append_once "$MLMS_ROOT/memory-bank/progress.md" "Git Reconciliation $SUBGOAL_ID ($STATUS)"
append_once "$CHILD_ROOT/memory-bank/progress.md" "Git Reconciliation $SUBGOAL_ID ($STATUS)"
append_once "$MLMS_ROOT/memory-bank/sprintReview.md" "Git Reconciliation $SUBGOAL_ID ($STATUS)"
append_once "$CHILD_ROOT/memory-bank/sprintReview.md" "Git Reconciliation $SUBGOAL_ID ($STATUS)"
printf 'subgoal_id=%s\nmerge_status=%s\ntarget_commit=%s\nevidence=%s\nparent_goal_changed=false\n' "$SUBGOAL_ID" "$STATUS" "$TARGET_COMMIT" "$EVIDENCE"
