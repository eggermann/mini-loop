#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_DIR="$SCRIPT_DIR/skills/mini-loop-memory-scrum"
TARGET_DIR="${CODEX_HOME:-$HOME/.codex}/skills/mini-loop-memory-scrum"

if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
  echo "Missing source skill: $SOURCE_DIR/SKILL.md" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET_DIR")"
rm -rf "$TARGET_DIR"
cp -R "$SOURCE_DIR" "$TARGET_DIR"

echo "Installed skill to: $TARGET_DIR"
