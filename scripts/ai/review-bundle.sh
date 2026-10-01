#!/usr/bin/env bash
# Build an independent review input for Astra (WORKFLOW.md §8.1).
#   scripts/ai/review-bundle.sh <task_id> <round> [base_ref=main]
# Output: ${REVIEW_ROOT:-<repo>/../_review}/<task_id>-r<round>/{src,bundle}
#   src/    = git archive of HEAD (no .git, no commit messages), tasks/ removed
#   bundle/ = task.yaml, spec.md, diff.patch, diffstat.txt, evidence matching HEAD's code, MANIFEST.md
#   bundle/prior/ (round>=2) = previous astra-r*.md and responses-r*.md
# log.md / escalations.md / hypotheses.md are never included.
set -euo pipefail

die() { echo "review-bundle: $*" >&2; exit 2; }
[ $# -ge 2 ] || die "usage: $0 <task_id> <round> [base_ref]"
task="$1"; round="$2"; base="${3:-main}"
[[ "$round" =~ ^[1-9][0-9]*$ ]] || die "round must be a positive integer"

root="$(git rev-parse --show-toplevel)"
cd "$root"
tdir="tasks/$task"
[ -f "$tdir/task.yaml" ] || die "$tdir/task.yaml not found"
[ -z "$(git status --porcelain)" ] || die "working tree not clean; commit everything (incl. tasks/) first"

head="$(git rev-parse HEAD)"
mb="$(git merge-base "$base" HEAD)" || die "no merge-base with $base"
out="${REVIEW_ROOT:-$(cd "$root/.." && pwd)/_review}/$task-r$round"
[ -e "$out" ] && die "$out already exists (bundles are immutable; use a new round)"
mkdir -p "$out/src" "$out/bundle/evidence"

git archive HEAD | tar -x -C "$out/src"
rm -rf "$out/src/tasks"

cp "$tdir/task.yaml" "$out/bundle/"
[ -f "$tdir/spec.md" ] && cp "$tdir/spec.md" "$out/bundle/"
git diff "$mb" HEAD -- . ':(exclude)tasks' > "$out/bundle/diff.patch"
git diff --stat "$mb" HEAD -- . ':(exclude)tasks' > "$out/bundle/diffstat.txt"

# Include only evidence whose recorded commit has the same code (outside tasks/) as HEAD.
ev_count=0
shopt -s nullglob
for f in "$tdir"/evidence/*.log; do
  c="$(sed -n 's/^commit: //p' "$f" | head -n1)"
  [ -n "$c" ] || continue
  git cat-file -e "$c^{commit}" 2>/dev/null || continue
  if git diff --quiet "$c" HEAD -- . ':(exclude)tasks'; then
    cp "$f" "$out/bundle/evidence/"; ev_count=$((ev_count+1))
  fi
done

if [ "$round" -gt 1 ]; then
  mkdir -p "$out/bundle/prior"
  for f in "$tdir"/reviews/astra-r*.md "$tdir"/reviews/responses-r*.md; do
    cp "$f" "$out/bundle/prior/"
  done
fi

{
  echo "# Review bundle"
  echo "task: $task"
  echo "round: $round"
  echo "base_ref: $base"
  echo "base (merge-base): $mb"
  echo "head: $head"
  echo "created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "evidence_files_matching_head: $ev_count"
  [ "$ev_count" -eq 0 ] && echo "WARNING: no evidence for this code state -> treat tests as NOT RUN"
  echo ""
  echo "Excluded by design: .git (history, commit messages), tasks/ (implementer log, escalations, hypotheses)."
} > "$out/bundle/MANIFEST.md"

echo "bundle: $out (evidence matching HEAD: $ev_count)"
echo "run e.g.: (cd '$out' && codex exec --sandbox read-only -m \"\$ASTRA_MODEL\" \"\$(cat '$root/docs/ai-workflow/prompts/astra-review.md')\") > '$root/$tdir/reviews/astra-r$round.md'"
