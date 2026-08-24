#!/usr/bin/env bash

set -euo pipefail

readonly repo="maisieyang/writing"
readonly branch="main"
readonly commit_message="${1:-Publish site updates}"

push_head_via_github_api() {
  local commit_sha="$1"
  local parent_sha remote_sha base_tree tree_entries
  local change_status change_path mode object_type blob_sha
  local new_tree commit_payload api_commit_sha

  parent_sha="$(git rev-parse "$commit_sha^")"
  remote_sha="$(gh api "repos/$repo/git/ref/heads/$branch" --jq '.object.sha')"

  if [[ "$remote_sha" != "$parent_sha" ]]; then
    echo "API fallback aborted: remote branch is not the parent of the local commit." >&2
    return 1
  fi

  base_tree="$(git rev-parse "$parent_sha^{tree}")"
  tree_entries='[]'

  while IFS=$'\t' read -r change_status change_path; do
    if [[ "$change_status" == "D" ]]; then
      tree_entries="$(
        jq -c --arg path "$change_path" \
          '. + [{path: $path, mode: "100644", type: "blob", sha: null}]' \
          <<< "$tree_entries"
      )"
      continue
    fi

    read -r mode object_type < <(
      git ls-tree "$commit_sha" -- "$change_path" | awk '{print $1, $2}'
    )
    blob_sha="$(
      git show "$commit_sha:$change_path" |
        jq -Rs '{content: ., encoding: "utf-8"}' |
        gh api --method POST "repos/$repo/git/blobs" --input - --jq '.sha'
    )"
    tree_entries="$(
      jq -c \
        --arg path "$change_path" \
        --arg mode "$mode" \
        --arg type "$object_type" \
        --arg sha "$blob_sha" \
        '. + [{path: $path, mode: $mode, type: $type, sha: $sha}]' \
        <<< "$tree_entries"
    )"
  done < <(
    git diff-tree --no-commit-id --name-status --no-renames -r \
      "$parent_sha" "$commit_sha"
  )

  new_tree="$(
    jq -n \
      --arg base_tree "$base_tree" \
      --argjson tree "$tree_entries" \
      '{base_tree: $base_tree, tree: $tree}' |
      gh api --method POST "repos/$repo/git/trees" --input - --jq '.sha'
  )"

  commit_payload="$(
    git cat-file commit "$commit_sha" |
      sed '1,/^$/d' |
      jq -Rs \
        --arg tree "$new_tree" \
        --arg parent "$parent_sha" \
        --arg author_name "$(git show -s --format=%an "$commit_sha")" \
        --arg author_email "$(git show -s --format=%ae "$commit_sha")" \
        --arg author_date "$(git show -s --format=%aI "$commit_sha")" \
        --arg committer_name "$(git show -s --format=%cn "$commit_sha")" \
        --arg committer_email "$(git show -s --format=%ce "$commit_sha")" \
        --arg committer_date "$(git show -s --format=%cI "$commit_sha")" \
        '{
          message: .,
          tree: $tree,
          parents: [$parent],
          author: {
            name: $author_name,
            email: $author_email,
            date: $author_date
          },
          committer: {
            name: $committer_name,
            email: $committer_email,
            date: $committer_date
          }
        }'
  )"

  api_commit_sha="$(
    gh api --method POST "repos/$repo/git/commits" \
      --input - --jq '.sha' <<< "$commit_payload"
  )"

  if [[ "$api_commit_sha" != "$commit_sha" ]]; then
    echo "API fallback aborted: GitHub created a different commit." >&2
    return 1
  fi

  gh api --method PATCH "repos/$repo/git/refs/heads/$branch" \
    -f sha="$commit_sha" -F force=false --silent
  git update-ref "refs/remotes/origin/$branch" "$commit_sha" "$remote_sha"
  echo "Published commit through the GitHub API fallback."
}

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
if ! git push origin "$branch"; then
  echo "HTTPS push failed; trying the GitHub API fallback." >&2
  push_head_via_github_api "$commit_sha"
fi

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
