---
name: review-handoff
description: Move an implemented feature to In review — run every suite and CI, verify the red→green evidence exists, publish the TDD test inventory, open and merge the PR to the integration branch, and append the numbered manual checklist to the ticket. Use when a feature is finished and green. Triggers on "ready for review", "hand this off", "move to in review", "open the PR", "this is done", "finished the feature".
---

# Review handoff

"In review" means a human can go and try it. That is a promise about the state
of the integration branch, not about your intentions — so the card moves last,
after the code is genuinely there.

## 0. Preflight — always, and first

The cheapest step, and it catches the most expensive mistake: adding commits
to a branch whose PR already merged. They land on the branch, never reach the
base, the tests still pass, and the work looks done when it is not.

```bash
BRANCH="$(git branch --show-current)"
gh pr list --head "$BRANCH" --state all --json number,state,mergedAt,baseRefName,url
```

| Result | Meaning | Do |
|---|---|---|
| `[]` | No PR yet | Continue. This will be a new one. |
| `OPEN` | Live PR | Continue. Pushing updates it. Do not open a second. |
| `MERGED` | **Already shipped** | **STOP.** Recovery below. |
| `CLOSED` | Rejected or abandoned | **STOP.** Ask whether to reopen or start fresh. |

Also refuse to work directly on a protected branch — the integration or
production branch from the config, or anything the remote protects.

### Recovery when the PR already merged

Find what is genuinely unshipped:

```bash
git fetch origin <integration>
git log origin/<integration>..HEAD --oneline
```

**Nothing listed** — the branch is fully merged and there is no new work.
Start a new branch from the integration branch for whatever comes next.

**Commits listed** — that work is stranded and needs a new branch and a new
PR:

```bash
git fetch origin <integration>
git checkout -b <new-branch> origin/<integration>
git cherry-pick <the stranded commits>
```

Tell the user plainly before doing any of it: which PR already merged, which
commits are stranded, and that a second PR is needed. The new PR references
the **same ticket**. Two PRs against one ticket is fine and honest; quietly
pushing to a merged branch is not.

## 1. Read the ticket first

```bash
ghboard read <n>
ghboard comments <n> --after-commit
```

Something may have changed while you were building. Handing off work that no
longer matches the ticket wastes the reviewer's time and yours.

## 2. Refuse unless it is actually green

Run the real commands from `.claude/workflow.config.json` — every suite in
`tests`, plus `integrationCommand` where the change touched storage, plus
`lintCommand`. If `ciCommand` is set, prefer it: it is what actually gates the
merge.

If anything is red, stop. Do not open a PR "for early feedback" on a red branch
— a reviewer cannot tell a known failure from a new one, so the review is
worthless and their time is spent anyway.

## 3. Check the red→green evidence exists

```bash
git log --oneline "$(git merge-base HEAD origin/<integration>)"..HEAD
```

You are looking for `test(red):` commits paired with `feat(green):` ones. Spot
check one:

```bash
git show --stat <red-sha>     # test files only, no production code
```

If every test arrived in the same commit as its implementation, TDD did not
happen. **Say so plainly** rather than writing a handoff that implies it did —
the point of the evidence is that it can be checked, which means it can also be
absent. It is recoverable; a false audit trail is not.

## 4. Check every acceptance criterion is covered

Go down the ticket's criteria. Each one should have a test that now passes, or
a manual step in the checklist you are about to write. A criterion with
neither is the thing that gets ticked at review because it sounds true.

Name any gaps before opening the PR.

## 5. Build the test inventory

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/review-handoff/scripts/test-inventory.sh" \
  --since "$(git merge-base HEAD origin/<integration>)"
```

Emits a markdown table: test name, one-line description, permalink. If it
reports tests missing their description, **add the descriptions** — one `//`
line directly above `func TestX` for Go, a clear `it()` string elsewhere. Do
not hand a reviewer a table with blanks in it.

## 6. Optional: review the branch first

If `code-review` resolves to a provider, run it before opening the PR. Findings
are cheaper to act on before a reviewer reads the diff. Resolve per
`references/capabilities.md`.

## 7. Open the PR to the integration branch

```bash
gh pr create --base <integration> --head "$(git branch --show-current)" \
  --title "<same summary as the ticket>" \
  --body-file <path>
```

**Reference the ticket as `Refs #<issue>`, not `Closes`, whenever the board has
a column after this one.** `Closes` auto-closes the issue when the PR merges,
which drops the card to Done before the work has reached production — and Done
is what authorises a release. Only the final promotion to production uses
`Closes`, and that belongs to `release-to-production`.

On a two-column flow where merging to the integration branch *is* the last
step before verification, `Closes` is still wrong for the same reason: the
human has not tried it yet.

The body carries: `Refs #<issue>`, one paragraph on what changed and why, and
both of these sections, always:

```markdown
## Automated tests

<which test files were added or extended, what they assert, and the suite
 result — e.g. `npm test` -> 17 passed. Name any pre-existing failures so they
 are not attributed to this PR.>

## Manual acceptance checklist

- [ ] <one concrete action, one expected outcome>
- [ ] <the bug's original repro case, for a fix>
- [ ] <anything nearby this change could have regressed>
```

**Refuse to open the PR if the manual checklist is empty or generic.** It is
the acceptance gate. "Test the feature works" is not a checklist item, and if
you cannot write concrete ones you do not understand the change well enough to
ship it.

When the config marks build config or setup scripts as security-sensitive and
this branch touched any, **call that out on its own line in the PR body** so a
reviewer cannot miss it.

Add a Mermaid diagram only if the implementation diverged from the ticket's —
otherwise link the ticket.

## 8. Wait for CI, then merge

```bash
gh pr checks --watch
gh pr merge --squash --delete-branch
```

Squashing the PR is fine — the red/green pair survives in the PR's own commit
list, which is where a reviewer looks. What must not happen is squashing them
together *before* the PR exists.

If CI fails, fix it on the branch. Do not move the card.

## 9. Append the manual checklist to the ticket

Use `manual-test-design` to write the steps, **numbered**, each tied to an
acceptance criterion. Then:

```bash
gh issue edit <issue> --body-file <path-with-checklist-appended>
```

It goes on the **issue**, not only the PR, because the issue is the board card
— the person verifying is looking at the card, and checkboxes there survive the
PR being merged and forgotten.

If the relevant `environments.*.url` is null, say the URL is unknown rather
than writing "open dev" and leaving the reader to guess.

If this ticket came back from a failed verification, also:

```bash
gh issue edit <issue> --remove-label verification-failed
```

and comment saying what changed and which test now covers it, so the tester
knows what to re-check rather than re-running the whole checklist blind.

## 10. Now move the card

Which column depends on the flow the config describes:

```bash
ghboard move <issue> inReview        # one integration environment
ghboard move <issue> pushedToDev     # PR-per-environment flow
```

Use `pushedToDev` when it is configured, `inReview` otherwise. On the
PR-per-environment flow this card is **not** finished review — it has reached
the first environment, and `release-to-production` carries it onward.

Last, deliberately. The card now says something true: it is on the integration
branch and can be tried.

## 11. Tell the human what to do

One short message: the PR link, the issue link, and that the checklist is
waiting on the ticket. Do not paste the whole checklist into chat — it lives on
the card so it can be ticked.

**Link straight to the checklist, and never say "the checklist above".** The
steps live in the issue body while your handoff is a separate message, so
"above" points at nothing and the reader counts steps in the wrong place. Use
the anchor:

```
https://github.com/<repo>/issues/<n>#user-content-manual-verification-checklist
```

Say explicitly how to report a failure, and that nothing polls:

> Checklist is on the ticket: <link>. If a step fails, comment on the issue
> with the **step number** and what you saw, then tell me. Nothing polls
> GitHub, so I will not see the comment otherwise.

Asking for the number matters: `verification-failed` quotes the step back
verbatim to confirm it is looking at the right one, and a mismatch between the
number reported and the step described is the signal that something was
misread rather than genuinely broken.

## What this skill will not do

- Move the card to Done. That is the human's verification, and it is what
  authorises a release.
- Merge with CI red or any suite failing.
- Write manual steps for a UI it has not seen running.
- Claim red→green evidence exists without checking the log.
