---
name: triage
description: Sweep the tracker for tickets that are missing a type, a service, a board entry or a priority, and fix them one at a time with the user. Use when the backlog has stopped being filterable, after bulk-importing issues, or as a periodic tidy. Triggers on "triage", "sweep the backlog", "what's unlabelled", "tidy the board", "which tickets are missing labels".
---

# Triage

Finds tickets the classification missed and fixes them. The gap this closes is
structural rather than careless: **issue forms only apply in the web UI.**
`gh issue create` and the REST API bypass them entirely, which is exactly how
an agent files a ticket. Without a sweep, every agent-filed ticket drifts out
of the taxonomy and the backlog slowly stops answering questions.

Requires a `taxonomy` block in the config. Without one there is nothing to
check against, so say so and stop.

## 1. Find the gaps

Four checks, in the order they matter. Report counts first, so the size of the
problem is clear before any detail:

```bash
# Not on the board at all — invisible to every other skill
gh issue list --repo <repo> --state open --limit 200 \
  --json number,title,labels,projectItems \
  | jq -r '.[] | select(.projectItems | length == 0) | "\(.number)\t\(.title)"'

# On the board, but carrying no type label
gh issue list --repo <repo> --state open --limit 200 --json number,title,labels \
  | jq -r --argjson types '["type:bug","type:feature"]' \
      '.[] | select([.labels[].name] - $types | length == [.labels[].name] | length)
       | "\(.number)\t\(.title)"'
```

Build the type and service label lists from `taxonomy`, not from a hardcoded
set. A type whose configured label is `null` cannot be checked this way — look
for the `[type]` title prefix instead, and say that those are unverifiable if
the prefix is off.

Also check: no service label and no `[service]` title prefix; no priority when
`priority` is configured and the board has the field.

## 2. Report before fixing

A wall of 40 tickets does not get read. Lead with counts, then the first few:

> 62 open tickets. 14 need something:
>
> - **3 not on the board at all** — #88, #91, #104. Nothing else can see these.
> - **9 with no type** — the largest group, and the one that makes the backlog
>   unfilterable.
> - **2 with no service** — #77, #83.
>
> Start with the 3 that are off the board? Those are invisible to every other
> skill, so they are worth more than the other 11 combined.

Order by consequence, not by count. A ticket off the board is worse than one
missing an area label.

## 3. Fix one at a time

**Never bulk-apply a type.** The type decision tree in `ticket-authoring`
needs the ticket's content, and a wrong type applied in bulk to 40 tickets is
worse than no type at all — it looks decided.

For each, read it and propose:

```bash
ghboard read <n>
```

> **#91** "Player stalls on 4K streams over slow connections"
> Proposing `type:bug`, service `player`, priority P1 — a core flow is broken
> for a whole class of user and the issue names no workaround. Yes, or correct
> me?

Apply on confirmation. Where a label does not exist, put the dimension in the
title rather than creating one:

```bash
gh issue edit <n> --add-label "<label>"
gh issue edit <n> --title "[service][type] <existing title>"
ghboard add <n> && ghboard move <n> backlog
```

**Never run `gh label create` during a sweep.** A missing label is a decision
for the team, not a side effect of tidying. Collect the missing ones and
report them at the end.

## 4. Offer to stop

After five or six, ask whether to continue. Triage is tedious and a half-done
sweep that the user chose to stop is better than a full one they disengaged
from halfway through and stopped checking.

## 5. Report what is left

Say what was fixed, what was skipped and why, and which labels are missing
from the tracker entirely:

> Fixed 6. Skipped #104 — it is a duplicate of #88 and wants closing rather
> than labelling, which is your call.
>
> Two configured labels do not exist on the tracker: `type:task` and
> `type:security`. Until they do, those tickets carry the type in the title
> only, which does not filter. Worth creating them.

## Ideas and stale tickets

Two judgements worth making while you are already reading every ticket:

**A ticket that is really an idea** — nobody committed to it — should be typed
`idea` and left unprioritised. Prioritising uncommitted work is how a backlog
fills with things that look scheduled.

**A ticket old enough that its reason may have gone** is worth raising rather
than labelling. `ghboard stale` finds these structurally; triage is where a
human decides. Offer to close, do not close.

## What this skill will not do

- Apply a type in bulk without reading each ticket.
- Create a label.
- Close anything. It proposes, the human decides.
- Change a priority a human set. An absent priority gets one; a considered one
  is left alone, even when you would have chosen differently.
