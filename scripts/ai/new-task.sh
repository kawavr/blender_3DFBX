#!/usr/bin/env bash
# Create branch ai/<task_id>, worktree ../wt/<task_id>, and tasks/<task_id>/ from templates.
#   scripts/ai/new-task.sh <task_id> <class> [base_ref=main]
set -euo pipefail

die() { echo "new-task: $*" >&2; exit 2; }
[ $# -ge 2 ] || die "usage: $0 <task_id> <class> [base_ref]"
task="$1"; class="$2"; base="${3:-main}"
[[ "$task" =~ ^T-[0-9]{8}-[a-z0-9-]+$ ]] || die "task_id must look like T-YYYYMMDD-short-slug"

root="$(git rev-parse --show-toplevel)"
branch="ai/$task"
wt="$(cd "$root/.." && pwd)/wt/$task"

git -C "$root" rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "base '$base' not found"
git -C "$root" rev-parse --verify --quiet "refs/heads/$branch" >/dev/null && die "branch $branch already exists"
[ -e "$wt" ] && die "worktree path $wt already exists"

base_commit="$(git -C "$root" rev-parse "$base")"
mkdir -p "$(dirname "$wt")"
git -C "$root" worktree add -b "$branch" "$wt" "$base_commit"

tdir="$wt/tasks/$task"
[ -e "$tdir" ] && die "$tdir already exists in base"
mkdir -p "$tdir/evidence" "$tdir/reviews"
tpl="$root/docs/ai-workflow/templates"
sed -e "s/__TASK_ID__/$task/g" -e "s/__CLASS__/$class/g" \
    -e "s/__DATE__/$(date -u +%Y-%m-%d)/g" -e "s/__BASE_COMMIT__/$base_commit/g" \
    "$tpl/task.yaml" > "$tdir/task.yaml"
sed -e "s/__TASK_ID__/$task/g" "$tpl/log.md" > "$tdir/log.md"
touch "$tdir/evidence/.gitkeep" "$tdir/reviews/.gitkeep"

echo "created: branch=$branch worktree=$wt"
echo "next: fill $tdir/task.yaml (TRIAGE), then commit."
