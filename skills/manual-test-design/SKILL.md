---
name: manual-test-design
description: Decide which behaviours genuinely cannot be covered by an automated test, and write the layman's manual steps for those. Use when planning a ticket's test coverage, or when preparing the human verification checklist for review. Triggers on "manual test", "how do we test this", "can this be automated", "verification checklist", "QA steps", "acceptance steps".
---

# Manual test design

Two jobs: decide what genuinely needs a human, and write steps a human can
actually follow.

The principle behind both: **"can't be automated" is never the same as
"untested".** If a behaviour can only be confirmed by a person in a browser, it
still gets a written test — a plain-language step, as a checkbox on the ticket.

## What needs a human

Short list. Treat it as closed — if a behaviour is not on it, the automated
test exists and has not been thought of yet.

- **Visual judgement.** Does the layout hold at this width, does the hierarchy
  read, does it look right. (Note: *rule* conformance is automatable — "no
  border radius anywhere", "page title is 28px" are assertions, not opinions.)
- **Real-browser behaviour that a test double replaces.** Cross-origin
  preflights, cookie flags, redirects to third parties, clipboard, file
  pickers, notification permission.
- **Something outside the system.** A payment provider's sandbox, an email
  actually arriving, an OAuth consent screen.
- **Feel.** Is the loading state long enough to notice, does the error message
  make sense to someone who does not know the code.

## What does not

Be sceptical of these, they are the common excuses:

| "Needs a human because…" | Actually |
|---|---|
| it involves the database | integration test against a real database |
| it's a UI interaction | Testing Library — click it and assert |
| it's about CORS | assert the preflight response headers directly |
| there are lots of combinations | table-driven test |
| it's hard to set up | that difficulty is the design telling you something |

A behaviour that ends up manual because it is *hard* to automate is a cost you
pay on every release, forever. Say so out loud before accepting it.

## Writing the steps

For someone who has never seen the code. No selectors, no jargon, no internal
names.

**One observable outcome per step.** If a step has two assertions, it is two
steps — otherwise a half-pass has nowhere to go.

**Number them.** A tester reporting a failure says "step 4 failed", and
`verification-failed` quotes the step back. Unnumbered steps make that
conversation ambiguous.

**Say where to start.** "Open <dev url>, go to the UPDATE tab." Not "navigate
to the update panel". If the relevant `environments.*.url` is null in the
config, say the URL is unknown rather than writing "open dev" and hoping.

**Say what to look at, and what it should be.** The reader should not need
judgement about whether it passed.

Good:

```
- [ ] **4.** On the UPDATE tab choose PUT, put 3 in the id box, type "replaced"
      in name, leave description empty, send. In the table at the bottom, row
      3's description is now blank.
```

Bad:

```
- [ ] Verify PUT semantics work correctly
```

The second one cannot fail — anyone can convince themselves it passed.

**Include the negative where it is the point.** If the interesting behaviour is
that something *doesn't* happen, say what would be wrong:

```
- [ ] **5.** Repeat on the PATCH tab with only "name" ticked. Row 1's
      description is unchanged. (If it goes blank, PATCH is behaving like PUT —
      that's the bug this ticket fixes.)
```

**Tie each step to an acceptance criterion.** The checklist proves the ticket,
so a step that proves nothing on the list is a step someone invented, and a
criterion with no step is a criterion nobody will check.

## Where they go

- **At ticket time**: named in the TDD test plan as `[manual]` lines with their
  criterion and a justification. No steps yet — the UI does not exist, so any
  steps would be for an imagined one.
- **At review time**: written out in full as numbered GitHub checkboxes,
  appended to the issue body by `review-handoff`, so the person verifying ticks
  them on the card itself.

## When a step fails

The tester reports which number and what they saw. That goes to
`verification-failed`, which decides whether the code is wrong, the step is
wrong, or the ticket was wrong — and only the first sends the card back.

A step that fails because it was ambiguously worded is a defect in the
checklist, not the code. Fix the wording; a checklist that cries wolf trains
people to skip it.
