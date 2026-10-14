#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SOURCE_DIR="$SCRIPT_DIR/skills/mini-loop-memory-scrum"
TARGET_DIR="${CODEX_HOME:-$HOME/.codex}/skills/mini-loop-memory-scrum"
STAGING_DIR="${TARGET_DIR}.install.$$"

[ -f "$SOURCE_DIR/SKILL.md" ] || { echo "Missing source skill: $SOURCE_DIR/SKILL.md" >&2; exit 1; }
mkdir -p "$STAGING_DIR/bin/templates/memory-bank"
cp "$SOURCE_DIR/SKILL.md" "$STAGING_DIR/SKILL.md"
for file in resolve-project.sh mlms-lock.sh init-project-memory.sh migrate-project-memory.sh select-context.sh loop-budget.sh reconcile-subgoal.sh mlms-commit.sh; do
  [ -f "$SCRIPT_DIR/$file" ] || { echo "Missing runtime helper: $SCRIPT_DIR/$file" >&2; exit 1; }
  cp "$SCRIPT_DIR/$file" "$STAGING_DIR/bin/$file"
done
cp "$SCRIPT_DIR/templates/AGENTS.md" "$STAGING_DIR/bin/templates/AGENTS.md"
cp "$SCRIPT_DIR/templates/projectBrief.md" "$STAGING_DIR/bin/templates/projectBrief.md"
cp -R "$SCRIPT_DIR/templates/memory-bank/." "$STAGING_DIR/bin/templates/memory-bank/"
chmod +x "$STAGING_DIR/bin/"*.sh
rm -rf "$TARGET_DIR"
mv "$STAGING_DIR" "$TARGET_DIR"
echo "Installed skill and runtime helpers to: $TARGET_DIR"
