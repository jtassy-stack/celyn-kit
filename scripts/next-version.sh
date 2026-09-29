#!/usr/bin/env bash
# next-version.sh — the next semver tag of celyn-kit, from conventional commits.
#
#   scripts/next-version.sh            # prints e.g. 1.19.0, or nothing if no release is due
#   scripts/next-version.sh 1.16.1     # pretend that tag is the last one (tests / dry runs)
#
# Only commits touching the package itself (Sources/, Package.swift) count:
# docs / CI / tests-only commits do not cut a release.
#   BREAKING CHANGE in the body, or "type!:" in the subject  -> major
#   feat:                                                    -> minor
#   anything else (fix, perf, refactor...)                   -> patch
set -euo pipefail

BASE="${1:-$(git tag --list '[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)}"
[[ -n "$BASE" ]] || { echo "no base tag" >&2; exit 1; }

RANGE="$BASE..HEAD"
git rev-parse -q --verify "refs/tags/$BASE" >/dev/null || { echo "unknown tag $BASE" >&2; exit 1; }

re_breaking='^[a-z]+(\([^)]*\))?!:'
re_feat='^feat(\([^)]*\))?:'
bump=""
while IFS= read -r sha; do
  [[ -n "$sha" ]] || continue
  subject="$(git log -1 --format=%s "$sha")"
  body="$(git log -1 --format=%b "$sha")"
  if [[ "$subject" =~ $re_breaking ]] || grep -q "BREAKING CHANGE" <<<"$body"; then bump="major"; break
  elif [[ "$subject" =~ $re_feat ]]; then [[ "$bump" == "major" ]] || bump="minor"
  else [[ -n "$bump" ]] || bump="patch"
  fi
done < <(git log --format=%H "$RANGE" -- Sources Package.swift)

[[ -n "$bump" ]] || exit 0

IFS=. read -r MA MI PA <<<"$BASE"
case "$bump" in
  major) echo "$((MA + 1)).0.0" ;;
  minor) echo "$MA.$((MI + 1)).0" ;;
  patch) echo "$MA.$MI.$((PA + 1))" ;;
esac
