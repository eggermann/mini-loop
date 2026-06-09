# AGENTS.md

## Codex Workflow

Before doing implementation work:

1. Read `projectBrief.md`.
2. Read all files in `memory-bank/`.
3. Identify current loop phase from `memory-bank/activeContext.md`.

During work:

1. Keep changes small.
2. Prefer a vertical slice over broad unfinished edits.
3. Record important architectural or product decisions.
4. Run available tests/checks when possible.
5. Do not push automatically.
6. Do not delete files without explicit user approval.

After meaningful work:

1. Update `memory-bank/activeContext.md`.
2. Update `memory-bank/progress.md`.
3. Update `memory-bank/decisionLog.md` if a decision was made.
4. Update `memory-bank/sprintReview.md` after review.
5. State next recommended action.

## Auto-Commit Policy

Auto-commit is allowed only after user grants permission.

When enabled:

- Commit after each green vertical slice.
- Never commit failing checks unless user explicitly requests a WIP commit.
- Never include unrelated files.
- Update memory bank before committing.
- Do not auto-push.
