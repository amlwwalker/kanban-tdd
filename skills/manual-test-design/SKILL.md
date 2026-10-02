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

And the corollary, which is where this skill has got stricter: **"needs a human
to look at it" is not the same as "needs a human to drive a browser".** Most
visual verification needs the first and not the second, and a browser capture
turns four minutes of resizing a window into four seconds looking at an image —
repeatable on every release instead of whenever someone remembers.

## Drive, or look?

The question people ask is "can this be automated", and it conflates two things
that come apart. Separate them first:

- **Does it need a human to DRIVE?** Someone clicking, typing, waiting.
- **Does it need a human to LOOK?** Someone exercising judgement on a result.

"Does the layout hold at 390px" needs a human to *look*. It does not need one to
*drive* — a browser suite sets the viewport, loads the page and photographs it,
and then a person spends four seconds on an image instead of four minutes
resizing a window. That is the same verification at a fraction of the cost, and
it is repeatable on every release rather than whenever someone remembers.

So the list below is **what needs a human to drive**. It is shorter than it used
to be, and `browser-evidence` is why.

## What needs a human to drive

Treat it as closed. If a behaviour is not on it, either an automated test exists
and has not been thought of, or a browser capture can photograph it.

- **Something outside the system.** A payment provider's sandbox, an email
  actually arriving, an OAuth consent screen on a third-party domain.
- **A native browser dialog the page does not own.** The file picker, the print
  dialog, the notification-permission prompt, OS-level clipboard permission.
- **Hardware.** A camera, a scanner, a card reader, a real mobile device where
  an emulated viewport is not the point.
- **Feel, in motion.** Is the loading state long enough to notice, does the
  transition feel wrong. A still image cannot settle this; a person using it can.

## What a browser capture covers instead

These were on the manual list and should not be. The human still looks — they
just look at an image instead of driving a browser:

| Behaviour | How it is captured |
|---|---|
| Does the layout hold at this width | Viewport matrix: every state at each configured width |
| Does the hierarchy read, does it look right | The same screenshots, reviewed on the ticket |
| Error and empty states | Route interception — force the 500, photograph the toast |
| Does the error message make sense | Capture it and let a reader judge the wording |
| A redesign looked better before | Before/after via an env switch, side by side |
| Real-browser behaviour a test double replaces | A real browser, which is what this is |

Rule conformance was always automatable and still is: "no border radius
anywhere", "the page title is 28px" are assertions, not opinions.

## What does not need a human at all

Be sceptical of these, they are the common excuses:

| "Needs a human because…" | Actually |
|---|---|
| it involves the database | integration test against a real database |
| it's a UI interaction | Testing Library — click it and assert |
| it's about CORS | assert the preflight response headers directly |
| there are lots of combinations | table-driven test |
| it's visual | a browser capture, reviewed as an image |
| it's an error state | route interception, then photograph it |
| it's hard to set up | that difficulty is the design telling you something |

A behaviour that ends up manual because it is *hard* to automate is a cost you
pay on every release, forever. Say so out loud before accepting it.

**Where the config has no `browser` block**, the middle table above is not
available and those behaviours go back to being manual steps. Say that is why,
rather than silently writing a longer checklist — it is the clearest argument for
running `/browser-setup` that the workflow can make.

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

A behaviour covered by a browser capture is **not** a `[manual]` line. Tag it
`[browser]` instead, so the test plan distinguishes the three kinds of coverage:
automated assertion, automated capture reviewed by a human, and a human driving.

Where screenshots exist for a ticket, say so at the top of the checklist and link
them. A tester who has already seen the error state photographed does not need a
step telling them to reproduce it — and a checklist that asks for work already
done is a checklist people start skimming.

## When a step fails

The tester reports which number and what they saw. That goes to
`verification-failed`, which decides whether the code is wrong, the step is
wrong, or the ticket was wrong — and only the first sends the card back.

A step that fails because it was ambiguously worded is a defect in the
checklist, not the code. Fix the wording; a checklist that cries wolf trains
people to skip it.
