# Agents

Subagents are how the main agent fans out without blowing its own context. Each
agent gets a narrow job, a lean context package, and a clear definition of done —
then returns a short structured summary, not a transcript.

## Routing

| Agent | Use it for |
|---|---|
| `adversarial-review-agent` | Argue a diff should not merge, before "done" |
| *(add your own)* | Domain work: backend, frontend, infra, data |

## Dispatch pattern

Each file here is a Claude Code subagent: its frontmatter carries the `name`, the
`description` the router reads, the `tools`, and the `model`. Dispatch it by name
with the `Agent` tool:

```
Agent(
  description="Adversarial review",
  subagent_type="adversarial-review-agent",
  prompt="""
    Target: <branch / PR / diff>
    Anchored goal: "<verbatim quote of the task>"
    Run all five frames. Return verdict + findings ranked by severity.
  """
)
```

Installed through the plugin, the name gains a prefix:
`harness-skeleton:adversarial-review-agent`.

## The output contract

A dispatched agent returns a structured summary (≤ ~60 lines): what it did,
evidence as `path:line` or a measured value, and a final `STATUS: done | blocked |
partial`. Long findings go to a file the main agent opens on demand — never a
multi-KB dump back into the orchestrator's context.

## Model selection

Pin the model per dispatch. Cheap, fast models for mechanical search and
exploration; stronger models for reasoning, review, and synthesis. Don't inherit
a default — an unpinned fleet quietly burns budget on the wrong tier.

An unpinned dispatch inherits the session's model, so a wide fan-out quietly runs
every agent on the most expensive tier and can spend a usage window in minutes.
Pin the cheap tier on fan-outs.

The review agent is the exception. It pins the strongest model in its own
frontmatter, because a critic weaker than the work it reviews approves by
omission.
