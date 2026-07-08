# Goal-driven execution

For any non-trivial task, restate it as verifiable success criteria before
writing code. Then loop until verified.

## The transform

| Imperative | Goal-driven |
|---|---|
| "Add validation" | "Write tests for invalid inputs, then make them pass" |
| "Fix the bug" | "Write a test that reproduces it, then make it pass" |
| "Refactor X" | "Tests green before and after; behavior unchanged" |
| "Make it faster" | "Define the metric + target (p50 < 100ms) before optimizing" |

## Multi-step format

For tasks with more than one step, state the plan as step → check pairs:

```
1. [step]  → verify: [observable check]
2. [step]  → verify: [observable check]
```

Each verify line must be something you can actually observe — a test passing, a
curl returning the expected shape, a log line appearing. Not "looks right" or
"should work."

## Why

Strong success criteria let the agent (and its subagents) loop independently.
Weak criteria — "make it work" — force constant clarification and re-rolls.
Declarative goals plus verify loops beat imperative instructions every time.
