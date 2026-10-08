# Changelog

## Unreleased

### Fixed

- **Plain-language CI job after a force push to `main`.** The push event's base sha
  is not in the clone after a history rewrite, so the job stopped with exit 2. It
  now measures the whole tree, the same as for a new branch.

## 2.0.0 — 2026-10-06

### Added

- **Plugin install.** `.claude-plugin/plugin.json` and `marketplace.json` make the repo
  installable with `/plugin marketplace add josephdecker1/harness-skeleton`. The
  plugin ships the review agent, three skills and two hooks.
- **`review-gate` hook.** Denies `git push`, `gh pr create`, `gh pr ready` and
  `gh pr merge` until the session shows a dispatch of `adversarial-review-agent`.
  It fails open on an unreadable transcript. The user turns it off for a session
  with `REVIEW_GATE=off`, or skips one publish with a `.claude/review-gate.off` file
  that the hook then deletes. The hook denies any agent command or file write that
  names that file. 110 cases and 31 mutation checks, one of them macOS-only, live in `evals/review-gate/`.
- **Rules:** `review-checkpoint.md`, `attempt-before-impossible.md`,
  `ablate-before-theorize.md` and `clean-up-probe-artifacts.md`.
- **Skills:** `handoff` (capture state before a context reset) and `teach-claude`
  (turn a recurring mistake into a proven harness lesson).
- **`evals/LEDGER.md`**, one row per harness lesson.
- **Plain-language gates in CI** (merged from #4).

### Changed

- **`adversarial-review-agent`** is a Claude Code subagent with frontmatter and an
  explicit model pin. Its frames are now necessity, complexity, mess, goal achievement
  and test correctness. It classifies every finding as common or rare path, and it
  treats an earlier closure table as claims to verify.
- **No review cycle cap.** v1 capped the loop at 2 to 3 cycles. The review runs until
  it concedes, unless the user sets a cap.
- **`verify`** walks every hop of the user story and lands the story in an end-to-end
  test.
- **`goal-driven-execution.md`** checks each progress claim against a tool result, and
  says when to skip the rule. **`surgical-changes.md`** spells out orphan cleanup.
- **README** covers both install paths and the lessons from running the harness.

## 1.0.0 — 2026-07-07

First public skeleton: nine surfaces, one runnable secret-scan hook, CI and one eval.
