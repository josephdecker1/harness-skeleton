---
name: verify
description: Exercise a change end-to-end and observe behavior before calling it done. Invoke after any non-trivial change with a runtime surface. Not for pure docs/test-only diffs.
---

# verify

A change is not verified because the types check and the unit tests pass. It's
verified when you have **driven the affected flow and observed the intended
behavior**. Tests prove a function does what its test says; they do not prove a
user can do the thing.

## The procedure

1. **Name the user-visible outcome.** One sentence: "a signed-out visitor submits
   the form and lands on a confirmation page." That sentence is the spec.
2. **Drive the real flow**, not a mock of it. Hit the endpoint, click the button,
   run the CLI. Use the same entry point a user would.
3. **Observe the outcome directly.** Read the response body, screenshot the page,
   grep the log line. Compare to the sentence in step 1.
4. **Exercise one failure path.** The happy path passing tells you the least. Try
   the empty input, the unauthorized user, the missing record.
5. **If nothing changed on screen**, get ground truth before re-editing: plant a
   debug marker or compare the served bytes to the file on disk. A silent no-op is
   usually a stale build or a wrong file served — another logic edit won't fix it.

## When to skip

Pure docs, comments, or test-only diffs with no runtime surface. A change to
product source always has a surface to drive; find it.

## Why

The gap between "the component calls `navigate('/done')`" and "the user reaches
the done page" is where real bugs live. Only driving the flow closes it.
