#!/usr/bin/env bash
#
# publish-screenshots.sh — put screenshots where a GitHub comment can show them.
#
#   ./publish-screenshots.sh 153                     every 153-*.png
#   ./publish-screenshots.sh 153 --dir checkout      a flow subdirectory
#   ./publish-screenshots.sh 153 --dry-run           print the markdown, push nothing
#
# Prints markdown ready to paste or pipe into a comment.
#
# WHY THIS EXISTS: GitHub has no API for attaching an image to an issue or PR
# comment. The drag-and-drop uploader is web-UI only. So the images go on an
# orphan branch as real blobs and get embedded by raw URL, pinned to the commit.
#
# If you have a browser open, dragging the PNG into the comment box is faster and
# this script is unnecessary. It exists for automation and for anyone working
# over SSH.
#
# Four details, each learned the hard way:
#
#   1. .jpg, not .png. A PNG has been observed rendering as a broken-image icon
#      in a comment with the blob present at that commit and the markdown
#      identical. Nobody has a tidy explanation. jpg works.
#   2. Pin the commit SHA, never the branch name, so a link cannot change
#      meaning when the branch moves.
#   3. curl cannot verify the result on a private repo. Both working and broken
#      images return 404 to an authenticated curl, because a PAT is not a
#      browser session. This script therefore ends by telling a human to look.
#   4. Never use the contents API's download_url in a comment. It carries a
#      short-lived ?token= that expires, so the image works today and breaks
#      next week.
#
# Portability: macOS ships bash 3.2 — no mapfile, no associative arrays. Keep it
# that way.
#
set -euo pipefail

die() { printf 'error: %s\n' "$1" >&2; exit 2; }

command -v gh >/dev/null 2>&1 || die "gh is not installed."
command -v jq >/dev/null 2>&1 || die "jq is not installed."

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || die "not inside a git repository"
CONFIG="${WORKFLOW_CONFIG:-$REPO_ROOT/.claude/workflow.config.json}"
cd "$REPO_ROOT"

TICKET="${1:-}"
[[ -n "$TICKET" ]] || die "usage: publish-screenshots.sh <ticket-number> [--dir <subdir>] [--dry-run]"
shift

SUBDIR=""
DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)     SUBDIR="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -f "$CONFIG" ]] || die "no config at $CONFIG
    Run /board-setup, then /browser-setup."

SHOTDIR="$(jq -r '.browser.screenshotDir // empty' "$CONFIG")"
FORMAT="$(jq -r '.browser.imageFormat // "jpg"' "$CONFIG")"

# NOT `// "assets"`: jq's alternative operator treats an explicit JSON null the
# same as a missing key, so `"assetsBranch": null` — a team deliberately opting
# out of publishing — would silently become "assets" and push anyway. Distinguish
# the three cases by hand.
BRANCH="$(jq -r '
  if has("browser") | not then "assets"
  elif .browser | has("assetsBranch") | not then "assets"
  elif .browser.assetsBranch == null then "__DISABLED__"
  else .browser.assetsBranch end' "$CONFIG")"

[[ -n "$SHOTDIR" ]] || die "no .browser.screenshotDir in the config. Run /browser-setup."
if [[ "$BRANCH" == "__DISABLED__" || -z "$BRANCH" ]]; then
  die "assetsBranch is null — publishing is disabled for this repo.
    Drag the images into the comment box instead; they are in $SHOTDIR."
fi

SRC="$SHOTDIR${SUBDIR:+/$SUBDIR}"
[[ -d "$SRC" ]] || die "no such directory: $SRC
    Run the browser suite first."

# The remote is needed to build URLs and to push. A dry run only formats
# markdown, so it must not require one — that is exactly when someone is
# checking the naming before wiring anything up.
#
# This lookup comes AFTER the assetsBranch check above: a repo that has
# deliberately disabled publishing must get the "drag them in" advice, not a
# confusing complaint about a remote it was never going to use.
SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
if [[ -z "$SLUG" ]]; then
  (( DRY )) || die "could not determine the repo from gh. Is a remote configured?"
  SLUG="OWNER/REPO"
fi

# Collect this ticket's images. Numeric-prefixed flow files (01-, 02-) are taken
# whole from a --dir, since their prefix is the sort order, not a ticket number.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/list"

if [[ -n "$SUBDIR" ]]; then
  find "$SRC" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' \) \
    | sort >> "$TMP/list"
else
  find "$SRC" -maxdepth 1 -type f \
    \( -name "${TICKET}-*.png"  -o -name "${TICKET}-*.jpg" \
    -o -name "${TICKET}[a-z]-*.png" -o -name "${TICKET}[a-z]-*.jpg" \) \
    | sort >> "$TMP/list"
fi

COUNT="$(wc -l < "$TMP/list" | tr -d ' ')"
if [[ "$COUNT" -eq 0 ]]; then
  die "no images for #$TICKET in $SRC
    Expected ${TICKET}-<state>.png — see the naming convention in browser-evidence."
fi

printf 'Found %s image(s) for #%s in %s\n' "$COUNT" "$TICKET" "$SRC" >&2

# Convert to the publish format. sips on macOS, ImageMagick elsewhere; if neither
# is available and the source is already the target format, pass it through.
convert_to_format() {
  local src="$1" out="$2"
  case "$src" in
    *."$FORMAT") cp "$src" "$out"; return 0 ;;
  esac
  if command -v sips >/dev/null 2>&1; then
    sips -s format "$([[ "$FORMAT" == jpg ]] && echo jpeg || echo "$FORMAT")" \
      -s formatOptions 85 "$src" --out "$out" >/dev/null 2>&1 && return 0
  fi
  if command -v magick >/dev/null 2>&1; then
    magick "$src" -quality 85 "$out" && return 0
  elif command -v convert >/dev/null 2>&1; then
    convert "$src" -quality 85 "$out" && return 0
  fi
  printf 'warning: cannot convert %s to %s (no sips or ImageMagick).\n' \
    "$src" "$FORMAT" >&2
  printf '         Publishing as-is. A PNG may render as a broken icon.\n' >&2
  cp "$src" "$out"
}

mkdir -p "$TMP/out"
: > "$TMP/names"
while IFS= read -r f; do
  base="$(basename "$f")"
  stem="${base%.*}"
  out="$TMP/out/${stem}.${FORMAT}"
  convert_to_format "$f" "$out"
  printf '%s\n' "${stem}.${FORMAT}" >> "$TMP/names"
done < "$TMP/list"

if (( DRY )); then
  printf '\n--- dry run, nothing pushed ---\n\n'
  printf '### Screenshots\n\n'
  while IFS= read -r n; do
    printf '**%s**\n\n![%s](https://github.com/%s/raw/<SHA>/%s)\n\n' \
      "${n%.*}" "${n%.*}" "$SLUG" "$n"
  done < "$TMP/names"
  exit 0
fi

# One blob per image.
: > "$TMP/tree.json"
printf '{"tree":[' >> "$TMP/tree.json"
first=1
while IFS= read -r n; do
  blob="$(gh api "repos/$SLUG/git/blobs" \
    -f content="$(base64 < "$TMP/out/$n" | tr -d '\n')" \
    -f encoding=base64 --jq .sha)" \
    || die "failed to create a blob for $n"
  (( first )) || printf ',' >> "$TMP/tree.json"
  first=0
  printf '{"path":"%s","mode":"100644","type":"blob","sha":"%s"}' \
    "$n" "$blob" >> "$TMP/tree.json"
  printf '  uploaded %s\n' "$n" >&2
done < "$TMP/names"
printf ']}' >> "$TMP/tree.json"

TREE="$(gh api "repos/$SLUG/git/trees" --input "$TMP/tree.json" --jq .sha)" \
  || die "failed to create the tree"

# The orphan branch may not exist yet. With a parent, the commit chains; without,
# it starts the branch. Keep it orphaned and code-free.
PARENT="$(gh api "repos/$SLUG/git/ref/heads/$BRANCH" --jq .object.sha 2>/dev/null || true)"

if [[ -n "$PARENT" ]]; then
  COMMIT="$(gh api "repos/$SLUG/git/commits" \
    -f message="screenshots for #$TICKET" -f tree="$TREE" \
    -f "parents[]=$PARENT" --jq .sha)" || die "failed to create the commit"
  gh api -X PATCH "repos/$SLUG/git/refs/heads/$BRANCH" \
    -f sha="$COMMIT" >/dev/null || die "failed to move refs/heads/$BRANCH"
else
  COMMIT="$(gh api "repos/$SLUG/git/commits" \
    -f message="screenshots for #$TICKET" -f tree="$TREE" --jq .sha)" \
    || die "failed to create the commit"
  gh api "repos/$SLUG/git/refs" \
    -f ref="refs/heads/$BRANCH" -f sha="$COMMIT" >/dev/null \
    || die "failed to create refs/heads/$BRANCH"
  printf '  created orphan branch %s\n' "$BRANCH" >&2
fi

# The markdown. SHA-pinned, so the link cannot change meaning later.
printf '### Screenshots\n\n'
while IFS= read -r n; do
  printf '**%s**\n\n![%s](https://github.com/%s/raw/%s/%s)\n\n' \
    "${n%.*}" "${n%.*}" "$SLUG" "$COMMIT" "$n"
done < "$TMP/names"

cat >&2 <<EOF

Published $COUNT image(s) to $BRANCH at $COMMIT.

  A HUMAN MUST CONFIRM THESE RENDER. curl cannot check it: on a private repo
  both a working and a broken image return 404 to an authenticated request,
  because a token is not a browser session. A body_html check only proves the
  markdown parsed, never that the image loads.

  Post the markdown above, open the ticket, and look.
EOF
