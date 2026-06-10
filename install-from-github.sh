#!/usr/bin/env sh
set -eu

REPO_URL="${1:-https://raw.githubusercontent.com/eggermann/mini-loop/main}"
TARGET_DIR="${CODEX_HOME:-$HOME/.codex}/skills/mini-loop-memory-scrum"
TMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

mkdir -p "$TMP_DIR/mini-loop-memory-scrum"

fetch() {
  src="$1"
  dest="$2"
  curl -fsSL "$REPO_URL/$src" -o "$dest"
}

fetch "skills/mini-loop-memory-scrum/SKILL.md" "$TMP_DIR/mini-loop-memory-scrum/SKILL.md"

if [ ! -s "$TMP_DIR/mini-loop-memory-scrum/SKILL.md" ]; then
  echo "Failed to download skill from $REPO_URL" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET_DIR")"
rm -rf "$TARGET_DIR"
cp -R "$TMP_DIR/mini-loop-memory-scrum" "$TARGET_DIR"

echo "Installed skill to: $TARGET_DIR"
