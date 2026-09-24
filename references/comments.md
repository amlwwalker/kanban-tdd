# Comments are part of the ticket

The body is what someone wrote when the ticket was created. The comments are
where it was argued with. A ticket assessed from its body alone produces a
confident answer about a superseded plan.

## The rule

**Every skill that acts on a ticket reads its comments first.** Before writing
a test, before cutting a branch, before opening a PR, before releasing:

```bash
ghboard read <n>          # body + every comment, in order
```

First action. Not "consider reading", not "read if something seems off". The
cost is one command; the cost of skipping it is building the wrong thing and
finding out at review.

## What to look for, by stage

A comment means different things depending on where the card is.

| Stage | Read for |
|---|---|
| **Backlog** (`ticket-refinement`) | Unanswered questions. A question raised in the body or a comment with no answer is the single most common reason a ticket is not ready. |
| **Ready → In progress** (`feature-workflow`) | Decisions made since the ticket was approved. A scope cut or a changed approach posted after promotion is still binding. |
| **In progress** (`red-green`) | Anything that changes what you are building, at every resume. Between sessions is exactly when comments land. |
| **In review** (`review-handoff`) | A failed manual step, or a question from the verifier. |
| **Done → release** (`release-to-production`) | Late objections. "Actually this broke X" posted after Done is a reason to stop, not a formality. |

## Detecting what you have not seen

At resume, the useful question is not "are there comments" but "are there
comments I have not acted on". Compare against your last commit on the branch:

```bash
ghboard comments <n> --after-commit     # comments newer than HEAD's commit date
ghboard read <n> --since 2026-09-20     # or an explicit cutoff
```

If anything comes back, **surface it before doing anything else**. Summarise
what changed and ask whether it alters the plan. Do not fold a scope change
into the work silently — the person who wrote it wants to know it landed.

## Fold decisions into the body

A decision that exists only in comment #4 is a decision the next person will
miss, because the next person reads the body.

```bash
gh issue edit <n> --body-file <path>
```

Then record that you did, so the edit is not silent:

```markdown
---
_Updated after discussion: visibility is per-user, not global (see comments)._
```

## Say that nothing polls

Nothing watches GitHub. A comment posted mid-session is invisible until the
next `ghboard read`. When you hand a ticket to a human, say so plainly:

> The checklist is on the ticket. Nothing polls GitHub, so comment there and
> then tell me — I will not see it otherwise.

A user who assumes comments are picked up automatically will write one and wait.
