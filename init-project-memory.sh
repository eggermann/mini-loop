#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TEMPLATE_DIR="$SCRIPT_DIR/templates"
TARGET_DIR="${1:-.}"

mkdir -p "$TARGET_DIR"

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

copy_if_missing "$TEMPLATE_DIR/projectBrief.md" "$TARGET_DIR/projectBrief.md"
copy_if_missing "$TEMPLATE_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/activeContext.md" "$TARGET_DIR/memory-bank/activeContext.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/productContext.md" "$TARGET_DIR/memory-bank/productContext.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/progress.md" "$TARGET_DIR/memory-bank/progress.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/decisionLog.md" "$TARGET_DIR/memory-bank/decisionLog.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/systemPatterns.md" "$TARGET_DIR/memory-bank/systemPatterns.md"
copy_if_missing "$TEMPLATE_DIR/memory-bank/sprintReview.md" "$TARGET_DIR/memory-bank/sprintReview.md"
