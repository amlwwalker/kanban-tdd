# Choosing a model

Two different questions, answered from two different places in the config.

**Implementation** varies per ticket, because difficulty does — so it comes
from `models.byComplexity` and the ticket's own complexity rating.

**Everything else** is a phase, and the phases differ from each other far more
than they differ ticket to ticket — so they come from `models.byPhase`.

| Phase | Key | What runs there | Why it sits where it does |
|---|---|---|---|
| Design | `design` | The story interview, `ticket-authoring` | **The worst place to economise.** A bad ticket is not caught by tests; it is built correctly and then rewritten. Every downstream cost is set here. |
| Refinement | `refinement` | `ticket-refinement` | Judgement about readiness, mostly reading. A mid tier is usually right. |
| Implementation | *(from complexity)* | `red-green` | Varies per ticket. This is the only phase whose model should change between tickets. |
| Review | `review` | `review-handoff` | Checking evidence and building the inventory. Mid tier. |
| Release | `release` | `release-to-production` | Mechanical, but the consequences are production. Mid tier, not the cheapest. |
| Triage | `triage` | `triage` | Reading and labelling. The cheapest phase, and the safest to run small. |

A key that is absent means **make no suggestion for that phase**. Silence is
better than a guess here.

## Saying it

At the start of a phase, when `byPhase` names a model for it and it differs
from the session's current one, say so in a sentence and — unless
`models.confirm` is `never` — ask:

> Design work is configured for `claude-opus-5`, and this session is on
> Sonnet. The ticket interview is where a wrong decision is most expensive,
> since tests do not catch a badly-framed ticket. Switch with `/model`, or
> carry on with Sonnet?

Once per phase, not per question. Then proceed on whichever they choose — do
not re-ask, and do not refuse to work on the model they picked.

## What the suggestion is and is not

It is a **token-efficiency guess**, and it is fallible. The user knows things
the config does not: that this area of the codebase is a minefield, that this
ticket is going into a release tonight, that the last attempt at something
similar went badly.

So the framing is always *here is my reasoning, do you agree* — never *this is
the model for this work*. When someone picks a larger model than suggested,
that is the system working. A cheap model doing damage costs far more than the
tokens it saved.

## Why tests do not settle this

It is tempting to think a predefined test plan makes the model choice safe:
the criteria were agreed by a stronger model, so a weaker one cannot narrow
the scope. That much is true, and it is a real protection.

But a green suite does not prove a good implementation. Three things pass:

- **A tautological test.** The assertion recomputes the expected value the way
  the code does, so it cannot disagree with it.
- **Passing by construction.** The implementation special-cases the exact
  inputs the tests use rather than implementing the rule.
- **Collateral damage.** Every criterion is met and something uncovered is
  broken — a performance cliff, a leaked field on the `neverLog` list, an
  invariant no test asserts.

`red-green` makes the first two harder: a test committed alone and watched
failing is difficult to fake, and the red commit is checkable afterwards. It
does not make them impossible.

Tests are a floor, not a ceiling. That is why the model choice is worth a
sentence of a human's attention, and why `models.escalateOn` overrides
complexity outright for subjects where a wrong answer is silent.
