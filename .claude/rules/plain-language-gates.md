# Plain language — the gates

Two runnable checks for `plain-language.md`. Neither is needed to read or install
the rule. Wire them in when the rule needs to hold after the first week.

A violation exits 1, which a pre-commit hook and a CI step read as failure. A
gate that cannot run exits 2 or higher.

Each gate below appears twice in this repo: as the fenced block you can copy, and
as a file under `scripts/` that CI runs. `scripts/plain-language-extract.sh`
pulls the block out of this file. The `plain-language` CI job diffs it against
the committed script, so the two copies cannot drift apart in silence. Save the
block at the same path when you copy this rule into your own repo.

---

## Gate 1: five rhetorical devices

Rule 6 bans twenty-five devices. Five are closed word lists, so a machine can
catch them. This repo runs it from `scripts/plain-language-rhetoric.sh`.

```bash
#!/usr/bin/env bash
# Exits 1 when a banned device appears. Portable ERE, no lookahead, no grep -P.
RHETORIC="not un(like|expected|common|usual|reasonable|important|familiar|heard)\
|no small([^-[:alnum:]]|$)|far from ideal|by no means|hardly surprising\
|(the point is|(here'?s|here is) the thing|needless to say|(it'?s|it is) worth noting)\
|at the end of the day\
|genuinely|honestly|frankly|truly([^-[:alnum:]]|$)|to be honest\
|very, very|really, really\
|not just a|not only .* but|n'?t (just|merely)|(is|are|was|were) not (just|merely)"

if [ "$#" -eq 0 ]; then
    echo "plain-language: no files given."
    exit 0
fi

grep -nEi "$RHETORIC" "$@"
status=$?
if [ "$status" -eq 0 ]; then
    echo "plain-language: rhetorical device found. Rewrite the line."
    exit 1
fi
if [ "$status" -gt 1 ]; then
    echo "plain-language: grep failed with exit $status. Check the file list."
    exit 2
fi
exit 0
```

Run it on changed Markdown.

### Gate 1 limits

Five limits, all measured on fixtures.

- It covers 5 of the 25 rows. The other twenty need structural judgement, so a
  clean run leaves most of rule 6 unchecked.
- It fires on literal uses of the banned phrases. Measured examples: "at the end
  of the day shift", "the point is transformed by the matrix", "here is the
  thing you asked for". Treat a hit as a line to look at.
- It reads stdin when given no files, so the no-args guard above returns early.
  Keep that guard if you edit the script.
- Exclude `plain-language.md`, `plain-language-devices.md`, and this file,
  because all three quote the banned phrases as examples.
- It reads whole files rather than the diff, so prose written before adoption day
  fails a branch that never touched it. Measured: a `README.md` carrying a device
  on line 2 exits 1 when the branch appends one clean line. Fix the old prose
  once, or scope the gate to changed lines yourself.

---

## Gate 2: comments longer than the code

Enforces hard limit 1 of the code-comment section. This repo runs it from
`scripts/plain-language-comments.sh`. It takes an optional commit range and
defaults to the staged diff, so one script serves a pre-commit hook and a CI
per-commit check.

```bash
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
```

### How it reads a diff

Seven defences, because a header-parsing bug in this script reads as a pass
rather than an error. Each one closes a fail-open measured on a fixture.

- `--no-ext-diff --no-color --no-textconv`, so an external diff tool, forced
  colour, or a textconv filter cannot reshape what the parser reads. Measured on
  one violation in a `.py` file across eight diff-shaping surfaces, including
  `diff.external`, `GIT_EXTERNAL_DIFF`, `color.ui=always`, and
  `color.diff=always`. All eight exit 1.
- `--src-prefix=a/ --dst-prefix=b/`, so `diff.mnemonicPrefix` and a custom
  `diff.srcPrefix` cannot rename the prefixes out from under the parser.
  Measured across five git configs. Two of them exited 0 against the script as
  it stood before these flags, and all five exit 1 now.
- `LC_ALL=C` on the awk, so a byte that is not valid UTF-8 cannot abort it. A
  latin-1 or cp1252 source file otherwise raises a multibyte conversion failure.
  Measured: a clean latin-1 `.py` exited 2 and now exits 0, and a violation in
  the same encoding exited 2 and now exits 1.
- The argument is a commit range or nothing. Anything starting with `-` or `.`
  exits 2. Without that guard, `git diff` accepts output-shaping flags that
  suppress the body. Measured with a violation staged: `--stat`, `--name-only`,
  `--quiet`, `-s`, `--exit-code`, `--output=`, `--` and `...HEAD` all exited 0,
  and all eight now exit 2.
- The parser reads headers only between `diff --git` and the first `@@`.
  Measured: a file carrying `-- a/decoy` at column 0 followed by `++ b/decoy.md`
  exited 0 before the window and exits 1 after.
- Output that arrives carrying no `diff --git` header exits 2 with a message.
  This backstops the first bullet when a mangler still produces output. A knob
  that empties the stream leaves the count at zero, so the gate exits 0 instead.
  Measured: a coloured stream fed straight to the parser exits 2, while
  nothing-staged, Markdown-only, and a pure rename all exit 0. A conflicted tree
  also exits 2, because `git diff --cached` renders `* Unmerged path` with no
  header. Git refuses the commit before the hook runs, so the hook never reaches
  it. Running the gate by hand in that state does.
- An added line that arrives with no file header raises a counter, and the
  script exits 2 with a message. That covers a parsing bug which still leaves
  `+` lines in the stream.

### Gate 2 limits

Ten limits, all measured on git fixtures.

- It reads a fixed extension list, so Markdown and YAML never trip it. A dotfile
  still trips when its extension is on the list, as `.eslintrc.js` does. Add
  your own extensions to that list.
- A `-diff` attribute exempts a file. That reaches generated and vendored code
  only where somebody marked it. Measured: `*_pb2.py -diff`, `*.min.js -diff`
  and `*.pb.go -diff` exit 0, while `linguist-generated=true`,
  `linguist-vendored`, an unmarked `thing_pb2.py` and an unmarked `vendor/lib.js`
  all exit 1. `protoc` ships no `.gitattributes`, so add the markers yourself.
  The cost is a way around the gate for anyone who marks a source file `-diff`.
- `#` counts as a comment only in `.py`, `.rb`, and `.sh`. A C `#include`, a
  C++ `#pragma`, a Rust `#[derive]`, and a shebang are code. Add a language by
  extending that test, never by treating `#` as universal.
- The `//` and `/* */` forms count only outside those three languages, so a
  Black-wrapped `* factor` continuation and a Python `// 2` floor division stay
  code.
- It matches a marker at the start of a line and keeps no block state. The `/*`
  and `*/` delimiters each count as one comment line. A body line counts only
  when it starts with `* `. An unprefixed body counts as code, so house
  formatting changes the totals for the same block. A JSX comment opens with a
  brace, so `{/*` counts as code while its `* ` body lines and its `*/}` close
  count as comments. SQL and HTML never reach the gate, because `.sql` and
  `.html` sit outside the pathspec.
- It strips leading spaces and tabs only. When a UTF-8 BOM, a form feed, or a
  non-breaking space indents a line, that byte classifies it. A `#` behind one
  counts as code.
- A line inside a string literal counts by its first character. A Python
  triple-quoted line starting `#`, or a JS template literal holding
  `//cdn.example.com`, counts as a comment.
- **Doc comments split by language, and this one bites.** A Python docstring
  counts as **code**, so the gate is lenient toward the exact shape in the
  rule's own example. A JSDoc, TSDoc, Javadoc, Rust `///`, or Go doc comment
  counts as a **comment**, so a six-line doc block over a one-line export exits
  1. Measured: `add.js` with a 6-line JSDoc over 1 code line trips, `doc.py`
  with a 6-line docstring over 2 code lines passes. That collides with the
  rule's "a public API still gets a docstring". On a JavaScript or TypeScript
  codebase, drop `.js .jsx .ts .tsx` from the pathspec, or raise the floor above
  your house doc-block size.
- It skips a file that adds zero code lines, so a licence header passes. The
  cost is a way around the gate: a comment-only diff of any size passes, however
  long the block.
- It needs three or more added comment lines. Fixing a typo in one comment
  passes. **A range dilutes rather than accumulates.** A two-dot or three-dot
  range is a net tree diff. A later commit adding code to the same file can
  cancel an earlier violation in it, once it adds enough. Measured on a branch whose first commit adds 4
  comment lines over 2 code lines. Its second commit adds 10 code lines to the
  same file, and the branch exits 0 under `main...HEAD`. Per commit it exits 1.
  Loop per commit in CI.

Hard limit 1 still needs a human on the PR checklist. This gate catches the
loudest cases.

---

## Wiring

These three surfaces are the ones that were measured. Git has more hook points
and more config knobs than this file tests, so treat anything else as your own
to verify. A commit-msg hook for Gate 1 was tried and dropped. Under
`commit.verbose`, git writes the whole staged diff into the message file before
the hook runs. Gate 1 then scanned source instead of prose, and it blocked clean
commits on pre-adoption comments.

### Check `core.hooksPath` first

`core.hooksPath` overrides `.git/hooks`, and the override is silent. Run this
before you trust any pre-commit wiring.

```bash
git config --get core.hooksPath   # empty means .git/hooks is live
```

Measured on a machine carrying a global `core.hooksPath`: the gate exits 1 by
hand, while the same commit with a `.git/hooks/pre-commit` hook goes through
untouched.

**Husky needs different advice, and the obvious move is wrong.** Husky points
`core.hooksPath` at `.husky/_`, and that directory is not where your hook goes.
Measured on husky 9.1.7. The file `.husky/_/.gitignore` holds `*`, so a hook
placed there is never committed and reaches no coworker. Running
`npm run prepare`, husky's own regeneration script, rewrites
`.husky/_/pre-commit` back to husky's shim. Put the call in
`.husky/pre-commit`, which husky leaves alone and git tracks.

### Surface 1: Gate 2 as a pre-commit hook

```bash
# .git/hooks/pre-commit, or .husky/pre-commit under husky
scripts/plain-language-comments.sh
```

Git blocks on any non-zero hook exit, so no `|| exit 1` is needed. Measured with
the hook wired: a clean stage commits, a violation blocks, and a missing script
blocks with its own error on stderr.

### Surface 2: Gate 2 in CI

The loop walks each ordinary commit, then one range pass catches what no single
commit holds. Both probes fail closed. Without them the loop returns 0 whenever
`rev-list` yields nothing, which is silent and wrong.

```bash
test "$(git rev-parse --is-shallow-repository)" = false || {
    echo "plain-language: shallow clone. Give CI full history."; exit 2; }
BASE=$(git merge-base origin/main HEAD) || {
    echo "plain-language: cannot resolve origin/main."; exit 2; }
rc=0
for c in $(git rev-list --no-merges --reverse "$BASE..HEAD"); do
    scripts/plain-language-comments.sh "$c^!" || rc=1
done
scripts/plain-language-comments.sh "$BASE...HEAD" || rc=1
exit $rc
```

`--no-merges` is load-bearing. A merge commit renders as a combined diff, header
`diff --cc` and markers `++`. The parser cannot read that shape, so the backstop
exits 2 and the loop reports a failure naming no file. Measured on a branch
holding zero comment lines: a blended conflict resolution exited 1 before the
flag and exits 0 after it. Measured separately: a violation introduced inside a
merge resolution exits 1 and names the file, through the range pass.

Both passes are needed and neither is enough alone. A range dilutes, so a later
commit adding code hides an earlier violation, and only the per-commit pass
catches that. A comment block committed apart from the code it documents is
invisible to every single commit, and only the range pass catches that.
Measured: a JSDoc block committed before its one-line export exits 0 per commit
and 1 on the range.

Measured on four checkouts. A full clone carrying one violation exits 1 and
names the file. A `--depth 1` clone, a depth-1 fetch of both refs, and a repo
whose default branch is `master` all exit 2.

### Surface 3: Gate 1 in CI, on changed Markdown

```bash
BASE=$(git merge-base origin/main HEAD) || {
    echo "plain-language: cannot resolve origin/main."; exit 2; }
git diff --name-only --diff-filter=d -z "$BASE...HEAD" -- '*.md' \
  | grep -zv 'plain-language' \
  | xargs -0 scripts/plain-language-rhetoric.sh
```

The `merge-base` probe is load-bearing here too. Without it, `git diff` writes
`fatal:` to stderr and nothing to stdout, `xargs` runs zero times, and the step
exits 0. Measured on the same four checkouts: control 1, and the depth-1 clone
and the `master` default both went 0 to 2.

`xargs` skips the run when nothing changed. Measured against `/usr/bin/xargs` on
macOS: it accepts `-r`, and it skips an empty run without the flag.

Both CI surfaces need full history. On GitHub Actions that means `fetch-depth: 0`
on the checkout step, because the default checkout fetches depth 1 and leaves
`origin/main` unreachable.

Wire all three. CI is the surface that survives a mis-set `core.hooksPath` and a
coworker who never installs the hook.

`.github/workflows/harness-gate.yml` runs surfaces 2 and 3 here, as the
`plain-language` job, on pull requests only. Both surfaces measure a branch
against its base, and a push to `main` leaves that range empty. Surface 1 stays
yours to install, because git does not track `.git/hooks`.
