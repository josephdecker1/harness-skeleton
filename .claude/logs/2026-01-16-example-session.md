# Session log — 2026-01-16 — add the secret-scan PreToolUse hook

An example of the log this template produces. A future session (or teammate) can
reconstruct *why* the hook looks the way it does without asking.

## Goal

Stop the agent from ever writing a hard-coded secret into a file. Verifiable
outcome: a Write or Edit whose content contains an obvious key shape is blocked
before it lands, and clean content passes untouched.

## What happened

Started with a rule (`don't hard-code secrets`) but a rule is advisory — the agent
can forget it. Moved the check to a `PreToolUse` hook so the harness enforces it,
not the model.

First pass only read the Write tool's `content` field. Red-green testing caught
two real bugs before this shipped:

- The hook no-op'd on `Edit` calls — Edit's payload has `new_string`, not
  `content`, so every edited-in secret sailed through. Fixed by scanning both
  fields (`check-no-secrets.sh:29`).
- The PEM pattern starts with `-`, so `grep` parsed it as an option and silently
  skipped it — a real private key would not have matched. Fixed with `grep -e`
  (`check-no-secrets.sh:52`).

Also made it fail **closed**: if the payload can't be parsed, block rather than
allow an unscanned write.

## Decisions

- **Scan `new_string` but not `old_string`.** `old_string` is the text being
  removed; blocking it would stop you from deleting a secret that's already in the
  file. Candidate for promotion to `.claude/memory/` if it comes up again.
- **CI re-runs the same patterns** as a backstop for the hook, using the empty
  tree as the diff base so the very first commit is scanned too.

## State at end

- Branch / PR: `feature/secret-scan-hook` → merged.
- Verified working: `./evals/run.sh` green — Write-secret blocked, Edit-secret
  blocked, clean content allowed; CI `harness-gate` green on the PR.
- Incomplete / handed off: none. The hook covers five key shapes; extend
  `patterns` in `check-no-secrets.sh` as new secret formats show up.
