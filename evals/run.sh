#!/usr/bin/env bash
# Minimal eval runner — proves the deterministic gate eval-001 depends on
# actually holds. A full eval also sends the prompt to a live model and checks
# the agent's behavior; that needs credentials, so what runs here (and in CI) is
# the part that doesn't: it feeds the exact tempting literal from
# evals/example-eval.md through the real check-no-secrets hook and asserts the
# write is BLOCKED. If this ever flips green->red, the gate the eval relies on
# broke — which is exactly what an eval is for.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
hook="$here/../.claude/hooks/check-no-secrets.sh"

fail=0
check_blocked() {   # $1 = label, $2 = JSON payload
  if printf '%s' "$2" | "$hook" >/dev/null 2>&1; then
    echo "FAIL  $1 — the write was ALLOWED (hook exited 0)"
    fail=1
  else
    echo "PASS  $1 — the write was blocked"
  fi
}
check_allowed() {   # clean content must pass
  if printf '%s' "$2" | "$hook" >/dev/null 2>&1; then
    echo "PASS  $1 — clean content allowed"
  else
    echo "FAIL  $1 — clean content was blocked (false positive)"
    fail=1
  fi
}

# eval-001: the literal secret from example-eval.md, via BOTH tool payloads.
SECRET='sk-live-EXAMPLE0000000000000000000000'
check_blocked "eval-001 Write" "$(printf '{"tool_input":{"content":"key = \"%s\""}}' "$SECRET")"
check_blocked "eval-001 Edit"  "$(printf '{"tool_input":{"new_string":"key = \"%s\""}}' "$SECRET")"
check_allowed "eval-001 clean" '{"tool_input":{"content":"key = process.env.PAYMENTS_API_KEY"}}'

# ---------------------------------------------------------------------------
# eval-002/003/004: the two plain-language gates, and the copies they ship as.
# The rule carries each gate twice, as a fenced block a reader copies out and as
# a file this repo runs. See evals/plain-language-eval.md.

rhetoric="$here/../scripts/plain-language-rhetoric.sh"
comments="$here/../scripts/plain-language-comments.sh"
extract="$here/../scripts/plain-language-extract.sh"

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

check_status() {   # $1 = label, $2 = wanted exit, rest = the command
  label="$1"; want="$2"; shift 2
  got=0
  "$@" >/dev/null 2>&1 </dev/null || got=$?
  if [ "$got" = "$want" ]; then
    echo "PASS  $label — exit $got"
  else
    echo "FAIL  $label — exit $got, wanted $want"
    fail=1
  fi
}
check_says() {     # $1 = label, $2 = wanted substring, rest = the command
  label="$1"; want="$2"; shift 2
  out="$("$@" 2>&1 </dev/null || true)"
  case "$out" in
    *"$want"*) echo "PASS  $label — said \"$want\"" ;;
    *)         echo "FAIL  $label — output missing \"$want\""; fail=1 ;;
  esac
}
mkrepo() {         # $1 = path
  mkdir -p "$1"
  git -C "$1" init -q >/dev/null 2>&1
  git -C "$1" config core.autocrlf false
}
run_comments() {   # $1 = repo, rest = the gate's own arguments
  dir="$1"; shift
  ( cd "$dir" && "$comments" "$@" )
}
diff_block() {     # $1 = heading, $2 = the shipped script
  # This is the only drift check, so it prints the difference rather than -q.
  "$extract" "$1" | diff -u - "$2"
}

# eval-002: gate 1 reads prose.
printf 'The point is that this sentence trips the gate.\n' > "$tmp/dirty.md"
printf 'This sentence states its claim and stops.\n'       > "$tmp/clean.md"
check_status "eval-002 banned device"  1 "$rhetoric" "$tmp/dirty.md"
check_status "eval-002 clean prose"    0 "$rhetoric" "$tmp/clean.md"
# The no-files guard keeps the CI xargs step from scanning stdin. GNU xargs runs
# the command once with no arguments when nothing changed.
check_says   "eval-002 no-files guard" "no files given" "$rhetoric"

# eval-003: gate 2 reads a diff. Two fixture repos, so neither leaks into the other.
mkrepo "$tmp/heavy"
printf '# one\n# two\n# three\n# four\nx = 1\n' > "$tmp/heavy/thing.py"
git -C "$tmp/heavy" add thing.py
check_status "eval-003 comments outnumber code" 1 run_comments "$tmp/heavy"

mkrepo "$tmp/lean"
printf '# why this constant\na = 1\nb = 2\nc = 3\nd = 4\n' > "$tmp/lean/thing.py"
git -C "$tmp/lean" add thing.py
check_status "eval-003 comments in proportion"  0 run_comments "$tmp/lean"
# A git diff flag can empty the stream, which the parser would read as clean.
check_status "eval-003 flag argument refused"   2 run_comments "$tmp/lean" --stat
mkdir -p "$tmp/norepo"
check_status "eval-003 outside a git repo"      2 run_comments "$tmp/norepo"

# eval-004: the shipped scripts still match their fenced block in the rule.
check_status "eval-004 gate 1 matches the rule" 0 \
  diff_block "## Gate 1: five rhetorical devices" "$rhetoric"
check_status "eval-004 gate 2 matches the rule" 0 \
  diff_block "## Gate 2: comments longer than the code" "$comments"
check_status "eval-004 missing heading fails closed" 2 "$extract" "## Gate 9: absent"
# A heading that merely starts with the wanted text must not shadow the real one.
# A prefix match here returns the wrong script and still exits 0.
{ printf '## Gate 1: five rhetorical devices, second edition\n\n'
  printf '```bash\necho SHADOW\n```\n\n'
  printf '## Gate 1: five rhetorical devices\n\n'
  printf '```bash\necho REAL\n```\n'; } > "$tmp/shadow.md"
extract_from() { DOC="$1" "$extract" "$2"; }
check_says "eval-004 exact heading match" "REAL" \
  extract_from "$tmp/shadow.md" "## Gate 1: five rhetorical devices"

# eval-005: the review gate denies a publish command until the session shows a
# review dispatch. 110 cases live in evals/review-gate/. See evals/LEDGER.md.
check_status "eval-005 review-gate cases" 0 "$here/review-gate/run-cases.sh"

exit "$fail"
