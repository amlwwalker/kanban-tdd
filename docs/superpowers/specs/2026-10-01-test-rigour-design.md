# Test rigour: interrogating behaviour before writing the test plan

## The problem

Tickets written by this plugin pass every existing gate while covering only the
happy path. Three specific defects, all reproducible against the current skills:

**Nothing asks how the feature behaves.** `ticket-authoring` stage 1 runs a
five-question interview, and all five are about *why the feature exists* — who
is stuck, what they do today, what happens if it is never built. Not one asks
what the feature does with invalid input, or what happens when a dependency
fails. The interview ends at the story and never resumes. Acceptance criteria
are therefore written from the author's imagination rather than from anything
interrogated.

**Unhappy paths are advice, never a gate.** The phrase appears three times —
`design-sketching` says "show the unhappy path", the ticket template repeats it
in a comment, `manual-test-design` says include the negative. All three are
guidance about *how to write a section well*. The acceptance-criteria and
test-plan sections carry no failure-path requirement at all, and
`ticket-refinement` checks that every criterion has a test without ever asking
whether the criteria cover failure. A ticket with five happy-path criteria and
five matching tests is currently assessed as ready.

**Parity is absent entirely.** Nothing looks at the features a new one sits
alongside. The PUT-versus-PATCH line in the design section is the only
parity-shaped text in the plugin and it is incidental to a different point.

A fourth defect sits underneath the first three and is the most expensive,
because no amount of failure-path thinking finds it: **the set of values the
real world supplies is wider than the set the tests use, and the code often has
no branch there at all.** An email stored as `Alex@foo.com` and looked up as
typed fails login on a case-insensitive expectation. Nothing throws. There is
no error path to have forgotten, no edge to have left off a diagram. Asking
"what happens when the lookup fails?" does not find it. Asking "what does the
real world actually type into this field?" does.

## The shape of the fix

A second interview, between the story gate and the design, whose answers become
the acceptance criteria directly.

```
STAGE 1  why-interview ──────────────▶ story ──▶ ⛔ GATE: human agrees the problem
                                                     (unchanged)

STAGE 2  behavioural interview ──┬──▶ failure modes
         (NEW)                   ├──▶ input domains
                                 └──▶ parity vs siblings
                                          │
                                          ▼
         design + coverage diagram + ACs + test plan
                                          │
                                          ▼
                              ⛔ GATE: human signs off the TESTS
                                 (existing Ready gate, re-pointed)
```

The ordering is the mechanism. Criteria derived from a walked checklist are
criteria nobody had to think of unprompted, which is why this fixes the
imagination problem rather than exhorting people to imagine harder.

## Files

| File | Change |
|---|---|
| `skills/ticket-authoring/references/interview.md` | **New.** The three question banks. |
| `skills/ticket-authoring/SKILL.md` | New stage 2 interview section; sign-off ask re-pointed at the tests. |
| `skills/ticket-authoring/references/ticket-template.md` | `Failure modes`, `Input domains`, `Parity` sections; criteria moved above the test plan. |
| `skills/design-sketching/SKILL.md` | Coverage-diagram pattern with fixed hex colours. |
| `skills/ticket-refinement/SKILL.md` | Three new checks in the step-2 ladder. |

The question banks go in a reference file rather than inline because
`ticket-authoring/SKILL.md` is already 507 lines; three banks inline would push
the skill's own structure past findability. `design-sketching` already
establishes this pattern with `references/diagram-patterns.md`.

## The three axes

Each axis walks a closed list, so an answer of "nothing to report" has to be
given rather than reached by omission. Each produces acceptance criteria
directly.

### Axis 1 — failure modes

For each step in the flow, against this list: dependency unavailable,
dependency slow, dependency returns malformed data, partial write, concurrent
writer, permission absent, resource missing, resource already exists.

Each answer becomes an observable criterion, and the criterion must say what
does *not* happen as well as what does:

```
AC4  a provider timeout surfaces as 503, and the record is NOT written
```

The negative half is the part that gets dropped, and it is usually the part a
test can catch.

### Axis 2 — input domains

For **each input the feature accepts**, against this list:

| Dimension | The question | Worked example |
|---|---|---|
| case | does case matter, and is it normalised on write **and** read? | `Alex@foo.com` |
| whitespace | is leading and trailing whitespace trimmed? | `" alex@foo.com"` |
| unicode | accented, non-Latin, combining characters? | `josé` vs `jose´` |
| length | at zero, at the column limit, past it? | a 320-character email |
| absence | empty, null and absent — three cases or one? | `""` vs `null` vs missing |
| uniqueness | can two values differ only by normalisation? | `Alex@` and `alex@` are one user |

**"On write and read" is load-bearing.** Normalising at signup alone still
breaks login, because the lookup compares the raw input against the stored
value. That asymmetry is the bug in the motivating example, and the question
names it rather than leaving it to be noticed.

One input can legitimately produce several criteria:

```
AC5  Alex@foo.com and alex@foo.com resolve to the same account on login
AC6  " alex@foo.com" is trimmed before lookup
AC7  an accented local part is accepted and NFC-normalised
AC8  an empty email returns 422, distinct from an absent one
AC9  signup with Alex@ when alex@ exists is rejected as a duplicate
```

### Axis 3 — parity

Grep for what sits alongside the feature — the other endpoints on the resource,
the other tabs, the other providers, the other half of a symmetric pair — and
tabulate this ticket's behaviour against theirs:

```markdown
## Parity

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

Every divergence is either a stated decision or a bug. An unexplained one in
the table is the latter.

### The closing question

Each axis ends the same way: **"which of these are we deliberately not
covering, and why?"**

A waived mode that has been named is a decision, and it is recorded. A mode
nobody mentioned is the defect this whole design exists to surface.

## The coverage diagram

Colour marks test coverage. Green is covered by a test in the plan; red is a
known path with no test.

```mermaid
flowchart TD
    In["login(email, pw)"] --> N{"normalise email?"}
    N -->|"lowercased"| L{"lookup user"}
    N -->|"as typed"| MISS["no user found"]
    L -->|"found"| P{"password ok?"}
    L -->|"not found"| E401a["401 invalid credentials · AC2"]
    P -->|"yes"| OK["200 + session · AC1"]
    P -->|"no"| E401b["401 invalid credentials · AC3"]

    OK:::covered
    E401a:::covered
    E401b:::covered
    MISS:::gap

    classDef covered fill:#1b4332,stroke:#2d6a4f,color:#fff
    classDef gap fill:#7f1d1d,stroke:#b91c1c,color:#fff
```

The red box is the point of the diagram. It is what the human looks at before
signing off, and in the motivating example it is the bug — drawn, visible, and
unticked, before the feature shipped.

Three rules, each forced by something checked rather than assumed:

**Use these four hex values.** Verified with `mmdc`: `classDef` emits
`fill: … !important` on the node rect and `color:#fff !important` on the label,
so the fills survive GitHub's theme CSS. Dark fills with white text read on
both GitHub themes. The pale pastels people reach for — `#d4edda` and its
relatives — are illegible on dark, which is why the skill specifies values
instead of saying "use red and green".

**Colour nodes, not edges.** Mermaid has no per-edge `classDef` that renders
reliably on GitHub. This is the better convention regardless: a test asserts an
*outcome*, so the outcome box is the honest place for the marker.

**Put the criterion in the node label.** `"401 invalid credentials · AC3"`,
not a separate annotation node joined by a dotted edge. Annotation nodes double
the node count and breach the dozen-node limit `design-sketching` already sets.

## The gates

**Authoring sign-off.** One gate, not two. The existing Backlog → Ready ask is
re-pointed: the test plan posts as its own comment, and the ask names every
waived mode, so the human's move to Ready *is* the test sign-off.

> #7 is written: <url>
>
> The test plan is comment 4. Before you move it to Ready, read it as the
> definition of done — if a test is missing there, it will not be written.
>
> Three failure modes found, two covered:
>  ✓ blank name → 422
>  ✓ provider timeout → 503, no partial write
>  ✗ concurrent PATCH on the same row — out of scope, pre-existing, no test.
>
> Agree?

**Refinement.** Three checks join the step-2 ladder at the same strength as the
existing "every criterion has a test". Each is a *not ready* verdict:

- Criteria are all happy-path and no reason is stated.
- An input-domain dimension is unanswered for an identifier-like input.
- A red node on the diagram is unaccounted for in the body.

**Comments.** Each axis posts as its own comment; the body stays canonical and
the agreed result is folded in. This preserves the model in
`references/comments.md` rather than inverting it — comments hold the argument,
the body holds the result.

## Skip rules

Written visibly into each section, so a skipped section is a readable decision
rather than a hidden conditional.

| Section | Skipped when |
|---|---|
| Parity | nothing sits alongside the feature |
| Coverage diagram | fewer than two failure paths |
| Behavioural interview | complexity is trivial **and** nothing on `models.escalateOn` is touched |
| Failure modes | never — but "none, because this is a static string change" is a passing answer |

No new config block. These additions are the behaviour the plugin should always
have had, and a default-off switch would leave the defect in place for anyone
who never configures it.

## The cost, stated plainly

Tickets get meaningfully slower to write. The input-domain pass turned one
field into five criteria in the example above, and that is one field of one
feature.

That is the trade being made deliberately, and the skip rules are where it
stays proportionate. If it proves too heavy in practice, the first lever is to
narrow axis 2 to identifier-like inputs — emails, usernames, slugs, codes —
rather than every input the feature accepts. That change is one sentence in
`interview.md` and does not disturb anything else in this design.

## Out of scope

- No change to `red-green`. It consumes the test plan and does not care how the
  plan got better.
- No change to `review-handoff` or its inventory script. The plan's format is
  unchanged — more lines, same shape.
- No new config block, per the skip-rule decision above.
- No change to the `comments.md` body-is-canonical model.
