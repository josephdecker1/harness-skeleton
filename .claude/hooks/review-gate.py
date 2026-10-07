#!/usr/bin/env python3
"""PreToolUse hook for Bash, Write and Edit. Denies git push, gh pr create, gh pr merge and
gh pr ready until the session transcript shows a dispatch of the adversarial-review-agent.
The user turns it off with REVIEW_GATE=off in the environment, or skips one publish by creating
.claude/review-gate.off, which the hook deletes when it uses it. The hook denies any agent
command or file write that names that file.
"""
import json
import os
import re
import sys
from pathlib import Path

REVIEW_AGENT = "adversarial-review-agent"
DISPATCH_NAME = ("harness-skeleton:" + REVIEW_AGENT) if os.environ.get("CLAUDE_PLUGIN_ROOT") else REVIEW_AGENT
MAX_TRANSCRIPT_BYTES = 64 * 1024 * 1024
DISPATCH_TOOLS = ("Agent", "Task")
PREFILTER = tuple(f'"name":{sp}"{t}"' for t in DISPATCH_TOOLS for sp in ("", " "))
# At a session's first tool call the assistant lines are not written yet, so the user line counts.
SHAPE_MARKERS = tuple(f'"type":{sp}"{t}"' for t in ("user", "assistant") for sp in ("", " "))
GH_PR_PUBLISH = {"create", "merge", "ready", "new"}
GIT_ARG_FLAGS = {"-C", "-c", "--exec-path", "--git-dir", "--work-tree", "--namespace"}
GH_ARG_FLAGS = {"-R", "--repo", "--hostname"}
WRAPPERS = {"if", "then", "else", "elif", "do", "while", "until", "!", "time", "command",
            "exec", "nohup", "env", "{", "}"}
FLAG_WRAPPERS = {"time", "command", "exec", "nohup", "env"}
SHELLS = {"bash", "sh", "zsh"}
HEREDOC_RE = re.compile(r"(?<!<)<<-?\s*(['\"]?)(\w+)\1")
ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
SHELL_C_RE = re.compile(r"^-[a-z]*c[a-z]*$")
DRY_RUN_RE = re.compile(r"^(--dry-run|-[a-zA-Z]*n[a-zA-Z]*)$")
MAX_DEPTH = 4
OFF_NAME = "review-gate.off"
FILE_TOOLS = ("Write", "Edit")


def _strip_heredocs(cmd):
    out, lines, i = [], cmd.split("\n"), 0
    while i < len(lines):
        out.append(lines[i])
        m = HEREDOC_RE.search(lines[i])
        i += 1
        if m:
            while i < len(lines) and lines[i].strip() != m.group(2):
                i += 1
            i += 1
    return "\n".join(out)


def _match_close(s, i):
    """Index of the ')' closing the '(' before position i, or len(s)."""
    depth, quote = 1, None
    while i < len(s):
        c = s[i]
        if quote:
            if c == "\\" and quote == '"':
                i += 1
            elif c == quote:
                quote = None
        elif c in "'\"":
            quote = c
        elif c == "\\":
            i += 1
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return len(s)


def _parse(cmd):
    """Split into segments of unquoted words. Return (segments, substitution bodies)."""
    segs, toks, word, inners = [], [], [], []
    quote, i, n = None, 0, len(cmd)
    in_word = False

    def flush():
        nonlocal in_word
        if in_word:
            toks.append("".join(word))
            word.clear()
            in_word = False

    def end_seg():
        flush()
        if toks:
            segs.append(list(toks))
            toks.clear()

    while i < n:
        c, nxt = cmd[i], cmd[i + 1] if i + 1 < n else ""
        if quote == "'":
            if c == "'":
                quote = None
            else:
                word.append(c)
        elif c == "\\":
            word.append(nxt)
            in_word = True
            i += 1
        elif c == "$" and nxt == "(" or c in "<>" and nxt == "(" and quote is None:
            end = _match_close(cmd, i + 2)
            inners.append(cmd[i + 2:end])
            word.append("__SUB__")
            in_word = True
            i = end
        elif c == "`":
            end = cmd.find("`", i + 1)
            end = n if end < 0 else end
            inners.append(cmd[i + 1:end])
            word.append("__SUB__")
            in_word = True
            i = end
        elif quote == '"':
            if c == '"':
                quote = None
            else:
                word.append(c)
        elif c in "'\"":
            quote, in_word = c, True
        elif c in " \t":
            flush()
        elif c == "#" and not in_word:
            while i < n and cmd[i] != "\n":
                i += 1
            continue
        elif c in ";\n|()":
            end_seg()
        elif c == "&" and nxt != ">" and (i == 0 or cmd[i - 1] not in "<>"):
            end_seg()
        else:
            word.append(c)
            in_word = True
        i += 1
    end_seg()
    return segs, inners


def _after_flags(tokens, arg_flags):
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if t in arg_flags:
            i += 2
        elif t.startswith("-"):
            i += 1
        else:
            return t, tokens[i + 1:]
    return None, []


def _publishes(word, rest):
    if "--help" in rest or "-h" in rest:
        return False
    if word == "git":
        sub, args = _after_flags(rest, GIT_ARG_FLAGS)
        return sub == "push" and not any(DRY_RUN_RE.match(a) for a in args)
    if word == "gh":
        sub, args = _after_flags(rest, GH_ARG_FLAGS)
        if sub != "pr":
            return False
        action, _ = _after_flags(args, GH_ARG_FLAGS)
        return action in GH_PR_PUBLISH
    return False


def _segment_gated(tokens, depth):
    """True when this segment publishes."""
    while tokens:
        if ASSIGN_RE.match(tokens[0]):
            tokens = tokens[1:]
        elif tokens[0] in WRAPPERS:
            wrapper, tokens = tokens[0], tokens[1:]
            while wrapper in FLAG_WRAPPERS and tokens and tokens[0].startswith("-"):
                tokens = tokens[1:]
        else:
            break
    if not tokens:
        return False
    word, rest = os.path.basename(tokens[0]), tokens[1:]
    if word in SHELLS:
        for j, t in enumerate(rest[:-1]):
            if SHELL_C_RE.match(t):
                return scan_command(rest[j + 1], depth + 1)
        return False
    return _publishes(word, rest)


def scan_command(cmd, depth=0):
    """True when the command publishes work and nothing overrides the gate."""
    if depth > MAX_DEPTH:
        return False
    segs, inners = _parse(_strip_heredocs(cmd.replace("\\\n", " ")))
    return (any(_segment_gated(s, depth) for s in segs)
            or any(scan_command(x, depth + 1) for x in inners))


def _names_off_switch(cmd):
    return OFF_NAME in re.sub(r"[\"'\\]", "", cmd)


def _is_review(inp):
    sub = str(inp.get("subagent_type", ""))
    return (sub == REVIEW_AGENT or sub.endswith(":" + REVIEW_AGENT)
            or REVIEW_AGENT + ".md" in str(inp.get("prompt", "")))


def transcript_has_review(path):
    """True or False, or None when the transcript is missing, huge or not Claude-shaped."""
    if not path:
        return None
    try:
        p = Path(path)
        if not p.is_file() or p.stat().st_size > MAX_TRANSCRIPT_BYTES:
            return None
        claude_shaped = False
        with open(p, encoding="utf-8", errors="ignore") as f:
            for line in f:
                claude_shaped = claude_shaped or any(m in line for m in SHAPE_MARKERS)
                if not any(sig in line for sig in PREFILTER):
                    continue
                try:
                    content = (json.loads(line).get("message") or {}).get("content") or []
                except (json.JSONDecodeError, AttributeError):
                    continue
                if not isinstance(content, list):
                    continue
                for blk in content:
                    if (isinstance(blk, dict) and blk.get("type") == "tool_use"
                            and blk.get("name") in DISPATCH_TOOLS
                            and _is_review(blk.get("input") or {})):
                        return True
        return False if claude_shaped else None
    except OSError:
        return None


DENY_REASON = f"""REVIEW GATE: no {REVIEW_AGENT} dispatch appears in this session.

This command publishes work (git push, gh pr create, gh pr merge or gh pr ready).
Dispatch the review now. The user installed this gate to ask for it, so do not ask first.
Call the Agent tool with subagent_type "{DISPATCH_NAME}". In the prompt, name the diff
(branch, PR or commit range) and quote the anchored goal: the user's original request.
Fix the findings, then run this command again.

The gate checks this session only. A trivial or doc-only change gets no exemption, and a
review from an earlier session does not count. If the user wants to skip the review,
tell them the two switches. Do not use either one yourself.
  REVIEW_GATE=off in the environment that starts the session
  touch .claude/review-gate.off   run by the user in their own terminal, in the project
                                  directory. It allows the next blocked publish, then the
                                  gate deletes it. Any command of yours that names it is denied."""

OFF_REASON = """REVIEW GATE: only the user creates or changes .claude/review-gate.off.

The gate denies any agent command or file write that names that file.
If the user wants to skip the review, ask them to run this in their own terminal:
  touch .claude/review-gate.off"""


def deny(reason):
    return json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }})


def main():
    try:
        if os.environ.get("REVIEW_GATE") == "off":
            return 0
        payload = json.load(sys.stdin)
        tool, inp = payload.get("tool_name"), payload.get("tool_input") or {}
        if tool in FILE_TOOLS:
            if Path(str(inp.get("file_path") or "")).name == OFF_NAME:
                print(deny(OFF_REASON))
            return 0
        if tool != "Bash":
            return 0
        cmd = inp.get("command") or ""
        if _names_off_switch(cmd):
            print(deny(OFF_REASON))
            return 0
        if not scan_command(cmd):
            return 0
        if transcript_has_review(payload.get("transcript_path")) is not False:
            return 0
        root = os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or "."
        off = Path(root) / ".claude" / OFF_NAME
        spent = off.with_name(f"{OFF_NAME}.spent-{os.getpid()}")
        try:
            # Parallel tool calls run their hooks at once. Only one rename of the off file can
            # succeed, while on APFS two deletes of it can both succeed.
            off.rename(spent)
        except FileNotFoundError:
            print(deny(DENY_REASON))
            return 0
        spent.unlink(missing_ok=True)
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
