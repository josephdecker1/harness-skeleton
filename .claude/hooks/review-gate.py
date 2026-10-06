#!/usr/bin/env python3
"""PreToolUse hook for Bash. Denies git push, gh pr create, gh pr merge and gh pr ready
until the session transcript shows a dispatch of the adversarial-review-agent.
The user turns it off with REVIEW_GATE=off in the environment, or by creating
.claude/review-gate.off in the project directory. Both switches are for the user, not the model.
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
GH_PR_PUBLISH = {"create", "merge", "ready"}
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
                claude_shaped = claude_shaped or '"type":"assistant"' in line \
                    or '"type": "assistant"' in line
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

The gate stays on until the user turns it off. Do not turn it off yourself.
If the user asks to skip review for this change, tell them the two switches:
  REVIEW_GATE=off in the environment that starts the session
  touch .claude/review-gate.off   (in the project directory, until deleted)"""


def deny():
    return json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": DENY_REASON,
    }})


def main():
    try:
        if os.environ.get("REVIEW_GATE") == "off":
            return 0
        payload = json.load(sys.stdin)
        if payload.get("tool_name") != "Bash":
            return 0
        root = os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or "."
        if (Path(root) / ".claude" / "review-gate.off").exists():
            return 0
        if not scan_command((payload.get("tool_input") or {}).get("command") or ""):
            return 0
        if transcript_has_review(payload.get("transcript_path")) is False:
            print(deny())
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
