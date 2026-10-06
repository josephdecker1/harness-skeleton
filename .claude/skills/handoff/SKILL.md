---
name: handoff
description: Capture session state before a context reset. Writes a handoff doc a fresh session can resume from, records durable lessons in memory, and drafts a paste-ready prompt for the next session. Use when the user says "handoff", "save state", "before I clear", or when a long session reaches a phase boundary.
argument-hint: "[focus note, or 'skip memory' / 'skip prompt']"
---

# handoff

A context reset loses everything the session knew that is not on disk. This skill puts it on
disk in a shape the next session can act on.

Use it at a phase boundary: a review conceded, a deliverable shipped, or the next ask is an
unrelated topic. A fresh context on a new topic beats a long one carrying stale state.

## Step 1 — Handoff doc

Write `.claude/handoffs/<YYYY-MM-DD>-<HHMM>-<slug>.md`. Get the time from `date +%Y-%m-%d-%H%M`.
The slug is 2 to 4 kebab-case words naming the topic.

```markdown
---
date: YYYY-MM-DD HH:MM
branch: <git branch, if any>
status: in-progress | blocked | shipped | parked
---

# <topic>

## TL;DR
<At most 3 sentences: the goal, where it ended, what comes next.>

## State
- **Doing:** <current focus>
- **Decided:** <decisions made this session>
- **Pending:** <open questions and blockers>

## Files touched
- `path/to/file` — <one line on what changed>

## Next steps
1. <verb-first, concrete>

## Gotchas
<What a fresh session would trip on. Omit the section if there is nothing real.>
```

Rules:

- The TL;DR is mandatory. Every other section appears only when it has content.
- Take "Files touched" from `git status` and `git diff --name-only`, never from recall.
- `status: blocked` names the blocker under Pending and the unblock under Next steps.
- **Every count states its basis**: what was counted, how, and when. Write "7 failing tests
  (`npm test`, 14:05)", never a bare "7 failing tests". The session that built a thing counts
  what it inherited and forgets what it just added. A dated basis tells the next reader when
  to measure again.

## Step 2 — Memory (skip on "skip memory")

For each durable lesson from the session, write one file in `.claude/memory/` and one line in
`.claude/memory/MEMORY.md`. Durable means a decision with its reason, a non-obvious constraint,
or a gotcha you hit twice. Check for an existing file first and update it rather than add a
duplicate.

Never save what the code or the git history already records.

## Step 3 — Next-session prompt (skip on "skip prompt")

Print a prompt the user can paste after the reset:

```
Read .claude/handoffs/<file>.md first.
Goal: <one sentence>
First step: <the first item under Next steps>
Done when: <the observable check from the goal-driven-execution rule>
```

## Output

Tell the user the handoff path, what went into memory, and the prompt. Keep it to the facts a
reader who did not watch the session needs.
