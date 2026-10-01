#!/usr/bin/env bash
# Produce an evidence log (WORKFLOW.md §12.3).
#   scripts/ai/run-checks.sh <task_id>                 # run scripts/ai/checks.txt
#   scripts/ai/run-checks.sh <task_id> -- <cmd...>     # run one ad-hoc command (e.g. a reproducer)
# Exit: 0 all passed, 1 some failed, 2 usage/precondition error, 3 no checks configured, 4 loop limit L2 reached.
set -uo pipefail

die() { echo "run-checks: $*" >&2; exit 2; }

[ $# -ge 1 ] || die "usage: $0 <task_id> [-- <command...>]"
task="$1"; shift
root="$(git rev-parse --show-toplevel)" || die "not in a git repository"
cd "$root"
tdir="tasks/$task"
[ -f "$tdir/task.yaml" ] || die "$tdir/task.yaml not found"

# Evidence must correspond to a commit: refuse if code (anything outside tasks/) is uncommitted.
if [ -n "$(git status --porcelain -- . ':(exclude)tasks')" ]; then
  git status --short -- . ':(exclude)tasks' >&2
  die "uncommitted changes outside tasks/. Commit first so evidence maps to a commit."
fi

# Loop limit L2 (WORKFLOW.md §11): count previous runs from evidence files, limit from task.yaml.
limit="$(sed -n 's/^[[:space:]]*max_check_runs:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$tdir/task.yaml" | head -n1)"
limit="${limit:-12}"
runs="$(find "$tdir/evidence" -maxdepth 1 -name '*.log' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$runs" -ge "$limit" ]; then
  echo "run-checks: LIMIT L2 reached ($runs/$limit runs). Stop and report to the human (raising it is gate G9)." >&2
  exit 4
fi

cmds=()
if [ $# -gt 0 ]; then
  [ "$1" = "--" ] || die "expected '--' before ad-hoc command"
  shift
  [ $# -gt 0 ] || die "empty ad-hoc command"
  cmds+=("$(printf '%q ' "$@")")
  label="adhoc"
else
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    cmds+=("$line")
  done < scripts/ai/checks.txt
  label="checks"
fi

head="$(git rev-parse HEAD)"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$tdir/evidence"
log="$tdir/evidence/${ts}-${label}.log"

{
  echo "# evidence"
  echo "task: $task"
  echo "commit: $head"
  echo "code_tree_clean: yes"
  echo "started: $ts"
  echo "host: $(uname -srm)"
} > "$log"

if [ ${#cmds[@]} -eq 0 ]; then
  echo "summary: NO_CHECKS_CONFIGURED" >> "$log"
  echo "run-checks: no active commands in scripts/ai/checks.txt -> cannot produce evidence ($log)" >&2
  exit 3
fi

fail=0; n=0
for c in "${cmds[@]}"; do
  n=$((n+1))
  echo "" >> "$log"
  echo "## command[$n]: $c" >> "$log"
  bash -c "$c" 2>&1 | tee -a "$log"
  rc=${PIPESTATUS[0]}
  echo "## exit[$n]: $rc" >> "$log"
  [ "$rc" -eq 0 ] || fail=$((fail+1))
done

echo "" >> "$log"
if [ "$fail" -eq 0 ]; then
  echo "summary: PASS ($n/$n commands exit 0)" >> "$log"
else
  echo "summary: FAIL ($fail/$n commands non-zero)" >> "$log"
fi
echo "run-checks: $(tail -n1 "$log") -> $log"
[ "$fail" -eq 0 ]
