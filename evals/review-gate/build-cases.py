#!/usr/bin/env python3
"""Regenerate fixtures/ and review-gate-cases.jsonl. Run from this directory."""
import json
from pathlib import Path

HERE = Path(__file__).parent
FIX = HERE / "fixtures"
FIX.mkdir(exist_ok=True)


def user(text):
    return {"type": "user", "message": {"role": "user",
            "content": [{"type": "text", "text": text}]}}


def asst_text(text):
    return {"type": "assistant", "message": {"role": "assistant",
            "content": [{"type": "text", "text": text}]}}


def tool_use(name, **inp):
    return {"type": "assistant", "message": {"role": "assistant", "content": [
        {"type": "tool_use", "id": "toolu_01", "name": name, "input": inp}]}}


def result(text):
    return {"type": "user", "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": "toolu_01", "content": text}]}}


def review(subagent_type="adversarial-review-agent", tool="Agent", **extra):
    inp = {"description": "Review the diff", "subagent_type": subagent_type,
           "prompt": "Review branch feature/x against main. Anchored goal: add retry."}
    inp.update(extra)
    return tool_use(tool, **inp)


NOISE = [
    user("Add retry to the client, then we can talk about an adversarial-review-agent run."),
    asst_text('I will dispatch {"name":"Agent"} with subagent_type adversarial-review-agent later.'),
    tool_use("Bash", command="git status"),
    tool_use("Agent", description="Research retry libraries", subagent_type="general-purpose",
             prompt="Survey adversarial testing and review tools for retries."),
    result("adversarial-review-agent is mentioned in this tool result only"),
]
GOOD = NOISE + [review(), result("VERDICT: CONCEDE")]

FIXTURES = {
    "no-review.jsonl": NOISE,
    "review.jsonl": GOOD,
    "review-namespaced.jsonl": NOISE + [review("harness-skeleton:adversarial-review-agent")],
    "review-prompt-ref.jsonl": NOISE + [tool_use(
        "Agent", description="Review", subagent_type="general-purpose",
        prompt="Read .claude/agents/adversarial-review-agent.md for your context package.")],
    "review-legacy-task.jsonl": NOISE + [review(tool="Task")],
    "review-then-edit.jsonl": GOOD + [tool_use("Edit", file_path="a.py", old_string="x",
                                               new_string="y"), result("ok")],
    "lookalike-agent.jsonl": NOISE + [review("not-adversarial-review-agent"),
                                      review("adversarial-review-agent-lite")],
    "foreign-shape.jsonl": [{"role": "assistant", "content": "ran a command"}],
}
for name, recs in FIXTURES.items():
    (FIX / name).write_text("".join(json.dumps(r, separators=(",", ":")) + "\n" for r in recs))
(FIX / "garbled.jsonl").write_text('not json\n{"type":"assistant","message":\n')

C = []


def case(name, command, transcript, expect, **extra):
    C.append({"name": name, "command": command, "transcript": transcript,
              "expect": expect, **extra})


NR, R = "no-review.jsonl", "review.jsonl"
for label, cmd in [
    ("git push", "git push"),
    ("git push with remote and branch", "git push -u origin feature/x"),
    ("git push force", "git push --force-with-lease origin fix/y"),
    ("gh pr create", "gh pr create --title 'feat: x' --body 'y'"),
    ("gh pr merge", "gh pr merge 42 --squash"),
    ("gh pr ready", "gh pr ready 42"),
    ("git -C push", "git -C ../other-repo push origin main"),
    ("env prefix push", "GIT_SSH_COMMAND='ssh -i k' git push"),
    ("env prefix gh pr create", "GH_TOKEN=$(cat tok) gh pr create --fill"),
    ("gh with --repo flag", "gh --repo acme/app pr merge 7"),
    ("full path git", "/usr/bin/git push"),
]:
    case(f"deny {label}, no review", cmd, NR, "deny")
    case(f"allow {label}, review ran", cmd, R, "allow")

for label, cmd in [
    ("and-chain", "git add -A && git commit -m done && git push"),
    ("semicolon chain", "git commit -m x; git push"),
    ("or chain", "git fetch || git push origin main"),
    ("pipe", "echo built | tee log.txt && git push"),
    ("pipe into publish segment", "echo y | gh pr merge 3"),
    ("subshell", "(cd sub && git push)"),
    ("command substitution", "RESP=$(gh pr merge 42 --squash) && echo \"$RESP\""),
    ("backticks", "URL=`gh pr create --fill`"),
    ("substitution inside double quotes", "echo \"$(git push)\""),
    ("bash -c", "bash -c 'git push origin main'"),
    ("newline separated", "git add .\ngit push"),
    ("background", "git push &"),
    ("redirect then push", "git push 2>&1 | tail -3"),
    ("env wrapper", "env FOO=1 git push"),
    ("shell if", "if git diff --quiet; then git push; fi"),
    ("heredoc then push", "cat > n.md <<EOF\nexample\nEOF\ngit push"),
]:
    case(f"deny chained: {label}", cmd, NR, "deny")
case("allow chained push after review", "git add -A && git commit -m done && git push", R, "allow")

for label, cmd in [
    ("commit message names gh pr create", "git commit -m 'then run gh pr create'"),
    ("commit message with && and git push",
     "git commit -m \"fix: a && git push && b\""),
    ("echo single quotes", "echo 'next: git push after review'"),
    ("echo double quotes", "echo \"gh pr merge 5 later\""),
    ("grep pattern", "grep -rn 'git push' docs/"),
    ("heredoc body", "cat > doc.md <<'EOF'\ngit push\ngh pr create\nEOF\necho done"),
    ("heredoc commit message", "git commit -F - <<EOF\nWe ran git push here.\nEOF"),
    ("here-string", "cat <<<'git push'"),
    ("comment", "ls # git push later"),
    ("script flag --push", "python3 tool.py --push"),
]:
    case(f"allow mention: {label}", cmd, NR, "allow")

for label, cmd in [
    ("git status", "git status"),
    ("git commit", "git commit -m 'wip'"),
    ("git pull", "git pull --rebase"),
    ("git stash push", "git stash push -m wip"),
    ("git push --dry-run", "git push --dry-run origin main"),
    ("git push -n", "git push -n"),
    ("git push -un", "git push -un origin main"),
    ("git -C status", "git -C ../x status"),
    ("git log", "git log origin/main..HEAD --oneline"),
    ("gh pr view", "gh pr view 42 --json state"),
    ("gh pr list", "gh pr list"),
    ("gh pr checks", "gh pr checks 42"),
    ("gh pr diff", "gh pr diff 42"),
    ("gh pr create --help", "gh pr create --help"),
    ("gh issue create", "gh issue create --title x"),
    ("gh repo view", "gh repo view"),
    ("docker push", "docker push registry.example.com/app:v1"),
    ("npm publish", "npm publish"),
    ("empty command", ""),
]:
    case(f"allow non-publish: {label}", cmd, NR, "allow")

case("deny plugin-namespaced lookalike is not a review", "git push", "lookalike-agent.jsonl", "deny")
case("allow plugin-namespaced review", "git push", "review-namespaced.jsonl", "allow")
case("allow review found by prompt reference", "git push", "review-prompt-ref.jsonl", "allow")
case("allow legacy Task tool review", "gh pr create --fill", "review-legacy-task.jsonl", "allow")
case("allow when review came before a later edit", "git push", "review-then-edit.jsonl", "allow")
case("allow inline transcript with review", "git push", GOOD, "allow")
case("deny inline transcript without review", "git push", NOISE, "deny")
case("deny inline transcript, no tool calls", "gh pr merge 1", [user("hi"), asst_text("hello")], "deny")

case("deny REVIEW_GATE=off prefix does not skip the gate", "REVIEW_GATE=off git push", NR, "deny")
case("deny REVIEW_GATE=off on a different segment", "REVIEW_GATE=off echo hi; git push", NR, "deny")
case("deny env REVIEW_GATE=off wrapper does not skip the gate", "env REVIEW_GATE=off gh pr create --fill", NR, "deny")
case("allow killswitch env var", "git push", NR, "allow", env={"REVIEW_GATE": "off"})
case("deny REVIEW_GATE=on is not a killswitch", "git push", NR, "deny", env={"REVIEW_GATE": "on"})
case("allow killswitch file in project dir", "git push", NR, "allow",
     files=[".claude/review-gate.off"])
case("deny no killswitch file", "git push", NR, "deny", files=[".claude/other.txt"])
case("allow killswitch file via CLAUDE_PROJECT_DIR", "git push", NR, "allow",
     files=[".claude/review-gate.off"], payload_cwd="elsewhere", project_dir=True)
case("allow non-Bash tool", "git push", NR, "allow", tool_name="Read")

case("allow missing transcript file (fail open)", "git push", "does-not-exist.jsonl", "allow")
case("allow missing transcript_path (fail open)", "git push", None, "allow")
case("allow foreign transcript shape (fail open)", "git push", "foreign-shape.jsonl", "allow")
case("deny garbled transcript with assistant marker, no review", "git push",
     "garbled.jsonl", "deny")
case("allow bad stdin (fail open)", "git push", NR, "allow", raw_stdin="{not json")

(HERE / "review-gate-cases.jsonl").write_text("".join(json.dumps(c) + "\n" for c in C))
print(len(C), "cases")
