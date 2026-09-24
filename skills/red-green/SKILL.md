---
name: red-green
description: The implementation loop, where the red→green commit pair is the audit trail. Use when implementing a Ready ticket, resuming work on a feature branch, or fixing something a human tester sent back. Owns the evidence — one failing test committed alone, then the implementation that turns it green — and delegates test quality to whichever TDD skill is installed. Triggers on "implement", "start coding", "write the test", "make it pass", "continue the feature", "resume", "red green", "next slice".
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

### 5. Run again, and commit the green

```bash
git add -A
git commit -m "feat(green): <what it does>"
```

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

- Move the card to In review. That is `review-handoff`, and only once
  everything is green.
- Commit a test it has not watched fail.
- Write production code in a `test(red):` commit.
- Bypass the configured test command.
