# Memory index

Durable facts the agent should recall across sessions live here as one file each,
with a one-line pointer in this index. `CLAUDE.md` imports this index, so it loads
into context every session. The files are read on demand when relevant.

Keep memory for what the code and git history do **not** already record: a
decision and its rationale, a non-obvious constraint, a hard-won gotcha. Don't
memorize what a `grep` would answer.

> Convention: one line per memory — `- [Title](file.md) — one-line hook`.

## Decisions
- [Queue backend: Redis over RabbitMQ](example-decision.md) — chosen for ops
  simplicity given existing Redis; revisit if fan-out exceeds ~10k msg/s.

## Gotchas
_(add as you hit them — the second time you debug the same thing, write it down)_

## Conventions
_(project-specific naming, patterns, or constraints not obvious from the code)_
