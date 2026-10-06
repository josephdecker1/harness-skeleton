#!/usr/bin/env bash
# Feeds each case in review-gate-cases.jsonl to the hook and checks allow or deny.
# Needs jq. Set HOOK to test a different copy of the hook.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
hook="${HOOK:-$here/../../.claude/hooks/review-gate.py}"
cases="${CASES:-$here/review-gate-cases.jsonl}"
work="$(mktemp -d "${TMPDIR:-/tmp}/review-gate.XXXXXX")"
trap 'rm -rf "$work"' EXIT

fail=0
total=0
nfail=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  total=$((total + 1))
  name=$(jq -r .name <<<"$line")
  expect=$(jq -r .expect <<<"$line")
  proj="$work/p$total"
  mkdir -p "$proj/elsewhere"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    mkdir -p "$proj/$(dirname "$f")"
    : >"$proj/$f"
  done < <(jq -r '.files[]?' <<<"$line")

  kind=$(jq -r '.transcript | type' <<<"$line")
  tpath=""
  if [ "$kind" = "array" ]; then
    tpath="$work/t$total.jsonl"
    jq -c '.transcript[]' <<<"$line" >"$tpath"
  elif [ "$kind" = "string" ]; then
    tpath="$here/fixtures/$(jq -r .transcript <<<"$line")"
  fi

  cwd="$proj"
  proj_env=()
  if [ "$(jq -r '.project_dir // false' <<<"$line")" = "true" ]; then
    cwd="$proj/elsewhere"
    proj_env=("CLAUDE_PROJECT_DIR=$proj")
  fi

  raw=$(jq -r '.raw_stdin // empty' <<<"$line")
  if [ -n "$raw" ]; then
    payload="$raw"
  else
    payload=$(jq -nc --arg cmd "$(jq -r .command <<<"$line")" --arg tp "$tpath" --arg cwd "$cwd" \
      --arg tool "$(jq -r '.tool_name // "Bash"' <<<"$line")" \
      '{hook_event_name:"PreToolUse", tool_name:$tool, cwd:$cwd, tool_input:{command:$cmd}}
       + (if $tp == "" then {} else {transcript_path:$tp} end)')
  fi

  extra_env=()
  while IFS= read -r kv; do
    [ -n "$kv" ] && extra_env+=("$kv")
  done < <(jq -r '.env // {} | to_entries[] | "\(.key)=\(.value)"' <<<"$line")

  out=$(printf '%s' "$payload" | env -u REVIEW_GATE -u CLAUDE_PROJECT_DIR \
    ${proj_env[@]+"${proj_env[@]}"} ${extra_env[@]+"${extra_env[@]}"} \
    python3 "$hook" 2>/dev/null)
  rc=$?

  got=allow
  if [ -n "$out" ]; then
    decision=$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out" 2>/dev/null)
    reason=$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$out" 2>/dev/null)
    got=bad-output
    if [ "$decision" = "deny" ]; then
      got=deny
      for need in adversarial-review-agent "REVIEW_GATE=off" ".claude/review-gate.off"; do
        case "$reason" in *"$need"*) ;; *) got=deny-bad-reason ;; esac
      done
    fi
  fi
  [ "$rc" -eq 0 ] || got="exit-$rc"

  if [ "$got" = "$expect" ]; then
    echo "PASS  $name - $got"
  else
    echo "FAIL  $name - expected $expect, got $got"
    fail=1
    nfail=$((nfail + 1))
  fi
done <"$cases"

echo "---"
echo "$total cases, $nfail failed"
exit "$fail"
