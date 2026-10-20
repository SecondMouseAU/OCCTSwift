#!/usr/bin/env bash
# Fast-forward the staging fork's IR to upstream and confirm they match.
# master is not synced: a push to it runs the fork's two heavy workflows.
# Run at the start of every upstream case. Refuses if the fork has commits of its own.
set -euo pipefail

# upstream/ is gitignored and lives in the main checkout, not in a linked worktree
root="$(cd "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)/.." && pwd)"
cd "$root/upstream"
eval "$(direnv export bash 2>/dev/null)"

login="$(gh api user --jq .login)"
if [ "$login" != "gsdali" ]; then
  echo "expected gsdali, got '$login'" >&2
  exit 2
fi

for branch in IR; do
  gh repo sync SecondMouseAU/OCCT -b "$branch" >/dev/null
  up="$(gh api "repos/Open-Cascade-SAS/OCCT/commits/$branch" --jq .sha)"
  fork="$(gh api "repos/SecondMouseAU/OCCT/commits/$branch" --jq .sha)"
  if [ "$up" != "$fork" ]; then
    echo "$branch differs: upstream $up, fork $fork" >&2
    exit 1
  fi
  echo "$branch ${up:0:9}"
done
