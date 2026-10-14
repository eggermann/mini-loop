#!/usr/bin/env sh
set -eu

REPO_URL=${1:-https://raw.githubusercontent.com/eggermann/mini-loop/main}
TARGET_DIR="${CODEX_HOME:-$HOME/.codex}/skills/mini-loop-memory-scrum"
TMP_DIR=$(mktemp -d)
STAGING_DIR="${TARGET_DIR}.install.$$"
cleanup() {
  rm -rf "$TMP_DIR" "$STAGING_DIR"
}
trap cleanup EXIT INT TERM
mkdir -p "$TMP_DIR/bin/templates/memory-bank"
fetch() {
  curl -fsSL "$REPO_URL/$1" -o "$TMP_DIR/$2"
}
fetch "skills/mini-loop-memory-scrum/SKILL.md" "SKILL.md"
for file in resolve-project.sh mlms-lock.sh init-project-memory.sh migrate-project-memory.sh select-context.sh loop-budget.sh reconcile-subgoal.sh mlms-commit.sh; do
  fetch "$file" "bin/$file"
done
fetch "templates/AGENTS.md" "bin/templates/AGENTS.md"
fetch "templates/projectBrief.md" "bin/templates/projectBrief.md"
for file in activeContext productContext progress decisionLog systemPatterns sprintReview; do
  fetch "templates/memory-bank/$file.md" "bin/templates/memory-bank/$file.md"
done
[ -s "$TMP_DIR/SKILL.md" ] || { echo "Failed to download skill from $REPO_URL" >&2; exit 1; }
mkdir -p "$STAGING_DIR"
cp "$TMP_DIR/SKILL.md" "$STAGING_DIR/SKILL.md"
cp -R "$TMP_DIR/bin" "$STAGING_DIR/bin"
chmod +x "$STAGING_DIR/bin/"*.sh
mkdir -p "$(dirname "$TARGET_DIR")"
rm -rf "$TARGET_DIR"
mv "$STAGING_DIR" "$TARGET_DIR"
echo "Installed skill and runtime helpers to: $TARGET_DIR"
