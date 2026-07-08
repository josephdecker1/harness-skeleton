# Agents

Subagents are how the main agent fans out without blowing its own context. Each
agent gets a narrow job, a lean context package, and a clear definition of done —
then returns a short structured summary, not a transcript.

## Routing

| Agent | Use it for |
|---|---|
| `adversarial-review-agent.md` | Argue a diff should not merge, before "done" |
| *(add your own)* | Domain work: backend, frontend, infra, data |

## Dispatch pattern

Use your agent's real subagent call. In Claude Code that's the `Agent` (Task)
tool, keyed on `subagent_type` + `prompt`:

```
Agent(
  description="Adversarial review",
  subagent_type="general-purpose",
  prompt="""
    Read .claude/agents/adversarial-review-agent.md for your job.
    Target: <branch / PR / diff>
    Anchored goal: "<verbatim quote of the task>"
    Run all five frames. Return verdict + findings ranked by severity.
  """
)
```

## The output contract

A dispatched agent returns a structured summary (≤ ~60 lines): what it did,
evidence as `path:line` or a measured value, and a final `STATUS: done | blocked |
partial`. Long findings go to a file the main agent opens on demand — never a
multi-KB dump back into the orchestrator's context.

## Model selection

Pin the model per dispatch. Cheap, fast models for mechanical search and
exploration; stronger models for reasoning, review, and synthesis. Don't inherit
a default — an unpinned fleet quietly burns budget on the wrong tier.
