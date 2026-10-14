#!/usr/bin/env sh
set -eu

PROJECT_DIR=${1:-mini-loop}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

mkdir -p "$PROJECT_DIR/skills/mini-loop-memory-scrum" "$PROJECT_DIR/templates/memory-bank"
cp "$SCRIPT_DIR/README.md" "$PROJECT_DIR/README.md"
cp "$SCRIPT_DIR/create.sh" "$PROJECT_DIR/create.sh"
for file in init-project-memory.sh resolve-project.sh mlms-lock.sh migrate-project-memory.sh select-context.sh loop-budget.sh reconcile-subgoal.sh mlms-commit.sh install-skill.sh install-from-github.sh; do
  cp "$SCRIPT_DIR/$file" "$PROJECT_DIR/$file"
done
cp -R "$SCRIPT_DIR/skills/mini-loop-memory-scrum/." "$PROJECT_DIR/skills/mini-loop-memory-scrum/"
cp "$SCRIPT_DIR/templates/AGENTS.md" "$PROJECT_DIR/templates/AGENTS.md"
cp "$SCRIPT_DIR/templates/projectBrief.md" "$PROJECT_DIR/templates/projectBrief.md"
cp -R "$SCRIPT_DIR/templates/memory-bank/." "$PROJECT_DIR/templates/memory-bank/"
chmod +x "$PROJECT_DIR"/*.sh

echo "Created Mini-Loop project package: $PROJECT_DIR"
echo "Runtime helpers, skill, and sibling-MLMS templates included."
