#!/usr/bin/env sh
set -eu

# Print canonical application identity and current checkout context.
# This command is read-only. It never initializes or changes MLMS state.

fail() {
  echo "resolve-project: $*" >&2
  exit 1
}

target_dir=${1:-.}
worktree_root=$(git -C "$target_dir" rev-parse --show-toplevel 2>/dev/null) || fail "current directory is not inside a Git worktree"
worktree_root=$(CDPATH= cd -- "$worktree_root" && pwd -P) || fail "cannot resolve current worktree path"

git_common_dir=$(git -C "$worktree_root" rev-parse --git-common-dir 2>/dev/null) || fail "cannot resolve Git common directory"
case "$git_common_dir" in
  /*) ;;
  *) git_common_dir="$worktree_root/$git_common_dir" ;;
esac
git_common_dir=$(CDPATH= cd -- "$git_common_dir" 2>/dev/null && pwd -P) || fail "Git common directory is missing or inaccessible"

# Git lists primary worktree first, including when invoked from linked worktree.
worktree_list=$(git -C "$worktree_root" worktree list --porcelain 2>/dev/null) || fail "cannot list Git worktrees"
canonical_worktree=
current_worktree_found=false
first_worktree=true
while IFS= read -r line; do
  case "$line" in
    "worktree "*)
      listed_worktree=${line#worktree }
      if [ "$first_worktree" = true ]; then
        canonical_worktree=$listed_worktree
        first_worktree=false
      fi
      if [ "$listed_worktree" = "$worktree_root" ]; then
        current_worktree_found=true
      fi
      ;;
    bare)
      fail "bare repositories have no canonical application worktree"
      ;;
  esac
done <<EOF_LIST
$worktree_list
EOF_LIST

[ -n "$canonical_worktree" ] || fail "Git reported no primary worktree"
[ "$current_worktree_found" = true ] || fail "current checkout is absent from Git worktree registry"
case "$canonical_worktree" in
  *'
'*) fail "worktree paths containing newlines are unsupported" ;;
esac
[ -d "$canonical_worktree" ] || fail "primary worktree is missing; refusing to guess canonical identity"
canonical_worktree=$(CDPATH= cd -- "$canonical_worktree" && pwd -P) || fail "cannot resolve primary worktree path"
canonical_common_dir=$(git -C "$canonical_worktree" rev-parse --git-common-dir 2>/dev/null) || fail "cannot resolve primary worktree Git common directory"
case "$canonical_common_dir" in
  /*) ;;
  *) canonical_common_dir="$canonical_worktree/$canonical_common_dir" ;;
esac
canonical_common_dir=$(CDPATH= cd -- "$canonical_common_dir" 2>/dev/null && pwd -P) || fail "primary worktree Git common directory is missing"
[ "$canonical_common_dir" = "$git_common_dir" ] || fail "primary worktree and current checkout do not share Git common directory"

canonical_name=${canonical_worktree##*/}
[ -n "$canonical_name" ] && [ "$canonical_name" != "." ] || fail "invalid canonical repository folder name"
workspace_root=${canonical_worktree%/*}
[ -n "$workspace_root" ] || workspace_root=/
mlms_root="$workspace_root/.mlms-$canonical_name"

branch=$(git -C "$worktree_root" branch --show-current 2>/dev/null) || fail "cannot resolve current branch"
if [ -z "$branch" ]; then
  branch=DETACHED
fi

printf 'application_root=%s\n' "$canonical_worktree"
printf 'git_common_dir=%s\n' "$git_common_dir"
printf 'worktree_root=%s\n' "$worktree_root"
printf 'branch=%s\n' "$branch"
printf 'mlms_root=%s\n' "$mlms_root"
