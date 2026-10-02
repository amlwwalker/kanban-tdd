---
name: design-docs
description: The appendix documents a ticket links to rather than inlines — where the design, the failure-mode analysis and the input-domain walk live, how code and tests link back to a section by stable anchor, and the rule that keeps them true. Use when writing a ticket's design, when implementation diverges from what a document says, or when deciding where a piece of detail belongs. Triggers on "design doc", "RFC", "where does this go", "the doc is out of date", "link to the design", "anchor", "design-docs".
---

# Design docs

A ticket people scroll past is worse than a thin one, because a rubber-stamped
gate manufactures confidence. The rigour in `ticket-authoring` produces three
interview transcripts, a parity table and an input-domain matrix — inline, that
is a wall nobody reads, and the sign-off it is supposed to inform becomes a
formality.

So the detail lives here and the ticket carries a synopsis that links into it.

**The split, stated once:** the ticket carries what a human must read to
*decide*. The design doc carries what they might want to read to *understand*.
A reviewer deciding whether the tests are sufficient needs the coverage table
and the waived modes; they do not need the transcript of how those were arrived
at, until they disagree.

## The folder

```
design-docs/
  rfc/
    0003-session-identity.md          numbered, immutable once accepted
  features/
    auth-email-normalisation.md       one per coherent feature area
```

**`rfc/`** is for decisions with alternatives — a choice between approaches,
where the rejected options and the reasoning matter later. Numbered, and not
rewritten once accepted: a superseded RFC gets a successor that links back, so
the history of the decision survives. These are rare.

**`features/`** is for how something works, and is **kept current**. One
document per feature area, not per ticket — a second ticket touching email
normalisation edits `auth-email-normalisation.md` rather than adding
`auth-email-normalisation-2.md`. Named for the area, not the ticket, because
ticket numbers mean nothing to someone reading in two years.

If a repo has an established docs location, use it rather than creating this
tree alongside. Say which you chose.

## Anchors

Every section a ticket or a piece of code points at carries an explicit ID:

```markdown
## Email normalisation {#AUTH-3}
```

**Not a heading slug.** `#email-normalisation` breaks the moment someone
retitles the heading, and it breaks *silently* — nothing fails, and every
comment pointing at it goes on reading as authoritative while pointing at
nothing. That is the staleness problem this convention exists to avoid, so
avoiding it in the links themselves is the minimum.

An explicit ID survives retitling. More importantly a script can verify it:
`review-handoff` runs `scripts/design-anchors.sh`, which fails on a missing file
or a missing anchor, so a broken link is caught at the gate rather than by
someone months later who trusted the comment.

**Allocation.** The prefix belongs to the document, the number is sequential and
never reused:

- `AUTH-1`, `AUTH-2`, `AUTH-3` in `auth-email-normalisation.md`
- A new section on a later ticket takes the next free number — `AUTH-7` — rather
  than renumbering anything. Renumbering invalidates every comment in the
  codebase that pointed at the old ID.
- A deleted section's ID is **retired, not reused.** Reuse silently repoints
  every existing link at unrelated content, which is worse than a broken link
  because it resolves.

## Linking from code

Where a function or a test implements a design decision that is not obvious from
reading it, name the section:

```go
// design: design-docs/features/auth-email-normalisation.md [AUTH-3]
func normaliseEmail(s string) string {
```

```typescript
// design: design-docs/features/auth-email-normalisation.md [AUTH-3]
it("treats Alex@foo.com and alex@foo.com as one account", () => {
```

The format is exact, because a script parses it: `design:` then a repo-relative
path then the ID in square brackets. One per comment line.

**This is opt-in per symbol, and that restraint is the point.** A codebase where
every function carries a `design:` comment is a codebase where none of them are
read — the comments become furniture, like a copyright header. Add one where a
reader would otherwise ask "why does it do it this way", which in practice is:

- A normalisation, a rounding rule, a tie-break — anything where the chosen
  behaviour is one of several defensible ones
- A test whose value is not obvious from its name, especially a regression test
  for something subtle
- A workaround whose reason lives outside the code

Not on a CRUD handler that does what its name says.

## Keeping them true

This is the part that fails in every project that has tried documentation, so it
is enforced at a gate rather than requested in a style guide.

### The doc is updated in the green commit

When implementation diverges from what the document says, **the document is
edited in the same commit as the behaviour**. Not in a follow-up, not in a tidy-up
pass, not in a ticket someone files.

```bash
git add -A           # implementation AND the design-doc edit
git commit -m "feat(green): normalise email on lookup as well as write"
```

Same discipline as the red→green pair, for the same reason: it is visible in the
diff, and checkable afterwards by someone who was not there. A green commit that
changes behaviour a document describes, without touching the document, is the
defect — and `git log -p design-docs/` is how you find out whether this is
actually being done.

### Handoff asks whether it is still true

`review-handoff` runs two checks:

1. **`design-anchors.sh` passes.** Every `design:` comment resolves to a real
   file and a real anchor. A hard failure — a broken link is not a judgement
   call.
2. **If the diff changed behaviour under a `design:` comment and the referenced
   document is untouched since the ticket was written, it asks.** Is the
   document still true?

The second is deliberately a question, not a failure. A refactor can
legitimately leave the design unchanged, and a gate that cries wolf gets
routed around. But it is asked every time, and the answer goes in the handoff
where a reviewer sees it rather than being resolved silently.

### When a document is wrong

Fix it in the commit that discovers it, even when the discovery is incidental to
the ticket. A known-wrong document is worse than none: people trust it once and
then stop trusting the whole folder.

If the fix is too large to ride along — the design changed shape, not detail —
say so on the ticket and raise it, rather than leaving a document that is
confidently wrong.

## What goes in the ticket instead

A synopsis and tables. The full shape is in
`ticket-authoring/references/ticket-template.md`; the principle is that every
section on the ticket is either a **decision** or a **count with a link**:

```markdown
## Design docs

- [Email normalisation](design-docs/features/auth-email-normalisation.md) —
  design, all three interview axes, coverage diagram

## Failure modes

6 identified, 4 covered. Full analysis in the design doc.

| Mode | Covered | Criterion |
|---|---|---|
| blank name | yes | AC2 |
| provider timeout | yes | AC4 |
| concurrent write to one row | **no** | out of scope, pre-existing |
```

The coverage diagram stays **on the ticket**, not in the doc. It is the artifact
being signed off, and it is already a summary — moving it behind a link defeats
the gate.

## What this skill will not do

- Create an `rfc/` entry for a decision with no alternatives. That is a feature
  doc.
- Renumber anchors. IDs are permanent once a commit references them.
- Reuse a retired anchor ID.
- Leave a document contradicting the code it describes once that is noticed.
