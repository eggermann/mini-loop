#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TEMPLATE_DIR="$SCRIPT_DIR/templates"
TARGET_DIR="${1:-.}"
MEMORY_ROOT="$TARGET_DIR/.mlms"

mkdir -p "$MEMORY_ROOT"

copy_if_missing() {
  src="$1"
  dest="$2"

  if [ -e "$dest" ]; then
    echo "skip $dest"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo "create $dest"
}

copy_if_missing "$TEMPLATE_DIR/projectBrief.md" "$MEMORY_ROOT/projectBrief.md"
copy_if_missing "$TEMPLATE_DIR/AGENTS.md" "$MEMORY_ROOT/AGENTS.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/activeContext.md" "$MEMORY_ROOT/memory-bank/activeContext.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/productContext.md" "$MEMORY_ROOT/memory-bank/productContext.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/progress.md" "$MEMORY_ROOT/memory-bank/progress.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/decisionLog.md" "$MEMORY_ROOT/memory-bank/decisionLog.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/systemPatterns.md" "$MEMORY_ROOT/memory-bank/systemPatterns.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/sprintReview.md" "$MEMORY_ROOT/memory-bank/sprintReview.md"
