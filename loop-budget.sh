#!/usr/bin/env sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
if [ "${1:-}" != --unlocked ]; then
  TARGET_DIR=${1:-.}
  EXECUTION_ID=${2:-}
  ACTION=${3:-increment}
  [ -n "$EXECUTION_ID" ] || { echo "usage: loop-budget.sh <app-checkout> <execution-id> [read|increment]" >&2; exit 2; }
  exec "$SCRIPT_DIR/mlms-lock.sh" "$TARGET_DIR" -- "$SCRIPT_DIR/loop-budget.sh" --unlocked "$TARGET_DIR" "$EXECUTION_ID" "$ACTION"
fi
TARGET_DIR=${2:-.}
EXECUTION_ID=${3:-}
ACTION=${4:-increment}
case "$EXECUTION_ID" in ''|*[!A-Za-z0-9._-]*|*..*) echo "loop-budget: unsafe execution ID" >&2; exit 2 ;; esac
case "$ACTION" in read|increment) ;; *) echo "loop-budget: action must be read or increment" >&2; exit 2 ;; esac
RESOLVED=$("$SCRIPT_DIR/resolve-project.sh" "$TARGET_DIR") || exit $?
MLMS_ROOT=$(printf '%s\n' "$RESOLVED" | sed -n 's/^mlms_root=//p')
BUDGET_DIR="$MLMS_ROOT/executions/$EXECUTION_ID"
BUDGET_FILE="$BUDGET_DIR/activeContext.md"
mkdir -p "$BUDGET_DIR"
if [ ! -f "$BUDGET_FILE" ]; then
  cat > "$BUDGET_FILE" <<DOC
# Active Context
## Current Loop
Loop: 1
Phase: Planning
## Shared Loop Budget
MLMS Root: $MLMS_ROOT
Execution ID: $EXECUTION_ID
Used: 0
Maximum: 5
DOC
fi
used=$(sed -n 's/^Used: *//p' "$BUDGET_FILE" | head -n 1)
maximum=$(sed -n 's/^Maximum: *//p' "$BUDGET_FILE" | head -n 1)
case "$used:$maximum" in *[!0-9:]*|:*) echo "loop-budget: invalid counter in $BUDGET_FILE" >&2; exit 1 ;; esac
if [ "$ACTION" = increment ]; then
  [ "$used" -lt "$maximum" ] || { echo "loop-budget: maximum $maximum reached for $EXECUTION_ID" >&2; exit 3; }
  next=$((used + 1))
  temp_file="$BUDGET_FILE.tmp.$$"
  awk -v next_value="$next" '/^Used: / {$2=next_value} {print}' "$BUDGET_FILE" > "$temp_file"
  mv "$temp_file" "$BUDGET_FILE"
  used=$next
fi
printf 'execution_id=%s\nused=%s\nmaximum=%s\nactive_context=%s\n' "$EXECUTION_ID" "$used" "$maximum" "$BUDGET_FILE"
