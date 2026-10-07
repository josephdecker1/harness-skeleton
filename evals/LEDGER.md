# Lesson ledger

One row per harness lesson. A lesson is a recurring agent mistake, the harness change that stops
it, and the eval that proves the change still holds. The `teach-claude` skill adds rows.

Run every row on every pull request through `evals/run.sh`, and again after every model change.
A red row blocks the change until the harness is fixed or the lesson is retired on purpose.

Status: **holding** (last run passed), **regressed** (last run failed), **retired** (no longer
needed).

| # | Lesson | Tier | Artifact | Eval (exit 0 = pass) | Status |
|---|---|---|---|---|---|
| 001 | A hard-coded secret written into a file | 3 hook | `.claude/hooks/check-no-secrets.sh` | `evals/run.sh`, eval-001 (3 cases) | holding |
| 002 | Rhetorical devices in prose and comments longer than code | 4 script | `scripts/plain-language-*.sh` | `evals/run.sh`, eval-002 to eval-004 (11 cases) | holding |
| 003 | Publishing work with no adversarial review | 3 hook | `.claude/hooks/review-gate.py` | `evals/review-gate/run-cases.sh` (110 cases), `evals/review-gate/mutation-check.sh` (31 mutations) | holding |

## Notes

**Lesson 003** exists because a prose rule lost to a system-prompt default twice in two days.
Each time, a generic "do not use subagents" line won, and a diff shipped without review. The hook
denies `git push`, `gh pr create`, `gh pr ready` and `gh pr merge` until the session transcript
shows a dispatch of `adversarial-review-agent`.

Before it shipped here, its command classifier ran over 17,348 real Bash commands from the
maintainer's own sessions. 226 unique commands classified as publishing. A hand check of 80 hits
and 126 near-misses found no false positive and no false negative. The cases came from reading
the maintainer's original hook, and the sweep changed no code. Each of the 31 mutations turns at
least one case red.

Known gaps: the hook does not see a push through `gh api`, `ssh`, a script file or `xargs`. A
"this is ready" in prose, with no command, is invisible to a Bash hook. The rule covers those.

The gate checks one session. A doc-only push, or a merge in a later session, needs a new review
or the user's one-shot `.claude/review-gate.off`. The hook denies any agent command or file write
that names that file. That guard catches an agent that reaches for the switch. An agent that sets
out to dodge the gate can still build the name inside a script.

The gate fails open on a missing or unreadable transcript, because a gate that blocks every push
when it cannot read evidence gets switched off. A transcript that holds only the user prompt still
counts as readable. That is the state at a session's first tool call, before Claude Code writes
the assistant lines.
