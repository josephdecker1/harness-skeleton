#!/usr/bin/env bash
# Prints the fenced bash block under a heading in plain-language-gates.md.
# Each gate script lives twice: as a copyable block in the rule, and as a file this
# repo runs. CI diffs one against the other. A missing heading exits 2, so a rename
# fails the check instead of comparing against nothing.
set -o pipefail

DOC="${DOC:-$(dirname "$0")/../.claude/rules/plain-language-gates.md}"

if [ "$#" -ne 1 ]; then
    echo "usage: plain-language-extract.sh '## Gate 1: five rhetorical devices'" >&2
    exit 2
fi
if [ ! -f "$DOC" ]; then
    echo "plain-language: no such document: $DOC" >&2
    exit 2
fi

out=$(awk -v h="$1" '
  index($0, h) == 1 { seen = 1; next }
  !seen             { next }
  inblk && /^```$/  { exit }
  inblk             { print; next }
  /^## /            { exit }
  /^```bash$/       { inblk = 1 }
' "$DOC") || { echo "plain-language: awk failed reading $DOC" >&2; exit 2; }

if [ -z "$out" ]; then
    echo "plain-language: no fenced bash block under \"$1\" in $DOC" >&2
    exit 2
fi
printf '%s\n' "$out"
