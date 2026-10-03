---
name: red-green
description: The implementation loop, where the red→green commit pair is the audit trail. Use when implementing a ticket that is already in Ready, resuming work on a feature branch, or fixing something a human tester sent back. Checks the card is in Ready before anything else and refuses if it is not — Backlog means nobody approved it. Owns the evidence — one failing test committed alone, then the implementation that turns it green — and delegates test quality to whichever TDD skill is installed. Triggers on "implement", "implement #N", "start coding", "write the test", "make it pass", "continue the feature", "resume", "red green", "next slice".
---

# Red → green

A test that has never been red proves nothing. This skill exists to make that
checkable by someone who was not there: the commit pair is the evidence, and a
reviewer can check out the red commit and watch the test fail.

## What this skill owns, and what it does not

**It owns the evidence.** The commit sequence, that the red commit genuinely
fails, that no production code rides along with it, that the pair survives to
review unsquashed.

**It delegates the thinking.** What makes a good test, where the seam goes,
what to test next — resolve `tdd-discipline` per `references/capabilities.md`
at the plugin root and call that provider. It is a reference to consult, not a
session that takes over: when it finishes you are still here, and the card has
not moved.

**Say which provider you are using, once, before the first test** — and if it
is the fallback, say what the preferred one would add:

- Preferred (`tdd`) → "Using `tdd` for test discipline."
- Fallback (`superpowers:test-driven-development`) → "Using
  `superpowers:test-driven-development`. `mattpocock-skills:tdd` goes deeper
  on seams and anti-patterns — `claude plugins install mattpocock-skills` —
  but this covers the loop."
- Neither → use the built-in rules at the bottom and say so.

Then start. Do not wait for a reply about installing anything.

If nothing is installed, the built-in section at the bottom is enough to work
with, and noticeably thinner.

## Before the first test

### Refuse unless the card is in Ready

**First action, before reading the ticket and before cutting a branch.**

```bash
ghboard status <n>          # which column is this in?
```

It prints the live column name, so compare against `project.columns` in the
config rather than against the names below — a board may call them something
else.

| Column | Do |
|---|---|
| **Ready** | Continue. |
| **In progress** | Continue — this is a resume. |
| **Backlog** | **STOP.** Not approved. |
| **In review / Done** | **STOP.** Ask what is actually wanted. |
| *not on the board* | **STOP.** `ghboard status` errors. The ticket exists but was never added, so there is no gate to have passed. Offer `ghboard add`. |

**Backlog means written but not approved**, and Ready is the human's signal
that the design and the test plan are right. A ticket worked straight out of
Backlog has had no approval gate at all — so say so and stop:

> #1448 is in Backlog, not Ready. Ready is your approval that the design and
> the test plan are right, and nothing has been approved on this one yet.
>
> I can run `ticket-refinement` to say what is missing, or you can tell me to
> proceed anyway. I will not start on my own.

Then wait. Offer `ticket-refinement`; do not run it unasked, and do not
promote the card yourself — **moving a card to Ready is never a machine's
move.** If the human says go anyway, that is their call: proceed, and note in
the handoff that the ticket was worked from Backlog without approval, so the
reviewer knows which gate was skipped.

This check exists because the Ready gate is otherwise enforced only in
`ticket-authoring` and `ticket-refinement` — both upstream of here. A request
like "implement #1448" routes straight to this skill and walks past them, so
the gate has to be enforced where the work actually happens. Every other gate
in this plugin is.

### Read the ticket, comments included

```bash
ghboard read <n>
ghboard comments <n> --after-commit     # on resume
```

Anything new since your last commit, surface it before writing code. See
`references/comments.md`.

### Check for a re-entry

If the ticket carries the `verification-failed` label, a human tried this and
it did not work. Read the failure comment. The failed step is your next
behaviour, and it gets a red test that reproduces the failure before any fix —
a bug a human found is still a bug.

### Check the model the ticket asks for

If the ticket records a **Model** and this session is on a different one, say
so before the first test and ask — see `references/models.md`. The ticket's
suggestion came from its complexity and may have been escalated; the person
about to work it knows things the config does not.

Proceed on whichever they choose. Do not refuse to work on their pick.

### Agree the seams

Before any test is written, name the public boundary you will test at and
**confirm it with the user**. No test is written at an unconfirmed seam.

You cannot test everything. Agreeing the seams up front is how the effort lands
on critical paths and complex logic instead of spreading evenly over everything,
and it is the difference between tests that survive a refactor and tests that
break when nothing behavioural changed.

> The seams here are the `Store` interface and the HTTP handler. Tests go
> against those, not against the pgx pool or the router internals. Agreed?

*(The seam concept and the vertical-slice rules below are borrowed from Matt
Pocock's `tdd` and `to-tickets` skills, MIT licensed. If his skills are
installed, prefer them — they go deeper.)*

### Work from the ticket's test plan

The ticket's TDD test plan already lists the tests, one line each, each bound to
an acceptance criterion. Work down it in order. If a test you now need is not on
the plan, add it to the ticket rather than writing it silently — the plan is
what `review-handoff` checks the inventory against.

## The loop

One slice at a time. One seam, one test, one minimal implementation.

### 1. Write the failing test — and nothing else

No production code. No helper the implementation will need. No "while I'm here"
refactor. The red commit must contain exactly one thing: a test that fails.

### 2. Run it, and watch it fail

```bash
<tests.<suite>.command>          # from workflow.config.json, never a raw
                                 # `go test` or `vitest` — the configured
                                 # command is what CI runs, and bypassing it
                                 # is how local and CI drift apart
```

**Read the failure.** It must fail for the reason you intended. A test that
fails on a typo, a missing import, or a nil panic in setup is not red — it is
broken, and fixing it later will quietly turn it green without proving anything.

If it **passes** on first run, stop. Either the behaviour already exists, or
the test asserts nothing. Both are worth knowing, and neither is progress. Say
which, and do not commit a test that has never been red.

### 3. Commit the red

```bash
git add <test file only>
git commit -m "test(red): <the behaviour, as the test name reads>"
```

Keep the failure output — it goes in the handoff. Some teams paste it into the
commit body; that is a good habit and not required.

### 4. Make it pass — minimally

Only enough code to turn this test green. No speculative features, no
anticipating the next test on the plan. If you find yourself writing code no
current test demands, stop: that code belongs to a later slice, and writing it
now means it arrives untested.

### 5. Run again, and commit the green — with the doc

```bash
git add -A        # the implementation AND any design-doc edit
git commit -m "feat(green): <what it does>"
```

**If the implementation diverged from what a design doc says, the doc is edited
in this commit.** Not in a follow-up, not in a tidy-up pass, not in a ticket
someone files and nobody picks up.

Same reasoning as the red→green pair itself: it is visible in the diff and
checkable afterwards by someone who was not there. Documentation rots because
updating it is always someone's next task; attaching it to the commit that
caused the divergence is the only version of this rule that survives contact
with a deadline.

A green commit that changes behaviour a document describes, without touching
that document, is the defect. `git log -p design-docs/` is how anyone finds out
whether this is actually happening.

Where the behaviour you just wrote implements a non-obvious design decision —
a normalisation, a rounding rule, a tie-break, a subtle regression test — add the
anchor comment so the next reader can get from code to reasoning:

```go
// design: design-docs/features/auth-email-normalisation.md [AUTH-3]
func normaliseEmail(s string) string {
```

Opt-in per symbol, not on everything. A codebase where every function carries one
is a codebase where none are read. See the `design-docs` skill for anchor rules —
IDs are never renumbered or reused, because a commit already points at them.

### 6. Repeat

Next line of the test plan. Each cycle is a tracer bullet: it responds to what
the last one taught you, rather than executing a plan written before you knew
anything.

## The invariants

Check these before every handoff. They are what a reviewer can verify, which
means they are also what can be absent.

- **Two commits minimum per behaviour.** `test(red):` then `feat(green):`.
- **Never squash the pair locally.** Squashing the PR at merge is fine — the
  pair survives in the PR's commit list, which is where a reviewer looks. What
  must not happen is collapsing them before the PR exists.
- **The red commit contains no production code.** `git show --stat` on it
  should list test files only.
- **The red commit actually fails.** If someone checks it out and the suite
  passes, the evidence is a fiction.
- **No test arrives in the same commit as its implementation.** That is the
  tell that TDD did not happen, and `review-handoff` checks for it.
- **A design doc the work contradicts is edited in the green commit**, never
  left for later. A documented behaviour and a shipped behaviour that disagree
  is worse than no document, because people trust it once and then stop
  trusting the folder.

A design-doc edit is production-adjacent, so it belongs in the green commit, not
the red one. A `design:` comment inside a test file is fine in the red commit —
that file is still test-only.

Verify at any point:

```bash
git log --oneline "$(git merge-base HEAD origin/<integration>)"..HEAD
```

You should see pairs, alternating. A run of `feat(green):` commits with no red
between them means tests were written after the fact, or not at all.

## Anti-patterns

- **Horizontal slicing.** Writing all the tests first, then all the
  implementation. Bulk tests verify *imagined* behaviour: you commit to a test
  structure before understanding the implementation, and the tests go
  insensitive to real changes. Work vertically — one test, one implementation.
- **Implementation-coupled tests.** Mocking internal collaborators, testing
  private methods, asserting through a side channel (querying the database
  instead of using the interface). The tell: the test breaks on a refactor when
  no behaviour changed.
- **Tautological tests.** The assertion recomputes the expected value the way
  the code does, so it passes by construction and can never disagree with the
  code. Expected values come from an independent source: a known-good literal,
  a worked example, the ticket's acceptance criterion.
- **Retrofitting the red.** Writing code, then writing a test, then reordering
  the commits so it looks like TDD. The commits will say one thing and the
  reflog another. If TDD did not happen, say so — it is recoverable, and a
  false audit trail is not.

## When CI is red

Fix it on the branch. Do not move the card, do not open the handoff. A branch
that is red is still In progress, whatever the work feels like.

## Built-in TDD rules

Used when `tdd-discipline` resolves to `builtin`. Deliberately thin — install
`mattpocock-skills` for `tdd`, or superpowers for
`test-driven-development`, and this section stops being used.

- Test behaviour through public interfaces, never implementation details. A good
  test reads like a specification and survives a refactor.
- Name the seam before the test. Confirm it with the user.
- Expected values come from an independent source of truth.
- One test, one implementation, repeat. Never bulk-write tests.
- Red before green, always, with the failure read and understood.
- Refactoring is a separate step from the red→green cycle, and belongs with
  review rather than inside the loop.

## What this skill will not do

- **Start work on a ticket that is not in Ready.** Backlog means nobody has
  approved it. Stop, say which column it is in, and wait.
- Move a card to Ready to unblock itself. That is the human's gate, and
  promoting it here would defeat the only check this skill answers to.
- Move the card to In review. That is `review-handoff`, and only once
  everything is green.
- Commit a test it has not watched fail.
- Write production code in a `test(red):` commit.
- Bypass the configured test command.
- Hand-roll `gh` commands that `ghboard` already covers, or hunt for the
  script by path when the shim is missing — fix the shim and say so.
- Present a spike as workflow output.
