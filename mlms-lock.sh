#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TARGET_DIR=${1:-.}
[ "$#" -ge 3 ] && [ "${2:-}" = -- ] || {
  echo "usage: mlms-lock.sh <app-checkout> -- <command> [args...]" >&2
  exit 2
}
shift 2
RESOLVED=$("$SCRIPT_DIR/resolve-project.sh" "$TARGET_DIR") || exit $?
MLMS_ROOT=$(printf '%s\n' "$RESOLVED" | sed -n 's/^mlms_root=//p')
[ -n "$MLMS_ROOT" ] || { echo "mlms-lock: resolver returned no MLMS root" >&2; exit 1; }
mkdir -p "$MLMS_ROOT"
LOCK_DIR="${MLMS_ROOT}.update-lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "mlms-lock: update lock already exists at $LOCK_DIR" >&2
  if [ -f "$LOCK_DIR/owner" ]; then
    cat "$LOCK_DIR/owner" >&2
  else
    echo "owner metadata unavailable; inspect lock and remove it manually only after confirming no updater is running" >&2
  fi
  exit 75
fi
printf 'pid=%s\nworktree=%s\n' "$$" "$TARGET_DIR" > "$LOCK_DIR/owner"
cleanup() {
  owner_pid=$(sed -n 's/^pid=//p' "$LOCK_DIR/owner" 2>/dev/null || true)
  if [ "$owner_pid" = "$$" ]; then
    rm -f "$LOCK_DIR/owner"
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
"$@"
