#!/usr/bin/env bash
# PreToolUse hook: block a Write/Edit that would commit an obvious secret.
#
# Hooks are the one surface the model cannot talk its way past — the harness
# runs them, not the agent. Use them for checks that must NEVER be skipped.
#
# Two design choices that matter for a gate:
#   1. It scans the fields that carry *newly written* content for BOTH tools:
#      the Write tool's `content` and the Edit tool's `new_string`. (A hook that
#      only reads `content` silently no-ops on every Edit — the more common way
#      an agent writes into an existing file. We do NOT scan `old_string`: that
#      is the text being removed, and blocking it would stop you from deleting a
#      secret that's already there.)
#   2. It fails CLOSED. If the payload can't be parsed, it blocks rather than
#      letting an unscanned write through — the correct default for a secret gate.
#
# Wire it via .claude/hooks/settings.example.json and make it executable:
#   chmod +x .claude/hooks/check-no-secrets.sh
# Extend the patterns to your stack; keep it fast and false-positive-averse (a
# gate that cries wolf gets disabled, and a disabled gate protects nothing).

set -euo pipefail

payload="$(cat)"

# Pull the written content out of the tool payload. python exits 3 on a parse
# failure so we can tell "couldn't parse" apart from "parsed, nothing to scan".
content="$(printf '%s' "$payload" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(3)
ti = d.get("tool_input", {}) or {}
parts = [ti.get("content"), ti.get("new_string")]   # Write: content, Edit: new_string
print("\n".join(p for p in parts if isinstance(p, str)))
')" || {
  echo "BLOCKED: could not parse tool input — refusing to allow an unscanned write (fail-closed)." >&2
  exit 2
}

# High-signal secret shapes. Prefixed keys are near-zero false positive. The
# "sk-" pattern allows internal hyphens so it catches real vendor keys
# (sk-ant-…, sk-proj-…, sk-live-…), not just hyphen-free ones.
patterns=(
  'AKIA[0-9A-Z]{16}'                       # AWS access key id
  '(^|[^A-Za-z0-9])sk-[A-Za-z0-9-]{20,}'    # "sk-" API keys; boundary before "sk" so
                                            #   kebab words ending in "sk" (disk-, risk-) don't false-positive
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'      # PEM private key
  'ghp_[A-Za-z0-9]{36}'                     # GitHub personal access token
  'xox[baprs]-[A-Za-z0-9-]{10,}'            # Slack token
)

for p in "${patterns[@]}"; do
  # -e marks the next arg as a pattern even when it starts with '-' (the PEM
  # pattern does), so grep never mistakes it for an option and silently skips it.
  if printf '%s' "$content" | grep -Eq -e "$p"; then
    echo "BLOCKED: content matches a secret pattern (${p}). Store it in a secret manager and reference it, don't hard-code it." >&2
    exit 2   # non-zero blocks the tool call
  fi
done

exit 0
