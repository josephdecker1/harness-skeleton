---
name: teach-claude
description: Turn a recurring agent mistake into a durable fix at the right enforcement tier, proven by an eval that fails before the fix and passes after it. Records the lesson in evals/LEDGER.md. Use when the user says "you keep doing X", "make this stop for real" or "add a harness lesson". Also use it to review or re-run the ledger. Not for one-off bugs.
argument-hint: "<the recurring behavior, or 'review ledger'>"
---

# teach-claude

The model does not learn from a correction. Its weights are fixed, and the correction leaves
with the context. A lesson sticks only as a harness change plus an eval that proves the change
holds. The eval is also what lets you swap models without guessing.

## When to use

- The same mistake has happened at least twice, despite a rule or memory meant to stop it
- The user asks for a correction to hold for real
- Ledger upkeep: re-run the evals, or check them after a model change

## When not to use

- A one-off bug: fix it
- A fact or preference: write a memory
- A job a script can own outright: write the script, because it needs no lesson

## The loop

**SELECT → DIAGNOSE → AUTHOR → PROVE → RETAIN**

1. **SELECT.** Cite at least two real instances: a session, a review finding, a log line. With
   fewer than two, say so and stop.
2. **DIAGNOSE.** Why did the current tier fail? *Never recalled*, *recalled but not enforced*, or
   *enforced but wrong*. The answer picks the tier.
3. **AUTHOR.** Write the eval cases first, from the real instances. Write the expected result of
   each case before any run. Then write the fix.
4. **PROVE.** Red-green. The eval fails against the old behavior and passes against the new.
   Then mutate the fix one point at a time, and check that each mutation turns at least one case
   red. A mutation nothing catches means a case is missing.
5. **RETAIN.** Add a row to `evals/LEDGER.md`, wire the eval into `evals/run.sh` so CI runs it,
   and re-run the ledger at every model change. A regression goes back to DIAGNOSE, usually
   because the tier was too low.

## Enforcement tiers

Pick the highest tier that fits.

| Tier | Mechanism | It holds because |
|---|---|---|
| 0 memory | recalled into context | the model recalls it and complies |
| 1 rule | always-loaded prose | the model complies |
| 2 skill | a procedure invoked by name | the routing picks it |
| 3 hook | runs on a tool event and can block | the harness runs it, every time |
| 4 script or config | no model in the loop | there is nothing to persuade |

Prose loses to system-prompt defaults under pressure. When a rule has failed twice, the next
tier is usually a hook.

## The bar for a blocking hook

- **Zero false positives.** A gate that blocks good work gets switched off, and then it protects
  nothing.
- **Sweep real history before you wire it.** Run the classifier over real commands from past
  sessions and hand-check a sample of hits and near-misses. A corpus measures its author's
  imagination. History measures the work.
- **Name the off switch in every denial**, and say it belongs to the user. A gate with no
  override is a wall.
- **Never mutate the live hook.** Mutation tests run on a copy.

## Guards

- At least two instances per lesson, and at most three lessons open at once
- Run the review checkpoint before you apply a lesson that changes a hook or a rule
