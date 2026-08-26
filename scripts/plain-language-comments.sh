#!/usr/bin/env bash
# Exits 1 when a diff adds more comment lines than code lines in a source file.
# Takes an optional commit range. Default --cached, meaning the staged diff.
set -o pipefail
git rev-parse --git-dir >/dev/null 2>&1 || { echo "plain-language: not a git repository."; exit 2; }
case "${1:-}" in
    ""|--cached) RANGE="--cached" ;;
    -*|.*)     echo "plain-language: pass a commit range or nothing, not $1."; exit 2 ;;
    *)         RANGE="$1" ;;
esac
git -c diff.noprefix=false -c core.quotepath=false diff "$RANGE" -U0 --no-ext-diff --no-color --no-textconv \
    --src-prefix=a/ --dst-prefix=b/ -- \
    '*.py' '*.js' '*.jsx' '*.ts' '*.tsx' '*.go' '*.rs' '*.java' '*.kt' \
    '*.rb' '*.c' '*.h' '*.cc' '*.cpp' '*.cs' '*.php' '*.swift' '*.sh' | LC_ALL=C awk '
  # Headers are only read between "diff --git" and the first hunk, so a source
  # line starting "++ b/" cannot pose as one.
  { lines++ }
  /^diff --git / { hdrs++; inhdr = 1; next }
  /^@@/          { inhdr = 0; next }
  inhdr && /^\+\+\+ ("?b\/|\/dev\/null)/ {
      file = substr($0, 5)
      sub(/\t.*$/, "", file)          # git appends a tab when the path has a space
      gsub(/^"|"$/, "", file); sub(/^b\//, "", file)
      hash = (file ~ /\.(py|rb|sh)$/)
      next
  }
  inhdr { next }
  /^\+/ {
      if (file == "") { unparsed++; next }
      line = substr($0, 2); sub(/^[ \t]+/, "", line)
      if (line == "") next
      c = 0
      if (hash) {
          if (line ~ /^#/ && line !~ /^#!/) c = 1
      } else {
          if (line ~ /^\/\// || line ~ /^\/\*/ || line ~ /^\* / || line ~ /^\*\//) c = 1
      }
      if (c) comment[file]++; else code[file]++
  }
  END {
      if (lines > 0 && hdrs == 0) {
          print "plain-language: diff output carried no file headers. Parse failed."
          exit 2
      }
      if (unparsed > 0) {
          printf "plain-language: %d added lines had no file header. Parse failed.\n", unparsed
          exit 2
      }
      bad = 0
      for (f in comment)
          if (code[f] > 0 && comment[f] > code[f] && comment[f] >= 3) {
              printf "%s: +%d comment lines, +%d code lines\n", f, comment[f], code[f]
              bad = 1
          }
      if (bad) print "plain-language: hard limit 1. See the code-comment section."
      exit bad
  }'
