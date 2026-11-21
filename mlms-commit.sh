#!/usr/bin/env sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
if [ "${1:-}" != --unlocked ]; then
  TARGET_DIR=${1:-.}
  MESSAGE=${2:-}
  [ -n "$MESSAGE" ] && [ "$#" -ge 3 ] || {
    echo "usage: mlms-commit.sh <app-checkout> <message> <mlms-relative-path>..." >&2
    exit 2
  }
  shift 2
  exec "$SCRIPT_DIR/mlms-lock.sh" "$TARGET_DIR" -- "$SCRIPT_DIR/mlms-commit.sh" --unlocked "$TARGET_DIR" "$MESSAGE" "$@"
fi
TARGET_DIR=${2:-.}
MESSAGE=${3:-}
[ -n "$MESSAGE" ] && [ "$#" -ge 4 ] || { echo "mlms-commit: message and explicit paths required" >&2; exit 2; }
shift 3
RESOLVED=$("$SCRIPT_DIR/resolve-project.sh" "$TARGET_DIR") || exit $?
MLMS_ROOT=$(printf '%s\n' "$RESOLVED" | sed -n 's/^mlms_root=//p')
[ -d "$MLMS_ROOT/.git" ] || { echo "mlms-commit: sibling MLMS is not an independent Git repository" >&2; exit 1; }
for path do
  case "$path" in
    ''|/*|..|../*|*/..|*/../*|.git|.git/*) echo "mlms-commit: unsafe MLMS-relative path: $path" >&2; exit 2 ;;
  esac
  if [ ! -f "$MLMS_ROOT/$path" ] && ! git -C "$MLMS_ROOT" ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    echo "mlms-commit: expected existing or tracked path not found: $path" >&2
    exit 1
  fi
  git -C "$MLMS_ROOT" add -f -- "$path"
done
if git -C "$MLMS_ROOT" diff --cached --quiet -- "$@"; then
  echo "mlms-commit: no material changes; no commit created"
  exit 0
fi
# --only prevents unrelated staged MLMS files from entering this commit.
git -C "$MLMS_ROOT" commit -m "$MESSAGE" --only -- "$@"
