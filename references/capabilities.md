# Capabilities

These skills do not own how you think, how you test, or how you review. They
own the board: which column a ticket is in, and what evidence each transition
demands. Everything else is delegated to whichever skill the user has installed.

A **capability** is a job to be done. A **provider** is a skill that does it.
Skills in this plugin name capabilities, never providers, so a team that uses
Matt Pocock's skills and a team that uses superpowers both get a working
workflow without either being forced on them.

## The table

| Capability | Preferred provider | Fallback | Built-in |
|---|---|---|---|
| `design-interview` | `grilling` | `superpowers:brainstorming` | yes, thinner |
| `tdd-discipline` | `tdd` | `superpowers:test-driven-development` | yes, thinner |
| `ticket-slicing` | `to-tickets` | — | yes, thinner |
| `code-review` | `code-review` | `/code-review` (built into Claude Code) | yes, a checklist |
| `ui-style` | config-named only | — | skipped silently |

### Why this order, and when to override it

**With both installed, the preferred column wins.** The order is not a
judgement about which plugin is better in general — it is about which one fits
*this* workflow, where a ticket is the unit of work and evidence is the point:

- **`grilling` over `superpowers:brainstorming`** — it emits ADRs and a
  glossary as it interviews. Those are durable artifacts that outlive the
  conversation, which is what a ticket wants. `brainstorming` runs a good
  interview but leaves nothing behind except the answer.
- **`tdd` over `superpowers:test-driven-development`** — it makes you name and
  confirm the seam before the first test, and its vertical-slice rules map
  directly onto one line of a ticket's test plan.
- **`code-review` over `/code-review`** — it reviews against the originating
  ticket as well as the code, which is the check this workflow cares about.

**This is a default, not a verdict.** A team that prefers the other provider
for any of these should say so, and the way to say so is to name it in the
config rather than argue with a skill mid-ticket:

```jsonc
"capabilities": {
  "design-interview": { "provider": "superpowers:brainstorming" }
}
```

A concrete name in config is obeyed without question — step 1 below. It beats
the preference order, it beats detection, and it never gets re-litigated.
Whoever wrote it had a reason, and a tool second-guessing a recorded decision
every session is worse than one that occasionally uses the wrong interview.

Adding a provider later does **not** silently change anything: config is read
first, so an existing entry keeps winning until someone reruns `/board-setup`
or edits the file. That is deliberate — upgrading your toolchain should not
quietly change how your tickets get written mid-project.

Preferred providers come from `mattpocock-skills`
(https://github.com/mattpocock/skills, MIT). Depending on your install they may
appear bare (`grilling`) or namespaced (`mattpocock-skills:grilling`) — accept
either.

## Resolving one

Three steps. Stop at the first that answers.

### 1. Config

Read `capabilities.<name>.provider` from `.claude/workflow.config.json`.

- A skill name → use it. Do not ask, do not second-guess, do not offer
  alternatives. The user already decided.
- `"builtin"` → use the built-in section in the consuming skill. Do not ask.
- `"auto"` or absent → continue to step 2.

### 2. Detect

Look for the preferred provider in your available skills, then the fallback.

**Found the preferred one** → use it. Say which, in half a sentence: "Using
`grilling` for the design interview." Continue to step 4.

**Found only the fallback** → use it, and **say that the preferred provider is
missing and what it would add**. One sentence, once, not a sales pitch:

> Using `superpowers:brainstorming` for the design interview.
> `mattpocock-skills:grilling` is the stronger option here — it produces ADRs
> and a glossary as it interviews — but superpowers covers this fine.
> `claude plugins install mattpocock-skills` if you want it.

Then continue to step 4 and record the fallback. Do **not** stop and wait for
an answer: a working fallback is not a blocker, and interrupting real work to
upsell a plugin is worse than the gap it fills.

Saying nothing is the failure mode to avoid. A user who silently gets the
weaker provider never learns there is a better one, and never learns why their
interview feels thinner than the documentation describes.

**Found neither** → step 3.

Do not shell out to hunt for skill directories. You either have the skill
available or you do not.

### 3. Ask — once, and only when nothing resolved

Ask a single question, offering three routes. Do not ask again later in the
same session for the same capability.

> This ticket needs a design interview and no provider is installed.
>
> **(a)** Install Matt Pocock's skills — `claude plugins install
> mattpocock-skills` — which brings `grilling`: a relentless interview that
> produces ADRs and a glossary as it goes. Recommended.
> **(b)** Install superpowers for `brainstorming`.
> **(c)** Carry on with the built-in interview, which is shorter and produces
> no durable artifacts.
>
> I will record the choice in `workflow.config.json` so this only comes up once.

If they install something mid-session, it may not be visible until the session
restarts. Say so, and offer to proceed built-in for now.

**Never block on this.** A missing provider degrades the interview; it does not
stop the work. `ui-style` is weaker still — absent, skip it in silence.

### 4. Record

Write the resolved value back:

```bash
jq '.capabilities["design-interview"].provider = "grilling"' \
  .claude/workflow.config.json > /tmp/wc.json \
  && mv /tmp/wc.json .claude/workflow.config.json
```

`"auto"` means "ask me once". Leaving it as `auto` after resolving means asking
again next week, which is how a helpful prompt becomes a nag.

## Invoking a provider

Call the Skill tool with the provider's name. Say what you need from it, because
these are general skills being used for a specific purpose:

> Call the Skill tool with "tdd" — for the seam decision and test quality. The
> red/green commit evidence is this plugin's job, not the provider's.

Providers are references to consult, not sessions that take over. When one
finishes, you are still in the board workflow, and the card still has not moved.

## Why it works this way

Hard-coding `superpowers:brainstorming` in a skill body means a colleague
without superpowers hits a dead end on their first ticket. Naming the capability
means they hit a question with three answers, one of which is "carry on".

The config is the memory. Without it, every session re-asks, and a workflow that
interrogates you about your toolchain before every ticket is one people stop
using.
