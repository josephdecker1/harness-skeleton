# harness-skeleton

A forkable skeleton of the agent **harness** I run every day. A harness is the
configuration that turns an AI coding agent into an engineering system a team can trust.

It holds:

- the rules the agent reads every session
- the skills it invokes instead of improvising
- the hooks that run on every matching tool call, whether the agent remembers or not
- the memory that survives a context reset
- the review agent that argues before anything ships
- the CI gates that hold agent output to the same bar as human output
- the evals that decide whether a model upgrade is safe

> The example content is generic on purpose. Swap the placeholder rules, skills and
> evals for your team's. The **structure** is the point.

## What changed in v2 (October 2026)

- The review agent is a real Claude Code subagent, rewritten around five frames:
  necessity, complexity, mess, goal achievement and test correctness.
- A second runnable hook, `review-gate`, blocks a push or a pull request until the
  session shows a review dispatch. It has 110 test cases and 31 mutation checks.
- New rules: the review checkpoint, try before you call it impossible, ablate before
  you theorize, and agents clean up what they plant.
- New skills: `handoff` and `teach-claude`.
- An eval ledger, plus the plain-language gates running in CI.
- The repo installs as a Claude Code plugin.

Full list: [CHANGELOG.md](CHANGELOG.md).

## Install

### As a plugin (two commands)

Inside Claude Code:

```
/plugin marketplace add josephdecker1/harness-skeleton
/plugin install harness-skeleton@harness-skeleton
```

Restart the session. You get:

- `harness-skeleton:adversarial-review-agent`, the critic
- The `verify`, `handoff` and `teach-claude` skills
- Two hooks: a secret scan on every file write, and a review gate on `git push`
  and on `gh pr` create, ready and merge

A plugin cannot ship rules or a `CLAUDE.md`. Copy the files you want from
`.claude/rules/` into your repo's `.claude/rules/`, and merge the parts of
`CLAUDE.md` that fit. Take its `@.claude/memory/MEMORY.md` import line too. Without
it, no session loads the memory index that the `handoff` skill writes to.

`/plugin install` installs at user scope by default, so both hooks then run in every
repo you open. To keep them to one repo, install from that repo with
`claude plugin install harness-skeleton@harness-skeleton --scope project`, or commit
the settings below.

To offer the plugin to everyone who opens a repo, commit this to that repo's
`.claude/settings.json`. Each teammate gets it after they trust the folder.

```json
{
  "extraKnownMarketplaces": {
    "harness-skeleton": {
      "source": { "source": "github", "repo": "josephdecker1/harness-skeleton" }
    }
  },
  "enabledPlugins": { "harness-skeleton@harness-skeleton": true }
}
```

### What the review gate does to your sessions

The gate denies `git push`, `gh pr create`, `gh pr ready` and `gh pr merge` until the
session shows a dispatch of the review agent. The deny tells the agent to run that
review without asking first. The review agent pins Opus, so each deny costs one full
Opus review.

The gate checks the current session only. It has no exemption for a trivial or
doc-only change. A review from an earlier session does not count, so merging
yesterday's reviewed pull request gets the same deny.

Two switches turn it off, and both are for you to use:

- `REVIEW_GATE=off` in the environment that starts Claude Code turns the gate off for
  that session.
- `touch .claude/review-gate.off`, run in your own terminal at the project root, lets
  the next blocked publish through. The gate then deletes the file.

The gate denies any agent command or file write that names `review-gate.off`. That
guard catches an agent that reaches for the switch. An agent that sets out to dodge
the gate can still build the name inside a script.

### As a fork

1. Fork the repo, or copy its `.claude/` folder and `CLAUDE.md` into your repo.
2. **Replace the rules** in `.claude/rules/` with your team's. Start with three. Add
   one each time you correct the agent on the same thing twice.
3. **Wire the hooks.** Merge `.claude/hooks/settings.example.json` into
   `.claude/settings.json`. Skip this step if you installed the plugin, or the hooks
   run twice.
4. **Adopt the review loop.** `.claude/rules/review-checkpoint.md` says when the
   critic runs and how to close its findings.
5. **Add one eval** for the behavior you care most about, and run it in CI.
6. **Keep session logs**, and run `handoff` before a context reset. Memory files are
   distilled from both.

## Why a harness

Most teams that adopt an AI coding tool hit three failure modes:

1. **Shallow use.** The model writes boilerplate, while design, review and
   debugging stay manual.
2. **Fifty private playbooks.** Every engineer prompts differently. Nothing is
   shared, versioned or reviewed, so quality depends on who typed.
3. **The trust gap.** Agent output is either rubber-stamped or re-read line by line.
   Neither scales.

These are harness problems. A harness is infrastructure: you build it, version it in
the repo, review changes to it like code, and test it.

## The nine surfaces

Each surface decides one thing: what the model **knows**, what it **may do**, or what
it must **prove**.

| Surface | Lives in | Decides |
|---|---|---|
| **The agent** | `CLAUDE.md` | How the agent is oriented every session |
| **Rules** | `.claude/rules/` | House constraints, read every session |
| **Skills** | `.claude/skills/` | Repeatable procedures, invoked by name |
| **Hooks** | `.claude/hooks/` | Deterministic checks on every matching tool call |
| **Memory** | `.claude/memory/` | Durable context that `CLAUDE.md` loads every session |
| **Review agents** | `.claude/agents/` | Adversarial second passes before "done" |
| **CI gates** | `.github/workflows/` | The same bar a human merges through |
| **Evals** | `evals/` | Behavioral tests that gate model swaps |
| **Session logs** | `.claude/logs/` | Every decision written down |

They interlock. A rule is enforced by a hook, checked by a review agent and gated in
CI. An eval proves the loop still behaves after a model upgrade. A session log is
what memory is distilled from. Pull one surface out and the rest get weaker.

## What runs, and what you fill in

- **Runnable, and tested on every pull request:**
  - `check-no-secrets.sh` blocks a hard-coded key on Write and Edit, and fails
    closed when it cannot parse the payload.
  - `review-gate.py` denies a publish command until the session shows a review
    dispatch. Before it shipped, its classifier ran over 17,348 real commands with no
    false positive in a hand-checked sample.
  - The plain-language gates in `scripts/` fail the build on a banned rhetorical
    device in changed Markdown, and on a comment block longer than its code.
  - `evals/run.sh` proves all of the above, and `.github/workflows/harness-gate.yml`
    runs it on every pull request and every push to `main`.
- **Reference text you replace:** the rules, the review agent's playbook, the skills,
  and the memory, log and eval examples. They work because the agent reads them.

## Layout

```
harness-skeleton/
├── CLAUDE.md                  # the agent's house config, read every session
├── .claude-plugin/            # plugin manifest and marketplace file
├── .claude/
│   ├── rules/                 # constraints the agent reads every session
│   ├── skills/                # verify, handoff, teach-claude
│   ├── agents/                # the adversarial reviewer and a routing index
│   ├── hooks/                 # secret scan, review gate, and their wiring
│   ├── memory/                # durable facts and the index that loads them
│   └── logs/                  # session-log template
├── evals/                     # the lesson ledger and its runnable evals
├── scripts/                   # the plain-language gates
└── .github/workflows/         # CI that runs the same gates a human merges through
```

## Lessons from running it

- **Prose rules lose to system-prompt defaults.** A generic "do not use subagents"
  line beat a written review rule twice in two days. When a rule fails twice, the
  next tier is a hook.
- **The critic needs the strongest model and no cycle cap.** A cap stopped
  unfinished reviews, and each time the user authorized more cycles anyway. The cap
  only cost a round trip. A closure table before each new cycle keeps fixes honest.
- **Sweep real history before a hook can block.** A test corpus measures what its
  author imagined. A blocking hook tolerates zero false positives, because a gate
  that blocks good work gets switched off.
- **Every gate needs an off switch, and the switch belongs to the user.** The deny
  message names it and tells the model not to use it. The review gate's file switch
  works once, and the hook denies any agent command that names it.
- **Pin the model on every fan-out.** An unpinned subagent inherits the session's
  model, so a wide fan-out runs on the most expensive tier.
- **Agents clean up what they plant.** A probe symlink left behind by one review
  cycle turned a later cleanup into a credential wipe.

## What this is not

- A magic prompt. The leverage is in the loop, and no single string carries it.
- Tied to one vendor. Rules as code, invoked skills, review loops and evals port
  across agents. This skeleton targets Claude Code because it has the deepest hook
  and subagent surface.
- A substitute for judgment. It makes good judgment repeatable and reviewable.

---

Maintained by Joseph Decker · [josephdecker.app](https://josephdecker.app)
