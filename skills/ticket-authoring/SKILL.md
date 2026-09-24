---
name: ticket-authoring
description: Turn a feature idea into a GitHub issue on the project board, in two stages — the user story agreed first, then the technical design, acceptance criteria and TDD test plan derived from it. Use after requirements gathering, before any code is written. Triggers on "write the ticket", "create the issue", "raise a ticket for", "put this on the board", "spec this out as a ticket", "as a user I want".
---

# Ticket authoring

A ticket is a contract: why the work exists, what "done" means, and which tests
will prove it. If it cannot answer those, it is not ready and the work should
not start.

This happens in **two stages, with a stop between them**. The user story is
agreed before any technical design is drafted. That order is the point of the
skill — a story written to justify a solution someone already has in mind is
not a story, and the technical design that follows inherits every assumption
nobody examined.

## Stage 1 — The user story, and only the user story

### Interrogate the idea first

Resolve `design-interview` per `references/capabilities.md` at the plugin root
and call that provider. A feature described in one sentence has not been
thought about yet, and the interview is where that shows.

Built-in, if nothing is installed — get real answers to all of these:

- **Who is stuck?** Name them. A role, not "the user". If you cannot name
  someone who benefits, question whether the work should happen at all.
- **What are they trying to do**, in their words, not the system's?
- **Why does the current situation fail them?** What do they do today instead?
- **What happens if this is never built?** If the answer is "nothing much",
  that is worth knowing now.
- **How will they know it worked?** In terms they would use.

### Write it as prose

One paragraph. Not the `As a… I want… so that…` formula — that template
compresses three interesting things into one sentence and hides which of them
is load-bearing.

Say who is stuck, what they are trying to do, and why today fails them.

### Now stop

**Show the human the story and ask whether it is right. Do not continue until
they say so.**

> Here is the story as I understand it. Before I work out endpoints, criteria
> or tests — is this the problem we are solving, and is this who we are solving
> it for?

This gate is cheap and the alternative is not. A story that is wrong costs one
paragraph to fix here; discovered after the endpoints, criteria and test plan
are written, it invalidates all three. Do not draft the technical design "to
save a round trip" — that is the round trip that makes the correction expensive.

If they change the story, rewrite it and ask again.

## Stage 2 — Everything that derives from the story

Only once the story is agreed.

### Check the story is actually buildable

A user story almost always assumes a capability the codebase does not have.
"Only the owner can see it" assumes identity. "Notify them" assumes a channel.
"Restore it" assumes soft delete. "Their records" assumes a user table.

**List the assumptions the story makes and check each against the code.** Grep,
do not assume. If a prerequisite is missing, stop and say so plainly, then
propose the split:

> This needs an identity system and there isn't one — no users table, no
> session, no auth middleware. That's at least two tickets: authentication
> first, then per-record visibility on top. Do you want both, or should the
> first stub identity behind an interface so the visibility work can proceed
> independently?

Let the human decide. Options, in rough order of how often they are right:

- **Split it.** Two tickets, the dependency first. Usually correct.
- **Stub the dependency behind an interface.** A `CurrentUser` port with a
  hardcoded implementation lets the real work proceed and be tested, and makes
  the second ticket a swap rather than a rewrite.
- **Cut the scope** so the dependency is not needed.
- **Build it all in one.** Occasionally right, usually a ticket nobody can
  review.

Never write acceptance criteria the code could not satisfy even when finished.
A ticket that silently assumes a missing system is the most expensive kind: it
reads like a plan, so nobody questions it until someone is three days in.

### If it is too big for one ticket

If the work is several vertical slices rather than one, resolve
`ticket-slicing` and use that provider to break it up. Each slice cuts a narrow
but complete path through every layer — schema, API, UI, tests — and is
demoable on its own. A slice that touches only one layer is not a slice.

Built-in, if nothing is installed: size each ticket to fit one focused session,
give each one its blockers, and sequence any prefactoring first. "Make the
change easy, then make the easy change."

### Technical design

For API work: the method, path, request body, every status code it can return
and what each means. Decide `PUT` versus `PATCH` **here**, not while coding —
they are different contracts, and if you need both, say so and give each its
own acceptance criterion.

Where the design has a lifecycle, a multi-participant sequence, a schema
change, or branching logic, use `design-sketching` to decide whether a Mermaid
diagram earns its place — and to draw it if so. Diagrams belong here, once the
story is settled.

### Acceptance criteria

Checkboxes. Each independently verifiable by someone who did not write the
code, and each phrased as an observable outcome.

"Works correctly" is not a criterion. `Sending {"name":"x"} to PUT leaves
description empty` is.

### The TDD test plan — bound to the criteria

The tests you will write, before you write them. One line each, tagged with the
suite, and **each one naming the acceptance criterion it proves**:

```
- [go]     AC1 · rejects a blank name with 422
- [go]     AC2 · PUT resets fields the body omits
- [vitest] AC3 · PATCH body omits unticked fields
- [manual] AC4 · the console shows the reset field as blank in the table
```

**Every acceptance criterion must have at least one test.** A criterion with no
test is a criterion nobody will check, and it will be ticked at review because
it sounds true. Before finishing, go down the criteria and confirm each appears
in the plan. If one cannot be tested, that is a sign the criterion is not
observable — rewrite it until it is.

This binding is what makes the criteria useful to `red-green`: the
implementation loop works down the test plan, and each green test ticks off a
criterion rather than accumulating tests nobody asked for.

Anything tagged `[manual]` must be justified — see `manual-test-design`. The
default assumption is that a behaviour **can** be automated and the tagger has
not thought hard enough.

### Manual verification checklist

Leave the heading with a note that `review-handoff` fills it in. Writing the
steps now, before the UI exists, produces steps for a UI you imagined.

## Creating it

Use `references/ticket-template.md` for the shape.

```bash
gh issue create \
  --title "<verb-first summary>" \
  --body-file <path> \
  --label enhancement
```

Then put it on the board in **backlog**, not ready:

```bash
ghboard add <issue-number>
ghboard move <issue-number> backlog
```

Open the issue and check any Mermaid rendered. It fails silently.

## Then stop again

**Backlog means written but not approved.** Show the human the ticket URL and
ask them to review it. Do not create a branch, do not write a test, do not move
the card to Ready — moving it is their signal that the design is right.

When they approve:

```bash
ghboard move <issue-number> ready
```

If they ask for changes, edit the issue with `gh issue edit` rather than
opening a new one — the ticket number is the thread the whole process hangs on.

## What this skill will not do

- Draft technical design before the story is agreed.
- Move a card to Ready. That is the human's approval.
- Write acceptance criteria that no test in the plan covers.
- Write a ticket from a one-line request without interrogating it. That ticket
  is worse than none: it looks like a decision was made when none was.
