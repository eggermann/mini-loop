# Decision Log

## Decisions

### D-0001: Use Memory Bank + Scrum/Vibe Mini-Loop

Status: Accepted

Context:
Project needs persistent context across Codex/Roo sessions and repeatable development rhythm.

Decision:
Use a `memory-bank/` directory for durable context and a Scrum/Vibe mini-loop for planning, implementation, review, retrospective, and memory updates.

Consequences:
Codex must read and update `memory-bank/` files during each loop.
