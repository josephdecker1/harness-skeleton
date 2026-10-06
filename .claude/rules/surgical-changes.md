# Surgical changes

Touch only what the task requires. Clean only your own mess.

## When editing existing code

- Don't "improve" adjacent code, comments, or formatting the task didn't touch.
- Don't refactor things that aren't broken. Match the existing style even if you'd
  write it differently.
- If you spot unrelated dead code or a smell, mention it — don't delete it in the
  same diff.

## Orphan cleanup

- Remove imports, variables and functions that **your** change made unused.
- Leave pre-existing dead code alone unless the task asks for its removal.

## The diff test

Every changed line should trace directly to the task. If a reviewer asks "why did
this change?" and the answer isn't the task, revert it.

## Not a shield

This bounds *unrelated drive-by* edits. It is not license to skip cheap,
obviously-correct cleanups in the exact lines you're already touching — drop the
import you just orphaned, fix the typo in the string you just edited. Fix those
now, same diff. The test: would a reviewer be surprised or annoyed by the extra
change? If no, it belongs.

## Why

Drive-by edits inflate diffs, mix concerns, and bury the real change in noise.
Reviewers (including future-you) lose the signal. Bundled refactors also expand
blast radius without expanding the test surface.
