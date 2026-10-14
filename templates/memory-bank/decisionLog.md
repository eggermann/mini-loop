# Decision Log

## Decisions

### D-0001: Use Memory Bank + Scrum/Vibe Mini-Loop

Status: Accepted

Scope: Project-wide

Context:
Project needs persistent context across Codex/Roo sessions and repeatable development rhythm.

Decision:
Use a Markdown memory bank for durable context and a Scrum/Vibe mini-loop for planning, implementation, review, retrospective, and memory updates.

Consequences:
Codex reads and updates the relevant sibling MLMS context under the shared update lock.

## Proposals

Branch-local experiments remain proposals until reviewed. Preserve conflicting proposals and require explicit resolution before promoting one to project-wide accepted status.

## Superseded Decisions

None.
