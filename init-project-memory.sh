#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TEMPLATE_DIR="$SCRIPT_DIR/templates"
if [ "${1:-}" != --unlocked ]; then
  TARGET_DIR=${1:-.}
  exec "$SCRIPT_DIR/mlms-lock.sh" "$TARGET_DIR" -- "$SCRIPT_DIR/init-project-memory.sh" --unlocked "$TARGET_DIR"
fi
TARGET_DIR=${2:-.}
RESOLVED=$("$SCRIPT_DIR/resolve-project.sh" "$TARGET_DIR") || exit $?

APPLICATION_ROOT=
WORKTREE_ROOT=
BRANCH=
MLMS_ROOT=
while IFS='=' read -r key value; do
  case "$key" in
    application_root) APPLICATION_ROOT=$value ;;
    worktree_root) WORKTREE_ROOT=$value ;;
    branch) BRANCH=$value ;;
    mlms_root) MLMS_ROOT=$value ;;
  esac
done <<EOF_RESOLVED
$RESOLVED
EOF_RESOLVED

[ -n "$APPLICATION_ROOT" ] && [ -n "$WORKTREE_ROOT" ] && [ -n "$MLMS_ROOT" ] || {
  echo "init-project-memory: resolver returned incomplete application identity" >&2
  exit 1
}
[ ! -L "$MLMS_ROOT" ] || { echo "init-project-memory: sibling MLMS path must not be a symlink" >&2; exit 1; }
LEGACY_ROOT="$APPLICATION_ROOT/.mlms"
if [ -d "$LEGACY_ROOT" ] && [ -n "$(find "$LEGACY_ROOT" -type f ! -path "$LEGACY_ROOT/.git/*" -print -quit)" ]; then
  echo "init-project-memory: embedded memory exists at $LEGACY_ROOT; migrate it before initializing sibling context" >&2
  exit 1
fi

if [ -e "$MLMS_ROOT/.git" ]; then
  actual_root=$(git -C "$MLMS_ROOT" rev-parse --show-toplevel 2>/dev/null) || {
    echo "init-project-memory: sibling has invalid Git metadata: $MLMS_ROOT/.git" >&2
    exit 1
  }
  actual_root=$(CDPATH= cd -- "$actual_root" && pwd -P)
  expected_root=$(CDPATH= cd -- "$MLMS_ROOT" && pwd -P)
  [ "$actual_root" = "$expected_root" ] || {
    echo "init-project-memory: sibling is not an independent Git repository: $MLMS_ROOT" >&2
    exit 1
  }
else
  mkdir -p "$MLMS_ROOT"
  git -C "$MLMS_ROOT" init -q
fi

copy_if_missing() {
  src=$1
  dest=$2
  [ -f "$src" ] || {
    echo "init-project-memory: missing template: $src" >&2
    exit 1
  }
  if [ -e "$dest" ]; then
    echo "skip $dest"
    return 0
  fi
  mkdir -p "$(dirname -- "$dest")"
  cp "$src" "$dest"
  echo "create $dest"
}

copy_if_missing "$TEMPLATE_DIR/projectBrief.md" "$MLMS_ROOT/projectBrief.md"
copy_if_missing "$TEMPLATE_DIR/AGENTS.md" "$MLMS_ROOT/AGENTS.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/activeContext.md" "$MLMS_ROOT/memory-bank/activeContext.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/productContext.md" "$MLMS_ROOT/memory-bank/productContext.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/progress.md" "$MLMS_ROOT/memory-bank/progress.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/decisionLog.md" "$MLMS_ROOT/memory-bank/decisionLog.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/systemPatterns.md" "$MLMS_ROOT/memory-bank/systemPatterns.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/sprintReview.md" "$MLMS_ROOT/memory-bank/sprintReview.md"

echo "application_root=$APPLICATION_ROOT"
echo "worktree_root=$WORKTREE_ROOT"
echo "branch=$BRANCH"
echo "mlms_root=$MLMS_ROOT"
echo "Embedded .mlms, if present, was left unchanged. No commit was created."
