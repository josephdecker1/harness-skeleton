# harness-skeleton

A sanitized, forkable skeleton of the agent **harness** I run every day — the
configuration that turns an AI coding agent from a fancy autocomplete into an
engineering system a team can trust.

This is not a prompt collection. It's the scaffolding: the rules the agent reads
every session, the skills it invokes instead of improvising, the deterministic
hooks it can't skip, the memory that survives a context reset, the review agents
that argue before anything ships, the CI gates that hold agent output to the same
bar as human output, and the evals that decide whether a model upgrade is safe.

> The example content here is generic on purpose. Swap the placeholder rules,
> skills, and evals for your team's. The **structure** is the point.

## Why a harness

Most teams that adopt an AI coding tool get three failure modes:

1. **Shallow usage** — the model writes boilerplate while design, review, and
   debugging stay manual. Autocomplete with better marketing.
2. **Fifty private playbooks** — every engineer prompts differently. Nothing is
   shared, versioned, or reviewed; quality depends on who typed.
3. **The trust gap** — agent output is either rubber-stamped or re-read line by
   line. Neither scales.

None of these are model problems. They're harness problems. A harness is
infrastructure: you build it, version it in the repo, review changes to it like
code, and test it.

## The nine surfaces

Each surface decides one thing: what the model **knows**, what it **may do**, or
what it must **prove**.

| Surface | Lives in | Decides |
|---|---|---|
| **The agent** | `CLAUDE.md` | How the agent is oriented every session |
| **Rules** | `.claude/rules/` | House constraints, read every session |
| **Skills** | `.claude/skills/` | Repeatable procedures, invoked not improvised |
| **Hooks** | `.claude/hooks/` | Deterministic checks the model can't skip |
| **Memory** | `.claude/memory/` | Durable context that survives every session |
| **Review agents** | `.claude/agents/` | Adversarial second passes before "done" |
| **CI gates** | `.github/workflows/` | The same bars humans merge through |
| **Evals** | `evals/` | Behavioral tests that gate model swaps |
| **Session logs** | `.claude/logs/` | Every decision written down, searchable |

They interlock. A rule is enforced by a hook, checked by a review agent, and
gated in CI. An eval proves the whole loop still behaves after a model upgrade. A
session log is what memory is distilled from. Pull one surface out and the others
get weaker.

## What's runnable here (and what's yours to fill in)

Being honest about a skeleton matters more than looking finished, so:

- **Runnable and tested in CI.** The secret-scan hook
  (`.claude/hooks/check-no-secrets.sh`) blocks a hard-coded key on both Write and
  Edit, fails closed if it can't parse the payload, and is proven by
  `evals/run.sh` — which the CI gate (`.github/workflows/harness-gate.yml`) runs
  on every push. That much is a working enforcement loop you can watch go
  red-green.
- **Runnable and tested in CI.** The plain-language gates in `scripts/` fail the
  build two ways. One catches a banned rhetorical device in changed Markdown.
  The other catches a comment block longer than the code under it. The
  `plain-language` job runs both against the range this branch adds, and
  `evals/run.sh` proves the gates themselves still work.
- **Real reference text you replace.** The rules, the memory/session-log/eval
  examples, and the review-agent playbook are genuine and usable as-is, but they
  are *content*, not enforcement — they work because the agent reads and follows
  them. Swap them for your team's.

The leverage is the loop, and the loop is only as strong as the surfaces you
actually wire. This repo ships two wired end-to-end as worked examples; the rest
is the scaffold to wire the same way.

```
                         ┌───────────────┐   CLAUDE.md — read every session
                         │   THE AGENT   │
                         └───────┬───────┘
           ┌─────────────────────┼─────────────────────┐
           │                     │                     │
   ┌───────┴───────┐     ┌───────┴───────┐     ┌───────┴───────┐
   │ what it       │     │ what it       │     │ what it must  │
   │   KNOWS       │     │   MAY DO      │     │    PROVE      │
   ├───────────────┤     ├───────────────┤     ├───────────────┤
   │ Rules         │     │ Skills        │     │ Review agents │
   │ Memory        │     │ Hooks         │     │ CI gates      │
   │               │     │               │     │ Evals         │
   │               │     │               │     │ Session logs  │
   └───────────────┘     └───────────────┘     └───────────────┘
```

## Layout

```
harness-skeleton/
├── CLAUDE.md                     # the agent's house config (read every session)
├── .claude/
│   ├── rules/                    # constraints: surgical diffs, goal-driven, done,
│   │                             # grounded, plain language
│   ├── skills/verify/            # a procedure the agent invokes by name
│   ├── agents/                   # the adversarial reviewer + a routing index
│   ├── hooks/                    # a PreToolUse secret-scan gate + settings example
│   ├── memory/                   # durable facts + the index that loads them
│   └── logs/                     # session-log template
├── scripts/                      # the two plain-language gates, plus the drift check
├── evals/                        # one model-behavior eval + deterministic gate tests
└── .github/workflows/            # a CI job that runs the same gates a human merges through
```

## How to adopt this

1. **Fork it.** Drop it into a repo (or your monorepo root).
2. **Replace the rules** in `.claude/rules/` with your team's real constraints.
   Start with three. Add one every time the agent does something you had to
   correct twice.
3. **Wire the hooks** — copy `.claude/hooks/settings.example.json` into your
   agent's settings and make the secret-scan hook executable. Hooks are the only
   surface the model literally cannot talk its way past; use them for the checks
   that must never be skipped.
4. **Adopt the review loop** — the adversarial agent in `.claude/agents/` is the
   critic half of a drafter/critic pair. Run it against a diff before "done."
5. **Add one eval** for the behavior you care most about, and run it in CI. This
   is what lets you upgrade models without holding your breath.
6. **Keep session logs.** They are cheap to write and they are what your memory
   files get distilled from.

## What this is not

- Not a magic prompt. The leverage is in the loop, not any one string.
- Not tied to one vendor. The pattern — rules-as-code, invoked skills, review
  loops, evals — ports across agents; this skeleton is written for Claude Code
  because it has the deepest hook and subagent surface.
- Not a substitute for judgment. It's the scaffolding that makes good judgment
  repeatable and reviewable.

---

Maintained by [Joseph Decker](https://josephdecker.app). If you want this
installed and tuned for your team's repos, that's what I do — details at
[josephdecker.app](https://josephdecker.app).
