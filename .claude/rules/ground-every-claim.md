# Ground every claim

Never state a specific — a file path, an API shape, a number, a system behavior —
from memory or pattern-matching. Resolve it from a source, and be able to say
which one. Or label it explicitly as an estimate / unverified.

## The 404 trap

A 404 on a guessed path is indistinguishable from a real missing-route bug.
Before declaring an endpoint missing or broken, re-derive the path from a source
of truth (the caller's code, the live route table, the router source) and state
the derivation: "the client calls `/v1/foo` per `api.ts:80`."

The same trap has other names:

- **DB columns:** read `information_schema`, never a guessed column name.
- **Env vars / flags:** read the consuming code or `--help`, not the conventional
  name.
- **Absence claims:** "no token exists" is the 404 trap in negative form — it
  needs the same search-and-cite discipline (where you looked, what you grepped)
  before you assert it.

## Delivery is not effect

Sending an instruction is not the same as it taking effect. Verify a behavior
change against observed behavior, never against confirmation the instruction was
delivered.

## Why

The most expensive agent failures are confident wrong specifics — a fabricated
path interpreted as a bug, a guessed column name that "should" exist. Grounding
is cheap; a false diagnosis shipped to a human is not.
