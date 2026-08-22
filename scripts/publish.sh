#!/usr/bin/env bash

set -euo pipefail

readonly repo="maisieyang/writing"
readonly branch="main"
readonly commit_message="${1:-Publish site updates}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "$branch" ]]; then
  echo "Publish aborted: expected branch '$branch', found '$current_branch'." >&2
  exit 1
fi

git diff --check

if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "$commit_message"
else
  echo "No local changes to commit."
fi

commit_sha="$(git rev-parse HEAD)"
git push origin "$branch"

echo "Waiting for GitHub Pages..."
for _ in {1..36}; do
  IFS=$'\t' read -r build_status build_commit < <(
    gh api "repos/$repo/pages/builds/latest" --jq '[.status, .commit] | @tsv'
  )

  if [[ "$build_commit" == "$commit_sha" && "$build_status" == "built" ]]; then
    echo "Published: https://maisieyang.github.io/writing/"
    exit 0
  fi

  if [[ "$build_commit" == "$commit_sha" && "$build_status" == "errored" ]]; then
    echo "GitHub Pages build failed." >&2
    exit 1
  fi

  sleep 5
done

echo "Push succeeded, but GitHub Pages is still building." >&2
exit 1
