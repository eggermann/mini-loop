#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TEMPLATE_DIR="$SCRIPT_DIR/templates"
if [ "${1:-}" != --unlocked ]; then
  TARGET_DIR=${1:-.}
  exec "$SCRIPT_DIR/mlms-lock.sh" "$TARGET_DIR" -- "$SCRIPT_DIR/migrate-project-memory.sh" --unlocked "$TARGET_DIR"
fi
TARGET_DIR=${2:-.}
RESOLVED=$("$SCRIPT_DIR/resolve-project.sh" "$TARGET_DIR") || exit $?
APPLICATION_ROOT=$(printf '%s\n' "$RESOLVED" | sed -n 's/^application_root=//p')
MLMS_ROOT=$(printf '%s\n' "$RESOLVED" | sed -n 's/^mlms_root=//p')
LEGACY_ROOT="$APPLICATION_ROOT/.mlms"
[ -d "$LEGACY_ROOT" ] || { echo "migrate-project-memory: no embedded .mlms directory at $LEGACY_ROOT" >&2; exit 1; }
[ -n "$MLMS_ROOT" ] || { echo "migrate-project-memory: resolver returned no MLMS root" >&2; exit 1; }
[ ! -L "$MLMS_ROOT" ] || { echo "migrate-project-memory: sibling MLMS path must not be a symlink" >&2; exit 1; }

if [ -n "$(find "$LEGACY_ROOT" -type l -print -quit)" ]; then
  echo "migrate-project-memory: symlinks found; refusing unsafe migration" >&2
  exit 1
fi
if [ -n "$(find "$LEGACY_ROOT" ! -type d ! -type f -print -quit)" ]; then
  echo "migrate-project-memory: special files found; refusing unsafe migration" >&2
  exit 1
fi
mkdir -p "$MLMS_ROOT"

# Preflight every path before copying anything. POSIX find passes each full path
# as an argument, so spaces and newlines remain intact. Embedded Git metadata is skipped.
find "$LEGACY_ROOT" -type f -exec sh -c '
  legacy_root=$1
  mlms_root=$2
  shift 2
  for source_file do
    relative=${source_file#"$legacy_root"/}
    case "$relative" in .git|.git/*) continue ;; esac
    destination="$mlms_root/$relative"
    parent=$(dirname -- "$destination")
    if [ -L "$destination" ] || [ -L "$parent" ]; then
      echo "migrate-project-memory: symlinked destination path: $destination" >&2
      exit 1
    fi
    if [ -e "$destination" ] && [ ! -f "$destination" ]; then
      echo "migrate-project-memory: destination path type conflict: $destination" >&2
      exit 1
    fi
    if [ -e "$destination" ] && ! cmp -s "$source_file" "$destination"; then
      echo "migrate-project-memory: content conflict; resolve manually: $relative" >&2
      exit 1
    fi
    if [ -e "$parent" ] && [ ! -d "$parent" ]; then
      echo "migrate-project-memory: parent path type conflict: $parent" >&2
      exit 1
    fi
  done
' sh "$LEGACY_ROOT" "$MLMS_ROOT" {} +
[ $? -eq 0 ] || exit 1

if [ -e "$MLMS_ROOT/.git" ]; then
  actual_root=$(git -C "$MLMS_ROOT" rev-parse --show-toplevel 2>/dev/null) || {
    echo "migrate-project-memory: invalid sibling Git metadata" >&2
    exit 1
  }
  [ "$(CDPATH= cd -- "$actual_root" && pwd -P)" = "$(CDPATH= cd -- "$MLMS_ROOT" && pwd -P)" ] || {
    echo "migrate-project-memory: sibling is not an independent repository" >&2
    exit 1
  }
else
  git -C "$MLMS_ROOT" init -q
fi

find "$LEGACY_ROOT" -type f -exec sh -c '
  legacy_root=$1
  mlms_root=$2
  shift 2
  for source_file do
    relative=${source_file#"$legacy_root"/}
    case "$relative" in .git|.git/*) continue ;; esac
    destination="$mlms_root/$relative"
    if [ ! -e "$destination" ]; then
      mkdir -p "$(dirname -- "$destination")"
      cp -p "$source_file" "$destination" || exit 1
    fi
  done
' sh "$LEGACY_ROOT" "$MLMS_ROOT" {} +

copy_if_missing() {
  source_file=$1
  destination=$2
  if [ ! -e "$destination" ]; then
    mkdir -p "$(dirname -- "$destination")"
    cp "$source_file" "$destination"
  fi
}
copy_if_missing "$TEMPLATE_DIR/projectBrief.md" "$MLMS_ROOT/projectBrief.md"
copy_if_missing "$TEMPLATE_DIR/AGENTS.md" "$MLMS_ROOT/AGENTS.md"
for file in activeContext productContext progress decisionLog systemPatterns sprintReview; do
  copy_if_missing "$TEMPLATE_DIR/memory-bank/$file.md" "$MLMS_ROOT/memory-bank/$file.md"
done

# Verify every source file is present and identical at the sibling destination.
find "$LEGACY_ROOT" -type f -exec sh -c '
  legacy_root=$1
  mlms_root=$2
  shift 2
  for source_file do
    relative=${source_file#"$legacy_root"/}
    case "$relative" in .git|.git/*) continue ;; esac
    cmp -s "$source_file" "$mlms_root/$relative" || {
      echo "migrate-project-memory: verification failed: $relative" >&2
      exit 1
    }
  done
' sh "$LEGACY_ROOT" "$MLMS_ROOT" {} +

echo "Migrated embedded memory to $MLMS_ROOT; original $LEGACY_ROOT remains intact. No commit created."
