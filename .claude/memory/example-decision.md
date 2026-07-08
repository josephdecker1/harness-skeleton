---
title: Queue backend — Redis over RabbitMQ
type: decision
date: 2026-01-15
---

# Queue backend: Redis over RabbitMQ

**Decision:** Use Redis (with a lightweight queue library) for the background job
queue, not RabbitMQ.

**Why:** The service already runs Redis for caching and session storage. Adding
RabbitMQ means a second broker to operate, monitor, and upgrade for a job volume
that is comfortably within Redis's range. Operational simplicity wins here; we are
not at a scale where RabbitMQ's richer routing earns its keep.

**Revisit when:** Sustained fan-out exceeds ~10k messages/sec, or we need complex
topic routing / dead-letter semantics that the Redis-based library can't express
cleanly. At that point the second broker is worth its weight.

**What this is not:** a claim that Redis is always the right queue. It's the right
call *given this service's existing infra and current scale*. Delete this file if
that stops being true.
