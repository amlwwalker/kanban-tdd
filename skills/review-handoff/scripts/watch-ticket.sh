#!/usr/bin/env bash
#
# watch-ticket.sh — emit one line per new comment or column move on one ticket.
#
#   ./watch-ticket.sh 7                 watch until the card reaches a terminal column
#   ./watch-ticket.sh 7 --interval 30   poll faster (60s is GitHub's own advice)
#   ./watch-ticket.sh 7 --once          one pass, for testing
#
# Driven by the Monitor tool: every stdout line becomes a notification, and the
# script exits when the ticket reaches a terminal column so the watch ends on
# its own rather than idling until timeout.
#
# WHY NOT A WEBHOOK. A webhook needs a public HTTPS endpoint that is listening
# when GitHub fires, and it needs admin on the repo to create. Neither is true
# of a laptop running a plugin. A webhook would also still need somewhere to
# park the event until a session exists to read it — so it moves the problem
# rather than solving it.
#
# WHAT THIS USES INSTEAD. GitHub's notifications API is fed by the same event
# system webhooks fire from, needs no server, and catches up on anything that
# happened while nothing was watching. GitHub ships an `X-Poll-Interval: 60`
# header sanctioning a 60s poll, which is where the default comes from.
#
# Notifications only arrive for threads you are subscribed to, so the script
# also polls the issue's comments directly with `since` — being the author is
# usually enough, but a ticket someone else opened may not notify you at all.
# The two are deduplicated by comment id.
#
# COLUMN MOVES ARE NOT NOTIFIED. Projects v2 has no change feed and the issue
# timeline does not carry field changes, so a manual card drag fires nothing
# anywhere. The column is fetched and compared against the last value. One
# project call per poll.
#
# WHAT IT CANNOT DO: this runs only while a session is open. Nothing here is a
# standing service — close the session and the watch dies with it. Say that to
# the user rather than letting them assume a later comment will be picked up.
#
# Portability: macOS ships bash 3.2 — no mapfile, no associative arrays.
#
set -uo pipefail       # NOT -e: a failed poll must not kill the watch

die() { printf 'error: %s\n' "$1" >&2; exit 2; }

command -v gh >/dev/null 2>&1 || die "gh is not installed."
command -v jq >/dev/null 2>&1 || die "jq is not installed."

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || die "not inside a git repository"
cd "$REPO_ROOT"

ISSUE="${1:-}"
[[ -n "$ISSUE" ]] || die "usage: watch-ticket.sh <issue> [--interval N] [--once]"
case "$ISSUE" in *[!0-9]*) die "issue must be a number, got: $ISSUE" ;; esac
shift

INTERVAL=60
ONCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval) INTERVAL="${2:-60}"; shift 2 ;;
    --once)     ONCE=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" \
  || die "could not resolve the repo from gh"

# ghboard, for the column. Prefer the shim; fall back to the plugin copy.
GHBOARD=""
if [[ -x .claude/bin/ghboard ]]; then
  GHBOARD=".claude/bin/ghboard"
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -x "$CLAUDE_PLUGIN_ROOT/skills/feature-workflow/scripts/ghboard" ]]; then
  GHBOARD="$CLAUDE_PLUGIN_ROOT/skills/feature-workflow/scripts/ghboard"
fi

CFG=".claude/workflow.config.json"
DONE_COL="$(jq -r '.project.columns.done // "Done"' "$CFG" 2>/dev/null)"
BACK_COL="$(jq -r '.project.columns.inProgress // "In progress"' "$CFG" 2>/dev/null)"

SEEN="$(mktemp)"            # comment ids already emitted
trap 'rm -f "$SEEN"' EXIT

# Start from now, so a backlog of old comments is not replayed as new events.
SINCE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LAST_COL=""
[[ -n "$GHBOARD" ]] && LAST_COL="$($GHBOARD status "$ISSUE" 2>/dev/null | head -1)"

printf 'watching #%s (%s) — comments and column moves, every %ss\n' \
  "$ISSUE" "${LAST_COL:-column unknown}" "$INTERVAL"

while :; do
  NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # New comments on this issue. `since` means each poll returns only what is
  # new; `|| true` so a network blip is a skipped poll, not a dead watch.
  # Emit by id and record it, so the notifications pass cannot double-report.
  while IFS=$'\t' read -r id who body; do
    [[ -n "${id:-}" ]] || continue
    grep -qx "$id" "$SEEN" 2>/dev/null && continue
    printf '%s\n' "$id" >> "$SEEN"
    printf 'comment on #%s from %s: %s\n' "$ISSUE" "$who" "$body"
  done < <(
    gh api "repos/$SLUG/issues/$ISSUE/comments?since=$SINCE&per_page=20" 2>/dev/null \
      | jq -r '.[]? | [.id, .user.login, (.body | gsub("\\s+"; " ") | .[0:220])] | @tsv' \
      2>/dev/null || true
  )

  # The notifications API catches threads the direct poll can miss — a review
  # comment, or activity on a thread you are subscribed to but did not author.
  gh api "notifications?since=$SINCE&per_page=30" 2>/dev/null \
    | jq -r --arg repo "$SLUG" --arg n "#$ISSUE" '
        .[]? | select(.repository.full_name == $repo)
             | select(.reason == "comment" or .reason == "mention"
                      or .reason == "state_change" or .reason == "review_requested")
             | select((.subject.url // "") | endswith("/" + ($n | ltrimstr("#"))))
             | "\(.reason) on \($n): \(.subject.title)"' \
    2>/dev/null || true

  SINCE="$NOW"

  # Column. No event source exists for this, so compare against last seen.
  if [[ -n "$GHBOARD" ]]; then
    COL="$($GHBOARD status "$ISSUE" 2>/dev/null | head -1)"
    if [[ -n "$COL" && -n "$LAST_COL" && "$COL" != "$LAST_COL" ]]; then
      printf '#%s moved: %s -> %s\n' "$ISSUE" "$LAST_COL" "$COL"
    fi
    [[ -n "$COL" ]] && LAST_COL="$COL"

    # Exit on a terminal column so the watch ends itself. An unbounded monitor
    # stays armed until timeout even after the event it was waiting for.
    if [[ "$COL" == "$DONE_COL" ]]; then
      printf '#%s is in %s — watch ending. Release is the next step.\n' "$ISSUE" "$COL"
      exit 0
    fi
    if [[ "$COL" == "$BACK_COL" ]]; then
      printf '#%s sent back to %s — watch ending. Read the failure comment.\n' "$ISSUE" "$COL"
      exit 0
    fi
  fi

  (( ONCE )) && exit 0
  sleep "$INTERVAL"
done
