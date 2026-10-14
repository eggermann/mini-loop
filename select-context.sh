#!/usr/bin/env sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TARGET_DIR=${1:-.}
RESOLVED=$("$SCRIPT_DIR/resolve-project.sh" "$TARGET_DIR") || exit $?
APPLICATION_ROOT=$(printf '%s\n' "$RESOLVED" | sed -n 's/^application_root=//p')
WORKTREE_ROOT=$(printf '%s\n' "$RESOLVED" | sed -n 's/^worktree_root=//p')
BRANCH=$(printf '%s\n' "$RESOLVED" | sed -n 's/^branch=//p')
MLMS_ROOT=$(printf '%s\n' "$RESOLVED" | sed -n 's/^mlms_root=//p')
SUBGOAL_ROOT="$MLMS_ROOT/subgoals"

field() {
  field_name=$1
  field_file=$2
  sed -n "/^## Git Assignment/,/^## /{ /^- $field_name:/s/^- $field_name: *//p; }" "$field_file" | head -n 1
}
status() {
  awk 'BEGIN { in_status=0 } /^## Status$/ { in_status=1; next } /^## / { if (in_status) exit } in_status && NF { print; exit }' "$1"
}

selected=
selected_depth=0
matches_at_depth=0
any_assigned_active=false
if [ -d "$SUBGOAL_ROOT" ]; then
  FILE_LIST=$(mktemp "${TMPDIR:-/tmp}/mlms-contexts.XXXXXX")
  MATCH_LIST=$(mktemp "${TMPDIR:-/tmp}/mlms-matches.XXXXXX")
  LEGACY_LIST=$(mktemp "${TMPDIR:-/tmp}/mlms-legacy-contexts.XXXXXX")
  trap 'rm -f "$FILE_LIST" "$MATCH_LIST" "$LEGACY_LIST"' EXIT INT TERM
  find "$SUBGOAL_ROOT" -type f -name subgoal.md -print | sort > "$FILE_LIST"
  : > "$MATCH_LIST"
  : > "$LEGACY_LIST"
  while IFS= read -r file; do
    [ "$(status "$file")" = active ] || continue
    assigned_repo=$(field 'Application repository' "$file")
    assigned_branch=$(field Branch "$file")
    assigned_worktree=$(field Worktree "$file")
    if [ -n "$assigned_repo$assigned_branch$assigned_worktree" ]; then
      any_assigned_active=true
      if [ "$assigned_repo" = "$APPLICATION_ROOT" ] && [ "$assigned_branch" = "$BRANCH" ] && [ "$assigned_worktree" = "$WORKTREE_ROOT" ]; then
        printf '%s\n' "$file" >> "$MATCH_LIST"
      elif { [ "$assigned_repo" = "$APPLICATION_ROOT" ] && [ -z "$assigned_worktree" ] && { [ -z "$assigned_branch" ] || [ "$assigned_branch" = "$BRANCH" ]; }; } || { [ "$assigned_branch" = "$BRANCH" ] && [ -z "$assigned_worktree" ] && [ -z "$assigned_repo" ]; }; then
        echo "select-context: incomplete Git assignment matches current checkout in $file" >&2
        exit 75
      fi
    else
      printf '%s\n' "$file" >> "$LEGACY_LIST"
    fi
  done < "$FILE_LIST"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    depth=$(printf '%s\n' "$file" | awk -F/ '{print NF}')
    if [ "$depth" -gt "$selected_depth" ]; then
      selected=$file
      selected_depth=$depth
      matches_at_depth=1
    elif [ "$depth" -eq "$selected_depth" ]; then
      matches_at_depth=$((matches_at_depth + 1))
    fi
  done < "$MATCH_LIST"
fi

if [ "$matches_at_depth" -gt 1 ]; then
  echo "select-context: multiple active subgoals match this repository/branch/worktree" >&2
  exit 75
fi
if [ -n "$selected" ]; then
  selected_context=${selected%/subgoal.md}
  while IFS= read -r matched_file; do
    [ -n "$matched_file" ] || continue
    [ "$matched_file" = "$selected" ] && continue
    matched_context=${matched_file%/subgoal.md}
    case "$selected_context" in
      "$matched_context"/subgoals/*) ;;
      *) echo "select-context: matching subgoals are not in one parent/child chain" >&2; exit 75 ;;
    esac
  done < "$MATCH_LIST"
  # Legacy nested children inherit assigned parent worktree when no assignment recorded.
  while IFS= read -r legacy_file; do
    [ -n "$legacy_file" ] || continue
    legacy_context=${legacy_file%/subgoal.md}
    case "$legacy_context" in
      "$selected_context"/subgoals/*)
        depth=$(printf '%s\n' "$legacy_file" | awk -F/ '{print NF}')
        if [ "$depth" -gt "$selected_depth" ]; then
          selected=$legacy_file
          selected_depth=$depth
          matches_at_depth=1
        elif [ "$depth" -eq "$selected_depth" ]; then
          matches_at_depth=$((matches_at_depth + 1))
        fi
        ;;
    esac
  done < "$LEGACY_LIST"
  [ "$matches_at_depth" -le 1 ] || { echo "select-context: multiple active nested subgoals match this execution" >&2; exit 75; }
elif [ "$any_assigned_active" = false ]; then
  # Backward compatibility: a single active legacy child resumes in a sequential workflow.
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    depth=$(printf '%s\n' "$file" | awk -F/ '{print NF}')
    if [ "$depth" -gt "$selected_depth" ]; then
      selected=$file
      selected_depth=$depth
      matches_at_depth=1
    elif [ "$depth" -eq "$selected_depth" ]; then
      matches_at_depth=$((matches_at_depth + 1))
    fi
  done < "$LEGACY_LIST"
  [ "$matches_at_depth" -le 1 ] || { echo "select-context: multiple active legacy subgoals; assign branch/worktree explicitly" >&2; exit 75; }
  if [ -n "$selected" ]; then
    selected_context=${selected%/subgoal.md}
    while IFS= read -r legacy_file; do
      [ -n "$legacy_file" ] || continue
      [ "$legacy_file" = "$selected" ] && continue
      legacy_context=${legacy_file%/subgoal.md}
      case "$selected_context" in
        "$legacy_context"/subgoals/*) ;;
        *) echo "select-context: active legacy subgoals are not in one parent/child chain" >&2; exit 75 ;;
      esac
    done < "$LEGACY_LIST"
  fi
fi

if [ -n "$selected" ]; then
  context_root=${selected%/subgoal.md}
  subgoal_id=${context_root##*/}
  relative_context=${context_root#"$MLMS_ROOT/subgoals/"}
  execution_id=${relative_context%%/*}
else
  context_root=$MLMS_ROOT
  subgoal_id=
  branch_key=$(printf '%s' "$BRANCH" | tr -c 'A-Za-z0-9._-' '_' | cut -c 1-32)
  worktree_key=$(printf '%s' "${WORKTREE_ROOT##*/}" | tr -c 'A-Za-z0-9._-' '_' | cut -c 1-32)
  execution_id="root-${branch_key}-${worktree_key}-$(printf '%s\n%s\n%s\n' "$APPLICATION_ROOT" "$BRANCH" "$WORKTREE_ROOT" | cksum | awk '{print $1}')"
fi
printf 'context_root=%s\n' "$context_root"
printf 'subgoal_id=%s\n' "$subgoal_id"
printf 'execution_id=%s\n' "$execution_id"
