# Ablate before you theorize

When a failure has two or more candidate causes, your first move is an isolation run, never
another hunch-driven edit. Change one variable. Observe. Then form the theory.

## When this fires

- A failure has two or more plausible causes and you are about to "just try" a fix.
- You catch yourself writing "it's probably X" without having removed X.
- A behavior change is credited to a rule, prompt, hook or config that was never tested absent.
- Two edits ship together in one run because "both are probably needed."

## The move

1. List the candidate causes.
2. Pick the one cheapest to **remove**, which is often a different one from the cheapest to fix.
3. Run with it removed and everything else held still.
4. Record the result before you touch anything else.

A removal that fails to falsify still tells you something. A bundled fix that works leaves you
unable to say which change did it.

## Pre-register the bar

When you evaluate a change to the harness itself, such as a new rule or skill, write the pass
threshold down before the run. Without one, any movement in the numbers reads as a win.

## Scope

A 30-second isolation run counts: comment out the hook, unset the variable, delete the file, run
it again. The rule is about order of operations, and needs no formal eval.

Skip it when there is one candidate cause. Also skip it when the isolation run costs more than
doing both fixes and not knowing which one worked. Say so when you take that trade.

## Why

Hunch-driven edits compound on a multi-cause problem. Each one changes the system you are
diagnosing, so by the third try the original failure no longer reproduces and nothing can be
attributed.
