#!/usr/bin/env bash
# Applies single-point mutations to a temp copy of review-gate.py. Each one must make
# at least one case in run-cases.sh fail. The real hook file is never changed.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/review-gate-mut.XXXXXX")"
trap 'rm -rf "$work"' EXIT

cat >"$work/mutate.py" <<'PY'
import sys
src, dst, old, new = sys.argv[1:5]
text = open(src).read()
if text.count(old) != 1:
    sys.exit(f"pattern found {text.count(old)} times, expected 1: {old!r}")
open(dst, "w").write(text.replace(old, new))
PY

if ! "$here/run-cases.sh" >/dev/null 2>&1; then
  echo "ERROR  the real hook fails its own cases, so a caught mutation proves nothing"
  exit 1
fi

survivors=0
n=0
mutate() {   # $1 = label, $2 = old text, $3 = new text
  n=$((n + 1))
  local copy="$work/m$n.py"
  if ! python3 "$work/mutate.py" "$here/../../.claude/hooks/review-gate.py" "$copy" "$2" "$3"; then
    echo "ERROR  $1 - mutation did not apply"
    survivors=$((survivors + 1))
    return
  fi
  local out caught
  out=$(HOOK="$copy" "$here/run-cases.sh" 2>&1)
  caught=$(grep '^FAIL' <<<"$out" | head -1 | sed 's/^FAIL  //; s/ - expected.*//')
  if [ -n "$caught" ]; then
    echo "CAUGHT    $1 ($(grep -c '^FAIL' <<<"$out") cases fail, e.g. '$caught')"
  else
    echo "SURVIVED  $1"
    survivors=$((survivors + 1))
  fi
}

mutate "drop gh pr merge" '{"create", "merge", "ready", "new"}' '{"create", "ready", "new"}'
mutate "drop gh pr ready" '{"create", "merge", "ready", "new"}' '{"create", "merge", "new"}'
mutate "drop gh pr new" '{"create", "merge", "ready", "new"}' '{"create", "merge", "ready"}'
mutate "ignore git -C" 'GIT_ARG_FLAGS = {"-C", ' 'GIT_ARG_FLAGS = {'
mutate "ignore gh --repo" 'GH_ARG_FLAGS = {"-R", "--repo", "--hostname"}' 'GH_ARG_FLAGS = set()'
mutate "treat quoted text as commands" 'segs, inners = _parse(_strip_heredocs(cmd.replace("\\\n", " ")))' 'segs, inners = [s.split() for s in __import__("re").split(r"&&|\|\||;|\||\n", cmd)], []'
mutate "heredoc strip drops everything after the opener" 'while i < len(lines) and lines[i].strip() != m.group(2):' 'while i < len(lines):'
mutate "do not strip heredoc bodies" '_parse(_strip_heredocs(cmd.replace' '_parse((cmd.replace'
mutate "skip namespaced subagent_type" ' or sub.endswith(":" + REVIEW_AGENT)' ''
mutate "skip prompt reference" '
            or REVIEW_AGENT + ".md" in str(inp.get("prompt", "")))' ')'
mutate "any Agent counts as a review" ' and _is_review(blk.get("input") or {})' ''
mutate "ignore legacy Task tool" 'DISPATCH_TOOLS = ("Agent", "Task")' 'DISPATCH_TOOLS = ("Agent",)'
mutate "disable env killswitch" 'if os.environ.get("REVIEW_GATE") == "off":' 'if False:'
mutate "disable file killswitch" '            off.rename(spent)
' '            raise FileNotFoundError
'
mutate "file killswitch is not one-shot" 'off.rename(spent)' 'off.stat()'
mutate "file killswitch is spent before the review check" '        if transcript_has_review(payload.get("transcript_path")) is not False:
            return 0
        root = os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or "."
        off = Path(root) / ".claude" / OFF_NAME
' '        root = os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or "."
        off = Path(root) / ".claude" / OFF_NAME
        if off.exists():
            off.unlink()
            return 0
        if transcript_has_review(payload.get("transcript_path")) is not False:
            return 0
'
# Only APFS lets two concurrent deletes of one file both succeed. Elsewhere this mutant is correct code.
if [ "$(uname)" = Darwin ]; then
  mutate "off file claimed by delete, not rename" 'off.rename(spent)' 'off.unlink()'
else
  echo "SKIPPED   off file claimed by delete, not rename (macOS only)"
fi
mutate "agent command may name the off file" 'if _names_off_switch(cmd):' 'if False:'
mutate "off-file name check ignores quotes" 're.sub(r"[\"'"'"'\\]", "", cmd)' 'cmd'
mutate "agent may write the off file" 'if Path(str(inp.get("file_path") or "")).name == OFF_NAME:' 'if False:'
mutate "deny names the bare agent in plugin mode" 'subagent_type "{DISPATCH_NAME}"' 'subagent_type "{REVIEW_AGENT}"'
mutate "deny always names the plugin agent" 'if os.environ.get("CLAUDE_PLUGIN_ROOT") else REVIEW_AGENT' 'if True else REVIEW_AGENT'
mutate "ignore CLAUDE_PROJECT_DIR" 'os.environ.get("CLAUDE_PROJECT_DIR") or ' ''
mutate "git push --dry-run counts as publish" 'not any(DRY_RUN_RE.match(a) for a in args)' 'True'
mutate "fail closed on missing transcript" '"transcript_path")) is not False:' '"transcript_path")) is True:'
mutate "only an assistant line marks a Claude transcript" 'for t in ("user", "assistant")' 'for t in ("assistant",)'
mutate "fail closed on foreign transcript shape" 'return False if claude_shaped else None' 'return False'
mutate "ignore command substitution bodies" '
            or any(scan_command(x, depth + 1) for x in inners))' ')'
mutate "ignore bash -c" 'return scan_command(rest[j + 1], depth + 1)' 'return False'
mutate "ignore tool_name check" 'if tool != "Bash":' 'if False:'
mutate "invert review check" '"transcript_path")) is not False:' '"transcript_path")) is False:'

echo "---"
echo "$n mutations, $survivors survived or failed to apply"
exit $((survivors > 0))
