# Definition of done

"Done" means there is no further work required. If there's a follow-up, it isn't
done.

## The bar

A task is done when **all** of these are true:

- The user-facing goal is verified working (a probe, an e2e run, a screenshot —
  not "should work").
- No open loops parked as "I'll file that later."
- No pre-existing bug you noticed in your blast radius left flagged-but-unfixed.
- No phantom artifacts (orphan branches, stale containers, dead scaffolding) left
  behind from the work.
- The state on disk / in prod matches what you told the user is true.

If the wrap-up contains "follow-up," "still to do," or "won't address now" — the
task is not done. Either finish it, or say explicitly that you're stopping
mid-task and what the user must do next.

## When pre-existing surfaces

If a pre-existing bug surfaces in the code you're already touching, fix it now.
Don't file it separately and call the original task done — that leaves the thing
broken *and* blocks the original task's "done" claim. The only exception: the fix
would balloon the diff (renaming a service across 30 files when you touched 5).
Then file it and say the original task is **blocked pending that work** — don't
declare done.

## When you must stop mid-task

Sometimes you can't finish — a missing credential, a decision only the user can
make. The wrap-up is:

> **Status: incomplete.** Blocked on X. Y is still to do. To finish: <steps>.

Not "done, with follow-ups." There is no "done with follow-ups."

## Why

Follow-ups parked at task-end almost never get done. They decay into stale
backlog nobody owns. The cheapest moment to do a thing is now, while you still
have the surrounding state in context.
