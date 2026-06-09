#!/usr/bin/env sh
set -eu

PROJECT_DIR="${1:-mini-loop}"
SKILL_NAME="mini-loop-memory-scrum"

mkdir -p "$PROJECT_DIR/skills/$SKILL_NAME"
mkdir -p "$PROJECT_DIR/templates/memory-bank"

cp README.md "$PROJECT_DIR/README.md"
cp skills/mini-loop-memory-scrum/SKILL.md "$PROJECT_DIR/skills/$SKILL_NAME/SKILL.md"
cp templates/projectBrief.md "$PROJECT_DIR/templates/projectBrief.md"
cp templates/AGENTS.md "$PROJECT_DIR/templates/AGENTS.md"
cp templates/memory-bank/activeContext.md "$PROJECT_DIR/templates/memory-bank/activeContext.md"
cp templates/memory-bank/productContext.md "$PROJECT_DIR/templates/memory-bank/productContext.md"
cp templates/memory-bank/progress.md "$PROJECT_DIR/templates/memory-bank/progress.md"
cp templates/memory-bank/decisionLog.md "$PROJECT_DIR/templates/memory-bank/decisionLog.md"
cp templates/memory-bank/systemPatterns.md "$PROJECT_DIR/templates/memory-bank/systemPatterns.md"
cp templates/memory-bank/sprintReview.md "$PROJECT_DIR/templates/memory-bank/sprintReview.md"
