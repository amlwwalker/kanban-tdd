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

### Classify it

Skip this entirely if the config has no `taxonomy` block — a small project
does not need it, and inventing labels is worse than having none.

**Type — exactly one, never optional.** Work down `taxonomy.typeLabels` and
take the first that matches:

1. **Security-adjacent?** A vulnerability, an exposure, a leaked credential, a
   bypassed paywall, injected code. Then it is `security`, even when it is
   also a bug. Security wins over everything.
2. **Was it ever working as intended?** If yes and it stopped, `bug`. If it
   never worked, ask whether anyone was told it would: promised and absent is
   a bug, never promised is a feature.
3. **Will a user see something new?** `feature`.
4. **Has anyone committed to doing it?** If not, `idea` — and do not size or
   prioritise it.
5. **Otherwise `task`.** The honest home for CI work, migrations, legacy
   removal, performance fixes and config. Not a dumping ground: work with a
   definition of done and no user story.

Do not invent types beyond the configured set. Tech debt is a `task`;
performance work is usually a `bug`. Giving either its own label would not
change how it is handled.

Where the configured label is `null`, the type exists but the tracker has no
label for it yet. **Say so explicitly in your report** and put the type in the
title — `[backend][task] …` — rather than filing a silently untyped ticket.
**Never run `gh label create` as a side effect of filing a ticket.**

**Service — inferred, never guessed.** Read the current repo and look it up in
`taxonomy.serviceLabels.map`:

```bash
gh repo view --json name -q .name
```

If the repo is not in the map, **ask**. A mislabelled service is worse than an
unlabelled one, and an out-of-scope repo may not belong on this board at all —
say that rather than filing anyway.

**Area — zero or more**, from `taxonomy.areaLabels.values`. These span
services by design: a billing bug can touch three repos at once.

### Set priority and size

Skip if the config has no `priority` block.

Priority lives in a **project field**, never a label. Choose against
`priority.levels` — the definitions are the team's, not yours — and when
`requireReasoning` is true, **state in the ticket body why this level and not
the one above or below**:

> **Priority P1.** Syndicated sales are missing from the dashboard for every
> syndication customer and there is no workaround, but revenue is still being
> recorded correctly, so it is not P0.

That sentence is the point of the field. It makes the choice auditable and
gives a human something specific to disagree with.

`priority.default` applies unless the definitions clearly say otherwise. **Do
not reach for the top level by reflex** — a board where half the tickets are
P0 has a decorative priority field, and the next person cannot tell which
three things actually matter. If `securityIsAlways` is set, a security ticket
takes that level regardless.

Size, if configured, is **how much work, not how urgent** — the two are
independent, and a one-line fix can be the most urgent thing on the board.
Anchor it to a real ticket from `size.anchors` rather than an adjective.

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

### What it logs, and what it must never log

Skip if the config has no `logging` block.

Logging designed at ticket time gets built. Logging remembered at review gets
bolted on, inconsistently, by whoever notices. So if the feature touches
anything in `logging.logByDefault` — an API call, a user action, a state
change, an error path — the ticket says what it logs and at what level.

Three lines in the design section, not three paragraphs:

```markdown
## Logging

- `INFO` on a successful locale resolution: the locale requested and the one used.
- `WARN` when an unknown locale falls back: the requested locale, so a missing
  translation shows up in a query rather than silently degrading.
- Never logged: the visitor's name. It is user content, not diagnostic data.
```

Use the level names from `logging.levels` and their meanings — teams disagree
about where INFO ends and DEBUG begins, and the config records this team's
answer. Check anything the feature handles against `logging.neverLog`, and be
specific about it: "never log the token" is a rule, "never log the `Authorization`
header we now forward" is a decision about this ticket.

If `logging.sanitisation` names a gap — a layer that redacts nothing — and this
feature runs in it, say so. That is exactly where a reviewer needs to look.

### Check the API contract

Skip if the config has no `apiConventions` block, or the ticket adds no
endpoint.

The design section states the error shape, the status codes and the update
semantics **from the config**, not from scratch. These were decided once so
they are not re-litigated per endpoint:

- Errors use `apiConventions.errorShape`. One shape everywhere.
- Validation failures and malformed bodies get the configured statuses. They
  are different failures and a caller needs to tell them apart.
- When `internalErrorsLeak` is false, an internal error is logged in full and
  returned bare — **and the test plan carries a test asserting nothing leaks.**
- If the ticket adds a partial update, follow `partialUpdate`. If you need one
  of PUT/PATCH you almost certainly want both, with an acceptance criterion
  and a test for each.
- When `listsAreNeverNull` is true, an empty collection serialises as `[]`.

A design that departs from any of these is a decision worth stating, not a
detail to leave to implementation. Say which convention you are breaking and
why, so a reviewer can disagree with the reason.

### Acceptance criteria

Checkboxes. Each independently verifiable by someone who did not write the
code, and each phrased as an observable outcome.

"Works correctly" is not a criterion. `Sending {"name":"x"} to PUT leaves
description empty` is.

### The TDD test plan — bound to the criteria

The tests you will write, before you write them. One line each, tagged with the
suite, and **each one naming the acceptance criterion it proves**.

**The tag is a key from `tests` in the config, not a framework name.** Read
them first — `jq -r '.tests | keys[]' .claude/workflow.config.json` — and use
those exactly, plus `[manual]`. A plan tagged `[vitest]` against a config whose
suite is called `unit` names a suite that does not exist, and `review-handoff`
checks its inventory against this plan.

So for a config with `backend` and `frontend` suites:

```
- [backend]  AC1 · rejects a blank name with 422
- [backend]  AC2 · PUT resets fields the body omits
- [frontend] AC3 · PATCH body omits unticked fields
- [manual]   AC4 · the console shows the reset field as blank in the table
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

When the config has a `testers` list, add the sign-off block under it, so
verification has a named owner rather than being anonymous:

```markdown
## This ticket has been tested by

- [ ] Alex Walker
- [ ] Sam Patel
```

Omit it on a security ticket — a security fix should not wait on a full
sign-off round.

### House style

When the config has a `style` block, apply it to everything you write into the
ticket. British or American spelling per `style.english`. When
`style.emDashes` is `forbidden`, rewrite as two sentences — a full stop is
almost always right — and the rule applies **inside diagram labels too**, which
is the place it gets forgotten.

## Creating it

Use `references/ticket-template.md` for the shape.

Build the title from the classification when `taxonomy.titlePrefix` is on —
`[service][type] verb-first summary` — including the type only where its label
is `null`, since a real label already carries it.

```bash
gh issue create \
  --title "<[service] verb-first summary>" \
  --body-file <path> \
  --label "<type label>" --label "<service label>" --label "<area labels>"
```

Pass only labels that exist. If one is missing from the tracker, **say so in
your report** and carry the dimension in the title instead. Never create a
label as a side effect.

Then set the project fields, where configured. These are fields, not labels,
so they are set after the card is on the board:

```bash
ghboard add <issue-number>
ghboard move <issue-number> backlog
```

Set `priority.field` and `size.field` on the card with `gh project item-edit`.
If the board has no such field, say so rather than silently skipping it — a
priority that was decided and then dropped is worse than one never set, since
the body claims a level the board does not show.

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
