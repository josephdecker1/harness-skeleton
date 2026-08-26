# Plain language

This rule sets the default register for every word a human reads. It covers chat
replies, status reports, commit messages, and PR descriptions. It reaches design
docs, runbooks, review comments, and the comments and docstrings in source.

Model output defaults to a register that sounds thorough. In prose that shows up
as ornament a reader parses before reaching the content. The same habit fills a
diff with comment blocks that run longer than the code under them.

**Does not apply to:** direct quotations, generated or vendored files, log and
command output, and copy written in a named person's voice.

Two companion files sit beside this one, and neither is needed to install the
rule. One catalogues the twenty-five devices behind rule 6
(`plain-language-devices.md`). The other holds two runnable checks and their
wiring (`plain-language-gates.md`).

---

## The seven rules

1. **One idea per sentence, 25 words maximum.**
2. **Active voice.** "The worker retries the request", rather than "the request
   is retried by the worker".
3. **No semicolons.** Use two sentences.
4. **Use the plain word.**

   | Do not write | Write | Do not write | Write |
   |---|---|---|---|
   | utilize | use | perform | do |
   | ensure | make sure | obtain | get |
   | initiate | start | terminate | stop |
   | additional | more | indicate | show |
   | provide | give | assist | help |
   | determine | find | modify | change |
   | prior to | before | via | through |
   | leverage (verb) | use | facilitate | let |

5. **Replace an adjective with its number.** An adjective makes the reader guess
   at a quantity the writer already has.

   | Do not write | Write |
   |---|---|
   | "much faster" | "p50 dropped from 340ms to 90ms" |
   | "a big diff" | "412 lines across 9 files" |
   | "the suite is solid" | "162 tests, 0 failures" |

   When the number is not in hand, say that. Never swap in an adjective for a
   measurement nobody took.

6. **No rhetorical devices.** Pass/fail. One hit means rewrite the line. Scan
   for four first: negation-correction ("isn't just a config change"), the
   framing tic ("here's the thing"), the sincerity filler ("genuinely",
   "honestly"), and the tricolon ("faster, simpler, cheaper"). That shortlist is
   a judgement call. All twenty-five are in `plain-language-devices.md`.
7. **Cut the draft by a third before sending.** Cut in this order: anything rule
   6 catches, points already made once, context the reader already has, hedges.
   Fires on anything over roughly 150 words. Skips one-line answers, code, and
   command output.

---

## Code comments

This section decides whether to write a comment at all. The seven rules above
then govern how it reads.

**The default is no comment.** A comment claims the code cannot speak for
itself, so it has to carry something the code does not say.

**Keep a comment that holds one of these:**

- Why this approach and not the obvious alternative
- A constraint from outside the file: a vendor limit, a wire format, a bug in a
  dependency, a legal requirement
- A sharp edge for the next caller: a lock held, an order that matters, a unit
- A link to the issue, RFC, or standard behind a strange decision

**Delete a comment that is one of these:**

| Type | Example | Why it goes |
|---|---|---|
| Restatement | `# increment the counter` above `count += 1` | The code said it |
| Type narration | `# returns a string` on a `-> str` signature | The signature said it |
| Changelog | `# Changed from a list to a set for speed` | That is the commit message |
| Diff marker | `# NEW`, `# UPDATED`, `# added in this PR` | That is the diff |
| Section banner | `# ---- Helpers ----` in a file with no banners | Decoration |
| Tutorial | An explanation of what a standard-library call does | The reader knows the language |
| Apology | `# a bit hacky but it works for now` | Fix it, or state the real constraint |
| Invented TODO | A TODO nobody asked for and nobody owns | Backlog noise |
| Ceremonial docstring | A four-line Args/Returns block on a private two-line helper | The signature is the doc |

**Two hard limits:**

1. A comment block is never longer than the code it describes. When it has to
   be, the code needs a better name or a smaller function.
2. Comment density matches the file being edited. A file with no comments does
   not acquire them as a side effect of an unrelated change.

**The delete test.** Delete every comment in the diff, read the diff, then put
back only the comments a reviewer would ask for.

### Delete these

```python
# 19 lines, 2 of them executable.
def _retry_delay(attempt: int) -> float:
    """
    Calculate the retry delay for a given attempt number.

    This function implements exponential backoff, which is a standard strategy
    for retrying failed operations. The delay doubles with each attempt, which
    helps avoid overwhelming a service that is already under load. We cap the
    delay to make sure we do not wait too long between retries.

    Args:
        attempt: The attempt number (0-indexed).

    Returns:
        The delay in seconds as a float.
    """
    # Calculate the exponential delay by raising 2 to the power of attempt
    delay = 2.0 ** attempt
    # Cap the delay at 30 seconds
    return min(delay, 30.0)
```

```python
# 3 lines. Same behavior.
def _retry_delay(attempt: int) -> float:
    # attempt is 0-indexed. Capped at 30s: the gateway drops idle sockets at 60s.
    return min(2.0 ** attempt, 30.0)
```

Everything that docstring holds is already in the code, and both inline comments
restate the expression below them. The After block keeps one fact from it, that
`attempt` starts at zero. Its comment also adds a fact the Before block never
carried, which is why the cap is 30 seconds.

### Keep these

```python
def verify(expected_sig: str, provided_sig: str, timestamp: int, now: int):
    # compare_digest, never ==: a plain compare leaks the signature byte by byte.
    if not hmac.compare_digest(expected_sig, provided_sig):
        raise Forbidden("bad signature")
    # 60 seconds is the provider's replay bound, not a number to tune.
    if abs(now - timestamp) > 60:
        raise Forbidden("stale timestamp")
```

Two comment lines above five code lines, and both survive review. One says why a
standard-library call replaces the obvious operator. The other says where the
constant came from, which stops the next reader from widening it. Cutting either
one costs a future reader a security bug.

---

## What this rule does not ask for

Over-correction is a real failure mode. This rule targets ornament. The items
below are content, and they stay.

- **A design doc still argues the trade-off.** Compression applies to how the
  argument reads. The argument itself stays.
- **A public API still gets a docstring.** Parameters, units, raised errors, and
  thread-safety are content.
- **An error message still tells the user what to do next.**
- **A hard bug still gets its explanation**, in the commit message or the issue.
- **Say plainly what you do not know.** "I have not measured that" is shorter
  than a hedge and more useful.

When a cut is in doubt, keep the line.

---

## Installing it

| Harness | Where it goes |
|---|---|
| Claude Code | `.claude/rules/plain-language.md`, referenced from `CLAUDE.md` |
| Codex and other `AGENTS.md` readers | paste into `AGENTS.md` |
| Cursor | `.cursor/rules/plain-language.mdc`, frontmatter `alwaysApply: true` |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Any API harness | append to the system prompt |

Check the tool's current docs for the path before you commit it, because these
locations move between releases.

Install this file alone as the agent rule. The two companions are reference and
tooling, and a model reading the rule needs neither.

Two things make it stick. Reference the rule from the top-level agent file,
because an agent does not read a directory nothing points at. Then wire the
three surfaces in `plain-language-gates.md`: one git hook and two CI steps. None
of them counts against the install size.

---

## Why

Long output is a default, and one rule file in the repo overrides it.

The default register costs three things. Readers spend attention parsing
ornament instead of content. Reviewers read comment blocks that restate the
diff, which buries the few comments carrying real constraints. Narrating
comments also go stale on the first code change, leaving a confident wrong
statement beside the right one.

Ornament also hides a thin claim, and a flat sentence with no number in it is
visibly missing its number.
