#!/usr/bin/env bash
#
# design-anchors.sh — verify every `design:` comment resolves to a real anchor.
#
#   ./design-anchors.sh                check the whole repo
#   ./design-anchors.sh --since <ref>  only files changed since <ref>
#   ./design-anchors.sh --list         also print every resolved link as a table
#
# A comment in code names the design section it implements:
#
#     // design: design-docs/features/auth-email-normalisation.md [AUTH-3]
#
# and the document declares the anchor:
#
#     ## Email normalisation {#AUTH-3}
#
# The anchor is an explicit ID rather than a heading slug because a slug breaks
# silently on retitling: nothing fails, and the comment goes on reading as
# authoritative while pointing at nothing. An explicit ID can be checked, which
# is what this script does.
#
# Exit 0 when every link resolves, 1 when any does not, 2 on a usage error.
# Run at the review gate.
#
# Portability: macOS ships bash 3.2, which has no `mapfile` and no associative
# arrays. This script therefore uses plain files and newline-delimited strings
# where bash 4 would use an array or a hash. Do not "modernise" it without
# testing on /bin/bash.
#
set -euo pipefail

die() { printf 'error: %s\n' "$1" >&2; exit 2; }

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || die "not inside a git repository"
cd "$REPO_ROOT"

SINCE=""
LIST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="${2:-}"; shift 2 ;;
    --list)  LIST=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Which files to scan. Default to everything git tracks, so generated trees and
# dependencies are skipped without maintaining an exclude list. A --since diff
# can name deleted files, so keep only what still exists.
if [[ -n "$SINCE" ]]; then
  git diff --name-only "$SINCE"...HEAD -- . 2>/dev/null \
    | while IFS= read -r f; do [[ -f "$f" ]] && printf '%s\n' "$f"; done \
    > "$TMP/files" || true
else
  git ls-files > "$TMP/files"
fi

[[ -s "$TMP/files" ]] || { printf 'No files to check.\n'; exit 0; }

# Every `design:` reference, as "<file>:<line>:<rest>". grep -I skips binaries;
# the pattern requires a .md path on the line so a prose mention of the word
# "design:" is not treated as a link.
#
# xargs rather than "$(cat)" expansion: a large repo overflows ARGV, and the
# failure mode is a confusing "Argument list too long" rather than a wrong answer.
tr '\n' '\0' < "$TMP/files" \
  | xargs -0 grep -nI 'design:[[:space:]]*[^[:space:]]*\.\(md\|markdown\)' -- \
  > "$TMP/refs" 2>/dev/null || true

if [[ ! -s "$TMP/refs" ]]; then
  printf 'No `design:` comments found. Nothing to verify.\n'
  exit 0
fi

# Anchors declared by one document, newline-delimited, cached per document so a
# doc referenced fifty times is read once. bash 3.2 has no hash, so the cache is
# a file per document under $TMP/anchors/.
mkdir -p "$TMP/anchors"
anchors_for() {
  local doc="$1" key cache
  key="$(printf '%s' "$doc" | tr '/' '_')"
  cache="$TMP/anchors/$key"
  if [[ ! -f "$cache" ]]; then
    if [[ -f "$doc" ]]; then
      grep -oE '\{#[A-Za-z0-9][A-Za-z0-9_-]*\}' "$doc" 2>/dev/null \
        | sed -E 's/^\{#//; s/\}$//' > "$cache" || : > "$cache"
    else
      : > "$cache"
    fi
  fi
  cat "$cache"
}

total=0
broken=0
: > "$TMP/broken"
: > "$TMP/ok"

while IFS= read -r line; do
  # <file>:<lineno>:<rest>. The file path cannot contain a colon in git, so
  # cutting on the first two is safe.
  file="${line%%:*}"
  rest="${line#*:}"
  lineno="${rest%%:*}"
  rest="${rest#*:}"

  [[ -n "$file" && -n "$lineno" ]] || continue
  total=$((total + 1))

  doc="$(printf '%s' "$rest" \
    | sed -nE 's/.*design:[[:space:]]*([^[:space:]]+\.(md|markdown)).*/\1/p')"
  id="$(printf '%s' "$rest" \
    | sed -nE 's/.*\[([A-Za-z0-9][A-Za-z0-9_-]*)\].*/\1/p')"

  if [[ -z "$doc" ]]; then
    printf '%s:%s — no document path in the design: comment\n' \
      "$file" "$lineno" >> "$TMP/broken"
    broken=$((broken + 1)); continue
  fi
  if [[ -z "$id" ]]; then
    printf '%s:%s — no [ANCHOR-ID] in the design: comment (doc: %s)\n' \
      "$file" "$lineno" "$doc" >> "$TMP/broken"
    broken=$((broken + 1)); continue
  fi
  if [[ ! -f "$doc" ]]; then
    printf '%s:%s — no such document: %s\n' \
      "$file" "$lineno" "$doc" >> "$TMP/broken"
    broken=$((broken + 1)); continue
  fi
  if ! anchors_for "$doc" | grep -Fxq "$id"; then
    printf '%s:%s — %s has no anchor {#%s}\n' \
      "$file" "$lineno" "$doc" "$id" >> "$TMP/broken"
    broken=$((broken + 1)); continue
  fi

  printf '| `%s` | `%s` | %s:%s |\n' "$id" "$doc" "$file" "$lineno" >> "$TMP/ok"
done < "$TMP/refs"

if (( LIST )); then
  printf '| Anchor | Document | Referenced from |\n|---|---|---|\n'
  [[ -s "$TMP/ok" ]] && cat "$TMP/ok"
fi

if (( broken > 0 )); then
  printf '\n%d of %d `design:` link(s) do not resolve:\n\n' "$broken" "$total" >&2
  sed 's/^/  - /' "$TMP/broken" >&2
  printf '\nAn anchor is declared as `## Heading {#ID}` in the document.\n' >&2
  printf 'Anchors are never renumbered or reused — if a section was removed,\n' >&2
  printf 'repoint the comment rather than reviving the ID.\n' >&2
  exit 1
fi

printf '\nAll %d `design:` link(s) resolve.\n' "$total"
