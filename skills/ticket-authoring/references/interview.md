# The behavioural interview

Three axes, walked after the story is agreed and before the design is drafted.
Each is a **closed list**: you go down it and get an answer for every row, so
"we never thought about that" cannot survive to implementation disguised as "it
didn't come up".

The answers become acceptance criteria directly. That is the point of doing this
before the design rather than after — criteria derived from a walked list are
criteria nobody had to imagine unprompted, which is why this works where
"remember to think about edge cases" does not.

**Ask, do not assume.** Where the human does not know, that is an answer worth
having: it means the behaviour is undefined, and undefined behaviour ships as
whatever the implementation happens to do.

## Axis 1 — Failure modes

For each step in the flow, against this list. Not every row applies to every
step; say which do not and why.

| Mode | The question |
|---|---|
| Dependency unavailable | The database, the API, the queue is down. What does the caller see? |
| Dependency slow | It responds in 30 seconds. Is there a timeout, and what happens when it fires? |
| Dependency lies | It returns a 200 with malformed data, or a field that should never be null. |
| Partial write | Two things must be written and the second fails. What is the state afterwards? |
| Concurrent writer | Two requests touch the same row at once. Last-write-wins, or a conflict? |
| Permission absent | The caller is authenticated but not authorised. 403, 404, or filtered out? |
| Resource missing | The id does not exist. 404, or an empty success? |
| Resource exists | Creating something already there. 409, idempotent success, or overwrite? |

**State what does not happen, as well as what does.** The negative half is the
part that gets dropped, and it is usually the half a test can catch:

```
AC4  a provider timeout surfaces as 503, and the record is NOT written
```

"Returns 503" passes with a half-written record. "And the record is not written"
does not.

## Axis 2 — Input domains

For **each input the feature accepts**, against this list. This axis catches a
different class of defect from axis 1: not a path that fails, but a path the
code does not have, because the real world supplies values nobody tested.

| Dimension | The question | Worked example |
|---|---|---|
| Case | Does case matter, and is it normalised **on write and on read**? | `Alex@foo.com` |
| Whitespace | Is leading and trailing whitespace trimmed? Internal? | `" alex@foo.com"` |
| Unicode | Accented, non-Latin, combining characters, emoji? | `josé` vs `jose´` |
| Length | At zero, at the column limit, one past it? | a 320-character email |
| Absence | Empty, null and absent — three cases or one? | `""` vs `null` vs missing |
| Uniqueness | Can two values differ only by normalisation? | `Alex@` and `alex@` are one user |
| Type coercion | A number as a string, a string as a number, `"true"` vs `true`? | `{"qty": "3"}` |

### Why "on write and on read" is the load-bearing phrase

Normalising at signup alone still breaks login. The signup path lowercases and
stores `alex@foo.com`; the login path looks up whatever was typed. `Alex@foo.com`
finds nothing, the user is told their credentials are invalid, and no error is
ever logged because nothing failed.

That asymmetry is the bug. One side normalising is worse than neither, because
the data looks clean and the lookup still misses. Ask about both sides
explicitly — the answer "we lowercase it" is incomplete until you know where.

### One input, several criteria

This is normal and not a sign of over-specification:

```
AC5  Alex@foo.com and alex@foo.com resolve to the same account on login
AC6  " alex@foo.com" is trimmed before lookup
AC7  an accented local part is accepted and stored NFC-normalised
AC8  an empty email returns 422, distinct from an absent one
AC9  signup with Alex@ when alex@ exists is rejected as a duplicate
```

Five criteria from one field nobody would have thought to question.

### Proportionality

Walking seven dimensions over every input of a large feature is too much. Two
narrowings, in order of preference:

1. **Identifier-like inputs get the full walk.** Emails, usernames, slugs,
   codes, external IDs — anything used for lookup, comparison or uniqueness.
   These are where normalisation bugs hide, because they are compared rather
   than merely stored.
2. **Everything else gets absence and length.** Those two catch most of the
   rest, and they are the cheapest to answer.

## Axis 3 — Parity

**Skip when nothing sits alongside the feature.** The first genuinely new
endpoint on a new resource has no siblings, and inventing a comparison is worse
than omitting the section.

Otherwise: grep for what this feature sits beside — the other endpoints on the
resource, the other tabs in the UI, the other providers behind the interface,
the other half of a symmetric pair (create/update, PUT/PATCH, web/mobile).

Then tabulate. The table is the deliverable, because a list of prose
observations does not make a gap visible:

```markdown
Checked against the sibling endpoints on /records:

| | GET | POST | PUT | this (PATCH) |
|---|---|---|---|---|
| 422 on blank name | n/a | yes | yes | yes |
| auth required | yes | yes | yes | yes |
| empty list as [] | yes | n/a | n/a | n/a |
| soft-delete aware | yes | n/a | NO | NO ← |

PUT ignores soft-deleted rows too. The divergence from GET is pre-existing and
not introduced here.
```

**Every divergence is either a stated decision or a bug.** An unexplained cell
is the latter. Rows worth checking by default: error shape, validation rules,
auth requirement, pagination, empty-collection serialisation, soft-delete
awareness, and whatever the config's `apiConventions` block names.

Where the divergence is pre-existing, say so. "This is also wrong in PUT" is a
finding, not an excuse — it may deserve its own ticket, and saying it out loud
is how that gets decided rather than forgotten.

## The closing question, for every axis

> Which of these are we deliberately not covering, and why?

A waived mode that has been named is a decision, and it is recorded on the
ticket and carried into the sign-off ask. A mode nobody mentioned is the defect
this interview exists to surface.

Record waivers in the shape the sign-off needs:

```
✗ concurrent PATCH on the same row — out of scope, pre-existing, no test
```

Not "we decided not to worry about concurrency". The reason is what the human
agrees or disagrees with at the gate.

## Skip rule for the whole interview

Skip when complexity is **trivial** and the ticket touches nothing on
`models.escalateOn`. A copy change does not need a parity table.

Failure modes are the exception and never skip entirely — but
"none: this changes a static string and has no inputs, no dependencies and no
failure path" is a complete and passing answer. Write that sentence rather than
deleting the section, so a reviewer can see the question was asked.
