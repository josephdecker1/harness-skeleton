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
      --arg fp "$(jq -r '.file_path // empty' <<<"$line")" \
      '{hook_event_name:"PreToolUse", tool_name:$tool, cwd:$cwd,
        tool_input:({command:$cmd} + (if $fp == "" then {} else {file_path:$fp} end))}
       + (if $tp == "" then {} else {transcript_path:$tp} end)')
  fi

  extra_env=()
  while IFS= read -r kv; do
    [ -n "$kv" ] && extra_env+=("$kv")
  done < <(jq -r '.env // {} | to_entries[] | "\(.key)=\(.value)"' <<<"$line")

  out=$(printf '%s' "$payload" | env -u REVIEW_GATE -u CLAUDE_PROJECT_DIR -u CLAUDE_PLUGIN_ROOT \
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
      needs=()
      while IFS= read -r need; do needs+=("$need"); done < <(jq -r '.reason_has[]?' <<<"$line")
      [ ${#needs[@]} -gt 0 ] || needs=(adversarial-review-agent "REVIEW_GATE=off" ".claude/review-gate.off")
      for need in "${needs[@]}"; do
        case "$reason" in *"$need"*) ;; *) got=deny-bad-reason ;; esac
      done
      while IFS= read -r bad; do
        [ -n "$bad" ] || continue
        case "$reason" in *"$bad"*) got=deny-bad-reason ;; esac
      done < <(jq -r '.reason_lacks[]?' <<<"$line")
    fi
  fi
  [ "$rc" -eq 0 ] || got="exit-$rc"
  while IFS= read -r f; do
    [ -n "$f" ] && [ -e "$proj/$f" ] && got="$got-but-$f-kept"
  done < <(jq -r '.gone[]?' <<<"$line")
  while IFS= read -r f; do
    [ -n "$f" ] && [ ! -e "$proj/$f" ] && got="$got-but-$f-gone"
  done < <(jq -r '.kept[]?' <<<"$line")

  if [ "$got" = "$expect" ]; then
    echo "PASS  $name - $got"
  else
    echo "FAIL  $name - expected $expect, got $got"
    fail=1
    nfail=$((nfail + 1))
  fi
done <"$cases"

# Parallel tool calls in one turn run their hooks at the same moment. One off file must let
# exactly one of two concurrent publishes through, in every trial.
total=$((total + 1))
name="parallel publishes spend one off file"
proj="$work/race"
mkdir -p "$proj/.claude"
payload=$(jq -nc --arg t "$here/fixtures/no-review.jsonl" --arg cwd "$proj" \
  '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, transcript_path:$t,
    tool_input:{command:"git push"}}')
bad=0
for _ in $(seq 20); do
  : >"$proj/.claude/review-gate.off"
  for s in a b; do
    printf '%s' "$payload" | env -u REVIEW_GATE -u CLAUDE_PROJECT_DIR -u CLAUDE_PLUGIN_ROOT \
      python3 "$hook" >"$work/race-$s" 2>/dev/null &
  done
  wait
  allowed=0
  for s in a b; do [ -s "$work/race-$s" ] || allowed=$((allowed + 1)); done
  [ "$allowed" -eq 1 ] || bad=$((bad + 1))
  rm -f "$proj/.claude/review-gate.off"
done
if [ "$bad" -eq 0 ]; then
  echo "PASS  $name - 20 of 20 trials let exactly one through"
else
  echo "FAIL  $name - $bad of 20 trials did not let exactly one through"
  fail=1
  nfail=$((nfail + 1))
fi

echo "---"
echo "$total cases, $nfail failed"
exit "$fail"
