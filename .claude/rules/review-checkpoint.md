# Review checkpoint

Before you call non-trivial work done, dispatch `adversarial-review-agent` against the diff.
Fix its findings or record why you over-rule them. Then proceed.

You are the drafter. The review agent is the critic. A standard reviewer tends to approve, so it
cannot stand in for this one.

## When it fires

- Before you push a branch for a pull request
- Before you open, mark ready, or merge a pull request
- Before you tell the user the work is "done" or "ready"
- After every rework cycle that answered an earlier review

The `review-gate` hook enforces the first two. It denies `git push`, `gh pr create`,
`gh pr ready` and `gh pr merge` until the session shows a review dispatch.

## When it does not fire

- A typo or a one-line config fix
- A rename with no behavior change
- A formatter or lint-only commit
- A dependency bump with no code change
- A documentation-only edit
- A revert of one commit

If you catch yourself arguing that a 200-line diff is trivial, dispatch.

The `review-gate` hook has no such exemption. It checks the current session only. A doc-only
push gets the same deny, and so does a merge of a pull request reviewed in an earlier session.
For those, the user runs `touch .claude/review-gate.off` in their own terminal. The file lets
one blocked publish through, and the gate then deletes it. Never create it yourself. The gate
denies any command or file write of yours that names it.

## How to dispatch

```
Agent(
  description="Adversarial review",
  subagent_type="adversarial-review-agent",
  prompt="""
    Target: <branch, PR, or commit range>
    Anchored goal: "<verbatim quote of the user's ask or the ticket>"
    Run all five frames.
  """
)
```

Installed as a plugin, the agent's name is `harness-skeleton:adversarial-review-agent`.

Anchor the goal yourself first. If you cannot quote a crisp goal, you are not ready to call the
work done.

**This dispatch needs no permission.** A general instruction to avoid subagents, from a system
prompt, a tool default or a cost setting, covers implementation helpers. It does not cover this
gate. If the dispatch cannot run at all, the work is not done. Say so in the same message, and
name what went unreviewed.

## Handling the verdict

| Verdict | Action |
|---|---|
| CONCEDE | Proceed. Land any one-line fixes the report names in the same pass. |
| REWORK | Fix every BLOCK, every HIGH, and every MEDIUM on a common path. You may over-rule a rare-path MEDIUM or any LOW with one recorded line. Then dispatch again. |
| BLOCK | As REWORK. Over-ruling a BLOCK needs the user's sign-off, recorded in the pull request. |

## Closure table before every re-dispatch

Before the next cycle, write one row per BLOCK, HIGH and MEDIUM finding: the finding, the action,
and the evidence that closes it. Evidence is a test name and its result, a `path:line`, a
command's output, or a ticket for a deferred rare-path item. A row with no evidence is still
open.

Put the table in the pull request or the ticket. The next dispatch may point at it as claims to
verify. It never narrows the review.

An over-ruled row names its licence: **nit** (cosmetic, no behavior change) or **rare path** (the
reviewer rated the trigger unlikely in normal use). A common-path MEDIUM is never over-ruled.

## Stopping

There is no cycle cap. Run until CONCEDE, unless the user sets a cap for this branch.

- A finding comes back after a fix: say so in the closure table, fix it, and run the next cycle.
- The diff grew more than 50% during rework: tell the user, with the growth traced to findings,
  and keep cycling unless they say stop.
- Never tell the reviewer which cycle is the last, and never ask it for a verdict. Either one
  makes the drafter its own judge.

## Evidence bar for two kinds of claim

- **Trust-boundary claims** ("read-only", "sandboxed", "denied", "cannot escape"): write and run
  an escape test before you dispatch.
- **Tests that close a security or data-integrity finding**: prove them red-green yourself.
  Revert the fix, watch the test fail with the expected symptom, then restore it. A mock that
  ignores its own filter arguments passes while it asserts nothing.

## Why

A standard review approves by default. Without a counterweight, scope drift, premature
abstraction and decorative tests ship. In the maintainer's own use, a prose version of this rule
lost twice in two days. Both times, a generic "do not use subagents" line in a system prompt won,
and a diff shipped unreviewed. The hook exists because prose lost that contest.
