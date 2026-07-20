#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 --repo PATH --source ID --output DIR [--checkpoint-prefix PREFIX]" >&2
  exit 2
}

repo=""
source_id=""
output=""
checkpoint_prefix="feedback-reviewed"
while test "$#" -gt 0; do
  case "$1" in
    --repo) test "$#" -ge 2 || usage; repo="$2"; shift 2 ;;
    --source) test "$#" -ge 2 || usage; source_id="$2"; shift 2 ;;
    --output) test "$#" -ge 2 || usage; output="$2"; shift 2 ;;
    --checkpoint-prefix) test "$#" -ge 2 || usage; checkpoint_prefix="$2"; shift 2 ;;
    *) usage ;;
  esac
done

test -n "$repo" && test -n "$source_id" && test -n "$output" || usage
case "$source_id" in (*[!A-Za-z0-9._-]*|'') echo "invalid source id" >&2; exit 2;; esac
case "$checkpoint_prefix" in (*[!A-Za-z0-9._-]*|'') echo "invalid checkpoint prefix" >&2; exit 2;; esac

repo="$(git -C "$repo" rev-parse --show-toplevel)"
head="$(git -C "$repo" rev-parse HEAD)"
checkpoint="$checkpoint_prefix/$source_id"
umask 077
mkdir -p "$output"
chmod 700 "$output"

range="HEAD"
base=""
if git -C "$repo" rev-parse -q --verify "refs/tags/$checkpoint^{commit}" >/dev/null; then
  base="$(git -C "$repo" rev-parse "refs/tags/$checkpoint^{commit}")"
  if ! git -C "$repo" merge-base --is-ancestor "$base" "$head"; then
    echo "checkpoint is not an ancestor of HEAD: $checkpoint" >&2
    exit 1
  fi
  range="$base..$head"
fi

git -C "$repo" log --reverse --date=iso-strict \
  --format='%H%x09%aI%x09%an%x09%s' "$range" >"$output/commits.tsv"
git -C "$repo" log --reverse --date=iso-strict --format='commit %H%nAuthor: %an%nDate: %aI%nSubject: %s%n' \
  --patch --binary "$range" >"$output/series.patch"

count="$(wc -l <"$output/commits.tsv" | tr -d ' ')"
dirty="false"
test -z "$(git -C "$repo" status --porcelain)" || dirty="true"
{
  printf 'source=%s\n' "$source_id"
  printf 'checkpoint=%s\n' "$checkpoint"
  printf 'base=%s\n' "$base"
  printf 'head=%s\n' "$head"
  printf 'commit_count=%s\n' "$count"
  printf 'working_tree_dirty=%s\n' "$dirty"
} >"$output/manifest.env"

printf 'collected %s commits into %s\n' "$count" "$output"
