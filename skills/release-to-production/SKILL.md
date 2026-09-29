---
name: release-to-production
description: Ship verified work to production by opening and merging a PR from the integration branch to the production branch. Use only after a human has moved the ticket to Done. Triggers on "release", "ship it", "deploy to production", "merge dev to main", "push to prod", "cut a release".
---

# Release to production

A human's verification is the authorisation. Nothing else is.

## 0a. The model for this phase

If `models.byPhase.release` names one and it differs from the session's, say so
per `references/models.md`. Release is mechanical but the consequences are
production, so this is not the phase to economise on.

## 0. Which promotion is this?

Read `project.columns`. Two shapes, and they gate differently.

**One integration environment** (`inReview` configured, no `readyForProd`).
One promotion: integration to production. The gate is the card reaching
`done` — a human ticked the checklist.

**PR per environment** (`pushedToStaging` and `readyForProd` configured). Two
promotions, and this skill handles both:

| Promotion | Carries | On merge |
|---|---|---|
| integration → staging | everything merged since the last one | each card to `pushedToStaging` |
| staging → production | **only** cards in `readyForProd` | each card to `done`, issue closed |

The second row is the point of the extra columns. **A human moves a card to
`readyForProd` after testing it on staging**, and a production PR carries only
those. A ticket nobody verified cannot ride along with somebody else's
release, which is what a single review column cannot prevent.

If some cards on staging are not in `readyForProd`, say which and stop. The
answer is usually "test them, or wait" — not "ship them anyway".

## 1. Verify the authorisation is real

```bash
ghboard status <issue>
```

It must report the `done` column. If it says In review, the human has not
finished verifying — **stop and say so**. Do not move it to Done yourself to
unblock the release; that defeats the only gate in the process a machine cannot
fake.

If the user asks to release something still in review, tell them what is
outstanding and let them decide. They may well say "yes, go" — that is their
call, and it should be made knowingly rather than by a tool quietly assuming.

## 1b. If it is an epic, every child must be closed

A parent with open sub-issues is not done, whatever its own column says.
GitHub tracks this, so check rather than trust:

```bash
gh api graphql -H "GraphQL-Features: sub_issues" \
  -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){
    issue(number:$n){subIssuesSummary{total completed}}}}' \
  -f o=<owner> -f r=<repo> -F n=<issue>
```

If `completed` is below `total`, stop and name the open children. Shipping a
parent whose children are unfinished is shipping a half-built feature with a
ticket that claims otherwise.

## 2. Read the ticket for late objections

```bash
ghboard read <issue>
```

A comment posted after the card reached Done — "actually this broke X", "hold
off until Friday" — is a reason to stop, not a formality. Done is a human's
verdict at a moment in time, and the comments are where it gets revised.

## 3. See exactly what would ship

```bash
git fetch origin
git log --oneline origin/<production>..origin/<integration>
gh pr list --base <production> --state merged --limit 5   # what went out last
```

A release often carries more than the ticket you are thinking about. List
**every** issue in the diff, not just the one that prompted this:

```bash
git log origin/<production>..origin/<integration> --format=%s%n%b \
  | grep -oE '#[0-9]+' | sort -u
```

Check each one's column. If something in that list is **not** in Done, say so.
Shipping an unverified change alongside a verified one is the most common way
unverified code reaches production, and it happens because nobody looked at the
full diff.

## 4. Confirm before opening

Show the human:

- the issues that would ship, and each one's column
- the commit count and rough shape of the diff
- anything in the list that is not Done, called out explicitly

Then ask. This is the last reversible moment.

## 5. Open and merge

```bash
gh pr create --base <production> --head <integration> \
  --title "Release: <summary>" \
  --body-file <path>

gh pr checks --watch
gh pr merge --merge          # a merge commit, not a squash
```

**Merge, do not squash.** The two branches must keep a shared history, or every
subsequent `production..integration` diff is wrong and the next release cannot
be read.

**This is the one place `Closes` is legitimate.** Feature PRs use `Refs` so
the board does not drop to Done before the work ships. A production promotion
is the moment the work is genuinely finished, so its body closes every ticket
it carries:

```
Closes #12
Closes #15
```

A promotion PR also carries a **Rollback** section — what to do if this turns
out badly, written before it is needed rather than during an incident.

## 6. Afterwards — batched across every ticket

The promotion carried several tickets, so every board move and comment happens
for each of them, not just the one that prompted the release.

**Integration → staging:** move each card to `pushedToStaging` and comment with
the promotion PR link. Then say plainly that these are **waiting on a human**:
somebody tests each on staging and moves it to `readyForProd`, and nothing
reaches production until they do.

**Staging → production:** move each card to `done`, comment "Released to
production" with the PR link, and close the issue.

Leave the cards in Done — Done means verified and shipped; there is no further
column, and inventing one would mean two places to look.

## What this skill will not do

- Move a card to Done on any promotion but the final one to production.
- Move a card to `readyForProd`. That is the human asserting they tested it on
  staging, and it is the gate the whole flow rests on.
- Release anything unverified without the human explicitly saying so after
  being shown exactly what is unverified.
- Squash the integration branch into production.
- Force-push either branch.
