# Evals

Evals are behavioral tests for the **harness itself**. Unit tests prove your code
works. Evals prove your agent still behaves after something changed underneath it —
a model upgrade, a rule edit, a new hook.

The one question an eval answers: *if I swap the model, does the agent still do the
right thing on the cases I care about?* Without evals, a model upgrade is a leap of
faith. With them, it's a checklist.

## What makes a good eval

- **Behavioral, not cosmetic.** Assert the outcome (the agent refused to hard-code
  the secret; the agent grounded its claim), not the wording.
- **Derived from a real failure.** The best evals are yesterday's bug, frozen. When
  the agent does something you had to correct, write the eval that catches it next
  time.
- **Cheap to run in CI.** An eval you run only by hand decays. Wire it into the
  gate (see `.github/workflows/`).

## The loop

1. The agent does something wrong (or right and worth keeping).
2. Freeze it as an eval: input, the behavior to check, pass criteria.
3. Run it on every model swap and every harness change.
4. A red eval blocks the swap until the harness is fixed or the eval is
   consciously retired.

See `example-eval.md` for the shape.
