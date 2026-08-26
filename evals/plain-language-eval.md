---
id: eval-002-plain-language-gates
gates: rule-change, script-change
severity: medium
---

# eval-002/003/004 — the plain-language gates still hold

## Origin

`plain-language.md` shipped with two gate scripts printed inside it as fenced
blocks. A rule that prints a check it never runs is a claim nobody tested. These
evals move the scripts into `scripts/`, run them against fixtures, and pin the
failure modes that a green run would otherwise hide.

Each one froze a defect found during review of the gates themselves.

## What each eval checks

| Eval | Fixture | Pass criteria |
|---|---|---|
| eval-002 | prose carrying a framing tic | exit 1, and clean prose exits 0 |
| eval-002 | the gate called with no files | it prints its no-files message |
| eval-003 | 4 added comment lines over 1 added code line | exit 1 |
| eval-003 | 1 added comment line over 4 added code lines | exit 0 |
| eval-003 | a `git diff` flag passed as the argument | exit 2 |
| eval-003 | a directory that is not a git repository | exit 2 |
| eval-004 | each fenced block against its committed script | byte-identical |
| eval-004 | a heading that does not exist | exit 2 |
| eval-004 | a longer heading sitting above the real one | the real block wins |

## Why the odd ones matter

**The no-files case.** Gate 1 reads stdin when it gets no arguments. The CI step
pipes changed filenames through `xargs`, and GNU `xargs` runs the command once
with no arguments when the list is empty. Without the guard the gate would scan
the CI runner's stdin. The eval asserts the message rather than the exit code,
because deleting the guard still exits 0.

**The flag argument.** Gate 2 passes its argument to `git diff`. Flags such as
`--stat` and `--name-only` empty the diff body, and the parser reads an empty
body as clean. Eight such flags exited 0 before the guard.

**The two copies.** Gate 1 and gate 2 each live twice, once as a fenced block in
`plain-language-gates.md` and once as a file in `scripts/`. A drifted copy is
worse than no copy, because the rule then documents a check the repo does not
run. eval-004 re-extracts each block and diffs it.

## Running it

```
./evals/run.sh
```

All of this half is deterministic and needs no credentials. The CI `eval-gate`
job runs it on every push, so a regression turns the build red.

The behavioral half is not written. Whether an *agent* obeys rule 6 unprompted
needs a live model and a graded rubric. These evals prove the gates work, not
that the model complies.

## A note on this file

The CI step for gate 1 skips `.claude/rules/plain-language*`, because those three
files quote the banned phrases as examples. The skip is anchored to that
directory, so this file is read like any other. It describes its fixtures rather
than quoting them, and gate 1 reads it clean.

An earlier draft matched the substring `plain-language` anywhere in the path.
That let any file opt itself out of gate 1 by choosing its own name.

## Fail = block

A red result blocks the rule edit or script change that produced it. Fix the
gate, or retire the eval with a recorded reason. Never silently.
