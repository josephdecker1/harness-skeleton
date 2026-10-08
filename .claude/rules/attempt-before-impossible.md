# Try before you call it impossible

"Blocked", "not possible" and "not viable" are strong claims. They need proof, the same way a
passing test needs to have run. An argument that ends in "not possible" proves nothing until you
try.

## The rule

Never report a task as impossible or blocked without an attempt log. Fill all three lines:

```
TRIED:        <the command, edit or code path you actually ran>
WALL:         <the exact error or denial text, not a paraphrase>
SMALLEST-FIX: <the smallest change that would make it work>
```

If you cannot fill `TRIED:` with something you ran, you have not tried the task. If
`SMALLEST-FIX:` names an edit to a test, a constant or layout math, that edit is your job. Make
it.

"It is structurally hard" and "it changes the tests" describe work. Work is not a wall.

## Tests and constants are yours to change

Update a test that pins the old behavior the user asked to change. Do not weaken or delete a test
that catches a real defect just to make a block go away. Ask what the test pins. If it pins the
superseded behavior, update it. If it pins a contract the change would break, the test is right
and the code is the bug.

## Correct refusals stay correct

These protect a real boundary, so keep refusing them:

- A change to production or live state the user did not authorize
- A hard constraint the user set ("do not touch file X")
- A real permission denial

The two kinds of "no" carry different proof. A refusal on principle names the boundary, and you
never invent a `TRIED:` line for an action you were right not to take. A block you hit by trying,
a permission denial included, gets the full log.

## The question to ask yourself

Is the thing stopping me a boundary I must not cross, or work I do not want to do? If it is work,
do it. If it is a boundary, name it.

## Why

Agents call a change "not possible" because it moves geometry or breaks a pinned test, without
trying it. That is a design-cost judgment presented as a wall, and the user has to push back
before the work gets done.
