---
name: verification-failed
description: Send a ticket back from In review to In progress when a human's manual check fails. Records which step failed and what was actually seen, labels the ticket, and moves the card back. Use when a tester reports a manual step did not pass, or when someone says a feature is broken on the integration branch. Triggers on "step 3 failed", "that didn't work", "it's broken on dev", "verification failed", "send it back", "didn't pass review", "reopen".
---

# Verification failed

A human tried the work and it did not do what the ticket promised. That is a
normal outcome, not an incident — the checklist exists precisely so this is
caught before production.

The card goes back. What must not happen is the card staying in In review while
the work quietly resumes, because then the board says a human is testing when
nobody is.

## 1. Get the specifics

Vague failure reports produce vague fixes. You need three things, and should
ask for any that are missing rather than guessing:

- **Which step.** By number, from the checklist on the ticket.
- **What was seen**, in the tester's own words. Not their theory about the
  cause — what appeared on screen.
- **What they expected**, if the step's wording turned out to be ambiguous.

> Step 4 says row 3's description should be blank after the PUT. What did you
> see instead — the old text still there, an error, or something else?

Ask for a screenshot when the failure is visual. One image settles what three
messages of description will not.

## 2. Decide what kind of failure it is

Three kinds, and they are handled differently. Getting this wrong wastes a
cycle.

**The code is wrong.** The ticket promised a behaviour, the behaviour is
absent. Normal case: back to In progress, fix with a red test first.

**The step is wrong.** The code does the right thing; the checklist describes
it badly, or expects something the ticket never promised. Do not change the
code. Fix the step's wording, and ask the tester to try again. A checklist that
fails on its own ambiguity trains people to skip it.

**The ticket is wrong.** The code does what the ticket said, and what the ticket
said turns out to be undesirable. This is a new ticket, not a fix — the
original did what it promised. Say so plainly and let the human decide whether
to raise the new one now or ship this and follow up.

Only the first kind is a genuine verification failure. Say which one you think
it is and why, before moving anything.

## 3. Record it on the ticket

The comment is the record of what happened. Quote the step verbatim so there is
no ambiguity about which one:

```bash
gh issue comment <n> --body "$(cat <<'EOF'
**Verification failed — step 4.**

> - [ ] On the UPDATE tab choose PUT, put 3 in the id box, type "replaced" in
>       name, leave description empty, send. In the table at the bottom, row 3's
>       description is now blank.

Observed: row 3's description still reads "original text" after the PUT.
Reported by @tester on the dev environment.

Back to In progress. The fix starts with a failing test that reproduces this.
EOF
)"
```

## 4. Label and move

```bash
gh issue edit <n> --add-label "<labels.verificationFailed>"   # default: verification-failed
ghboard move <n> inProgress
```

Create the label if it does not exist:

```bash
gh label create verification-failed \
  --description "A manual verification step failed; returned to In progress" \
  --color D93F0B
```

The label is what the router reads next session. Without it, a resumed branch
looks like ordinary in-progress work and the failure comment goes unread.

## 5. Hand back to the loop

Route to `red-green` with the failed step as the next behaviour. The rule that
matters:

**A bug a human found gets the same treatment as any other behaviour.** A red
test that reproduces the failure, watched failing, committed alone. Then the
fix.

It is tempting to skip the test because the fix is obvious and the tester is
waiting. That is exactly the change most likely to regress, because nothing
will ever check it again. The red commit is also the proof that you understood
the failure rather than changing code until the symptom went away.

If the failing behaviour was never on the ticket's test plan, add it — with its
acceptance criterion, if the criterion was missing too. A manual step that
failed is usually a behaviour that should have had an automated test in the
first place, and this is the moment to notice.

## 6. Going back to review

Normal `review-handoff`, with two additions:

- Remove the label: `gh issue edit <n> --remove-label verification-failed`
- Comment on the ticket saying what changed and which test now covers it, so
  the tester knows what to re-check and does not have to re-run the whole
  checklist blind.

## What this skill will not do

- Move the card to Done. A fixed failure still needs the human to re-verify.
- Fix the code without a failing test first.
- Change the acceptance criteria to match what the code does. If the criteria
  were wrong, that is a conversation, not an edit.
- Treat an ambiguous checklist step as a code defect.
