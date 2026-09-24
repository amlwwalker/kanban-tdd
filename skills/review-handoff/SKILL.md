---
name: review-handoff
description: Move an implemented feature to In review — run every suite and CI, verify the red→green evidence exists, publish the TDD test inventory, open and merge the PR to the integration branch, and append the numbered manual checklist to the ticket. Use when a feature is finished and green. Triggers on "ready for review", "hand this off", "move to in review", "open the PR", "this is done", "finished the feature".
---

# Review handoff

"In review" means a human can go and try it. That is a promise about the state
of the integration branch, not about your intentions — so the card moves last,
after the code is genuinely there.

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

The body carries: `Closes #<issue>`, one paragraph on what changed and why, the
test inventory table, and the red→green SHA pairs. Add a Mermaid diagram only
if the implementation diverged from the ticket's — otherwise link the ticket.

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

```bash
ghboard move <issue> inReview
```

Last, deliberately. The card now says something true: it is on the integration
branch and can be tried.

## 11. Tell the human what to do

One short message: the PR link, the issue link, and that the checklist is
waiting on the ticket. Do not paste the whole checklist into chat — it lives on
the card so it can be ticked.

Say explicitly how to report a failure, and that nothing polls:

> If a step fails, comment on the issue with the step number and what you saw,
> then tell me. Nothing polls GitHub, so I will not see the comment otherwise.

## What this skill will not do

- Move the card to Done. That is the human's verification, and it is what
  authorises a release.
- Merge with CI red or any suite failing.
- Write manual steps for a UI it has not seen running.
- Claim red→green evidence exists without checking the log.
