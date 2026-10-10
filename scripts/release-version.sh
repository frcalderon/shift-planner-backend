#!/usr/bin/env bash
# Usage: scripts/release-version.sh <fallback-version>
# Prints the next release version (without "v") from the highest v<major>.<minor>.<patch> tag in HEAD and the
# conventional commits (merges excluded) since it: breaking -> major, feat -> minor, anything else -> patch.
# With no previous tag it prints <fallback-version> without its -SNAPSHOT suffix.
set -euo pipefail

fallback=${1:?fallback version required}

tag=$(git tag --merged HEAD --list 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)
if [[ -z $tag ]]; then
  echo "${fallback%-SNAPSHOT}"
  exit 0
fi

if [[ $(git rev-list --count --no-merges "$tag..HEAD") -eq 0 ]]; then
  echo "No commits since $tag: nothing to release" >&2
  exit 1
fi

subjects=$(git log --no-merges --format=%s "$tag..HEAD")
bodies=$(git log --no-merges --format=%b "$tag..HEAD")

IFS=. read -r major minor patch <<< "${tag#v}"

if grep -qE '^[a-z]+(\([^)]*\))?!:' <<< "$subjects" || grep -qE '^BREAKING[ -]CHANGE:' <<< "$bodies"; then
  echo "$((major + 1)).0.0"
elif grep -qE '^feat(\([^)]*\))?:' <<< "$subjects"; then
  echo "$major.$((minor + 1)).0"
else
  echo "$major.$minor.$((patch + 1))"
fi
