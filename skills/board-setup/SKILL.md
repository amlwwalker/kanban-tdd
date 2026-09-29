---
name: board-setup
description: Configure a repository for the kanban-tdd workflow — find or create the project board, map its columns, set branch names and test commands, resolve which installed skills provide the delegated capabilities, and write .claude/workflow.config.json. Run once per repo before the other skills are used.
disable-model-invocation: true
---

# Board setup

Writes `.claude/workflow.config.json`, the one file that binds these
repo-agnostic skills to this repository. Everything that varies between
projects lives there; the skills themselves never change.

Prompt-driven, not a script. Explore, present what you found, confirm, then
write. Lead each question with a recommended answer so it can be accepted in a
word, and skip any question exploration already settled.

## 1. Check the tools

```bash
command -v gh jq
gh auth status
```

`gh` needs the `project` scope to read a board:

```bash
gh auth refresh -s project
```

Without `gh`, setup can still write the file — say that board validation is
deferred, and that the workflow will run in local mode until it is available.

## 2. Explore

Do not assume; read.

```bash
git remote -v
gh repo view --json nameWithOwner,defaultBranchRef
git branch -r
gh project list --owner "@me" --limit 20
ls Makefile package.json go.mod pyproject.toml Gemfile 2>/dev/null
cat .claude/workflow.config.json 2>/dev/null     # already set up?
```

Also note which capability providers are available in your skills list:
`grilling`, `tdd`, `to-tickets`, `code-review` (mattpocock-skills);
`superpowers:brainstorming`, `superpowers:test-driven-development`.

## 3. Ask, in order

**The board.** Ask rather than assume, because **one board often tracks
several repos** and that is a supported setup, not an edge case. A team board
called "Q3 delivery" is a perfectly normal answer here.

If `gh project list` shows an obvious match, propose it — but say what you are
proposing and offer the alternative in the same breath:

> I found a board called `kanban-sandbox` (#6). Use that, or is this repo
> tracked on a shared team board? Give me its number or URL if so.

Otherwise take a number or URL, or offer to create one:

```bash
gh project create --owner "@me" --title "<repo name>"
```

The board's owner need not be the repo's owner: a personal board can track
org repos and vice versa. Set `ownerType` to whichever the **board** belongs
to — `gh` uses it to pick the right GraphQL root, and getting it wrong
produces a confusing "could not resolve to a ProjectV2".

For an org board:

```bash
gh project list --owner <org-login> --limit 20
```

If the board already has cards from other repos, say so — it confirms the
shared setup and reassures the user that their existing work is safe:

> Board #12 already has 14 cards, from `acme/api` and `acme/web`. Commands
> here will be scoped to this repo; `ghboard list --all` shows everything.

Read the live Status options rather than assuming the defaults:

```bash
gh project field-list <number> --owner <owner> --format json \
  | jq -r '.fields[] | select(.name=="Status") | .options[].name'
```

Four phase keys are always needed — `backlog`, `ready`, `inProgress`, `done`.
Their display names are yours: a board calling them "Icebox / Up next /
Building / Shipped" works fine.

What sits **between `inProgress` and `done`** is the one real choice here, and
it follows from how the team ships rather than from the board. Ask it that way:

> **Do you open a PR per environment, or merge once and deploy from there?**
>
> **(a) One integration branch.** Work merges to `dev`, a human tries it there,
> and production follows. One review column, `inReview`. This is the common
> case and the default.
>
> **(b) A PR per environment** — `dev`, then `staging`, then production. Three
> columns: `pushedToDev`, `pushedToStaging`, `readyForProd`.

Option (b) earns its extra columns through `readyForProd` specifically. **A
human moves a card there after testing it on staging, and a production
promotion PR carries only cards sitting in that column.** That stops a
half-tested ticket riding along with somebody else's release, which is the
failure a single review column cannot prevent. Say that when offering it —
otherwise (b) reads as more admin for no gain.

Both may coexist if the board genuinely has all four. Declare only the columns
that exist; `ghboard validate` checks the declared ones and reports which flow
the config describes.

If a needed column is missing from the board, say which phase has nowhere to
live and offer to add it. Do not silently collapse two phases into one — the
gates between them are the process. Adding a Status option:

```bash
# Read the field id first, then add options with the GraphQL mutation.
gh project field-list <number> --owner <owner> --format json \
  | jq -r '.fields[] | select(.name=="Status") | .id'
```

Note that `updateProjectV2Field` replaces the whole option list, so include the
existing options alongside the new ones or you will delete columns that have
cards in them.

**Branches.** Propose `production` = the repo's default branch, `integration` =
`dev` if it exists. If there is no integration branch, say plainly that the
whole flow depends on one and offer to create it:

```bash
git checkout -b dev main && git push -u origin dev
```

**Test commands.** Infer from what is present — a `Makefile` with `test`
targets, `package.json` scripts, `go.mod`. Propose one entry per suite and
confirm each actually runs before writing it:

```bash
make test-backend      # does this exist and exit 0?
```

Prefer a make target or npm script over a raw `go test` / `vitest`, and say
why: the configured command is what CI runs, and a raw invocation is how local
and CI drift apart. Ask for `ciCommand` if the project has a single CI entry
point.

**Capabilities.** This is the one moment where the whole picture is worth
showing, because it is the only time the user is thinking about setup rather
than about their feature. Later prompts have to be brief; this one does not.

Resolve each of `design-interview`, `tdd-discipline`, `ticket-slicing` and
`code-review` against what is actually installed, then **show a table** — what
each capability does, what is covering it now, and what the preferred provider
would add:

> **Capabilities.** This plugin owns the board and the red→green evidence. The
> thinking is delegated to skills you install separately — here is what I found:
>
> | Job | Covered by | Best available |
> |---|---|---|
> | Design interview | `superpowers:brainstorming` ✓ | `grilling` — also writes ADRs and a glossary |
> | TDD discipline | `superpowers:test-driven-development` ✓ | `tdd` — seams, anti-patterns, vertical slices |
> | Ticket slicing | *nothing* — built-in fallback | `to-tickets` — tracer bullets with blocking edges |
> | Code review | `/code-review` ✓ | `code-review` — standards and spec, in parallel |
>
> The preferred column is all from **Matt Pocock's skills**, which this plugin
> was built against:
>
> ```
> claude plugins install mattpocock-skills
> ```
>
> **Nothing here is required** and nothing is blocked without it — the built-in
> fallbacks work, they are just thinner. Install it now and I will record the
> stronger providers; otherwise I will record what you have and you can rerun
> `/board-setup` any time to upgrade.

Adapt the table to what is genuinely installed. A row where the preferred
provider **is** present says so and needs no suggestion.

Then record what resolved. Leave `"auto"` only where nothing was found and the
user did not choose — the consuming skill will ask at the moment it first
needs it, which is a better moment to decide than now.

If the user installs mid-session, say plainly that new skills may not be
visible until the session restarts, and offer to record the intended provider
anyway so the config is right on restart.

For `ui-style` there is no default. Ask whether they have a house design skill;
if not, omit the key entirely rather than writing a placeholder.

**Environments.** Where can a human try the integration branch? A null URL is
honest and fine — manual checklists will say the URL is unknown rather than
writing "open dev".

## 3b. The optional blocks — ask only what earns its place

Everything above is needed for the workflow to run. What follows is not, and a
solo project on one repo should never be asked about most of it. **Offer the
whole set in one line and let them pick**, rather than walking through seven
interviews nobody asked for:

> That is enough to work. Five more things can be recorded, each optional —
> say which, if any, are worth it here:
>
> - **Ticket classification** — type / service / area labels, so a tracker with
>   more than a handful of tickets stays filterable. Worth it once more than
>   one repo or more than two people file tickets.
> - **Priority and size** — as project fields, with definitions.
> - **Named testers** — a sign-off checkbox per person on every ticket.
> - **Complexity, model routing and epics** — size says how much, complexity
>   says how hard, and the model to use follows from complexity. Epics let a
>   big ticket become real GitHub sub-issues that can be worked in parallel.
>   Worth it once tickets vary enough that one model is wrong for most of them.
> - **Logging and API conventions** — so a ticket's design says what a feature
>   logs and which error shape it returns, rather than that being remembered at
>   review. The biggest one, and the one most worth doing on a backend.
> - **House style** — British or American, em dashes, anything else.

Take only the ones they pick. For each, the questions:

**Ticket classification.** Types first — offer `bug`, `feature`, `task`,
`security`, `docs`, `idea` and ask which exist as labels on their tracker
today. Where a label does not exist, record `null` rather than inventing one:
the skill will put the type in the title and say so, which is honest, whereas
`gh label create` as a side effect of filing a ticket is not.

Services next. Read the repos they file from and propose a map from repo name
to service name. **This is inferred from the current repo's git remote at
ticket time**, which removes the commonest source of mislabelling — so the map
matters more than it looks. Ask about areas last; they span services by design
and many teams have none.

**Priority.** Ask for the field name, then the levels **and what each means**.
Push back on definitions that cannot be disagreed with: "high" is not a
definition, "production down, data loss, or revenue blocked" is. Then ask for
the default, and say why it matters:

> Which level is the default? Make it a middle one. A default of the top level
> is how every ticket becomes top priority and the field stops telling anyone
> anything.

**Size.** Only if they want it. Ask for an anchor per size — a real ticket
number from their board. "Comparable to #237" is checkable; "medium" is not.

**Testers.** Names, and GitHub logins if they want @-mentions.

**Complexity.** Offer three or four levels and push for definitions about the
*reasoning* required, not the line count. A useful set looks like: trivial
"obvious once located, one file, no design decisions"; moderate "several places
must agree, but failure is loud"; hard "touches an invariant other code depends
on, and getting it wrong fails silently".

Create the project field if it does not exist, the same way as Priority.

**Model routing.** Only ask once complexity exists — without it there is
nothing to route on. Propose a mapping from the current model line-up and let
them correct it, since names change:

> Which model for each complexity? A reasonable default is Haiku for trivial,
> Sonnet for moderate, Opus for hard. And which subjects should always escalate
> a tier regardless — I would suggest security, auth, data migrations and
> concurrency, because a cheap model on a cheap-looking auth change is the
> expensive mistake.

Say plainly that the plugin **records** the choice and never switches the model
itself; the human switches with `/model`.

**Epics.** Ask whether big tickets should become GitHub sub-issues, and at what
threshold to propose it — a size, a criteria count, or a number of services
spanned. Stress that a breach only starts a conversation:

> These are prompts, not rules. A large ticket that is genuinely one coherent
> change should stay one ticket — splitting it produces children nobody can
> review on their own.

**Logging.** See section 3c — it is the longest and the most valuable.

**API conventions.** Ask only on a project that serves an API: the error body
shape as a literal example, which status for a validation failure versus a
malformed body, whether internal errors leak any detail, and how partial
update is expressed. Each answer becomes something `ticket-authoring` can
check a design section against.

**Style.** British or American; em dashes allowed or forbidden.

## 3c. The logging interview

Worth doing properly, because it is what turns logging from an afterthought
into part of the design. Once recorded, `ticket-authoring` asks of every
feature *what does this log, at what level, and what must it never log* — and
`red-green` writes the real call instead of a bare `console.log`.

Read the codebase first and propose from evidence rather than asking blind:

```bash
grep -rlE "winston|pino|bunyan|zap|logrus|slog|structlog|log4j" --include=package.json --include=go.mod --include=pyproject.toml . 2>/dev/null | head
grep -rhoE "(logger|log)\.(debug|info|warn|error)\(" --include=*.ts --include=*.js --include=*.go --include=*.py . 2>/dev/null | sort | uniq -c | sort -rn | head -5
```

Then six questions, each with a proposal attached:

1. **Where do logs end up so they can be queried later?** A hosted service, a
   file, a collector — or nowhere, and they stay on the console. Null is a fine
   answer and a better one than a guess. A log nobody can query after the fact
   is not much use, and saying so is more useful than pretending otherwise.

2. **What is the exact call?** One line, copied verbatim — `logger.info(msg,
   ctx, meta)`, `this.logger.logInfo(message, context, meta)`, `slog.Info(msg,
   "k", v)`. Skills copy this rather than inventing an idiom per file. If the
   grep above found a dominant form, propose it.

3. **What does each level mean here?** Teams genuinely disagree about where
   INFO ends and DEBUG begins, so record their answer rather than a textbook
   one. Offer as a starting point: DEBUG local diagnosis, off in production ·
   INFO something happened that someone may later ask about · WARN recovered,
   but a human should know · ERROR the operation failed.

4. **What gets a log line as a matter of course?** API calls, user actions,
   state changes, errors, slow requests. These become the design questions
   `ticket-authoring` asks of any feature that touches them.

5. **What must never be logged, at any level?** Propose tokens, passwords, full
   JWTs, API keys, session cookies, card details, and anything read from a
   credential file. Let them add.

6. **What is sanitised automatically, and what is not?** Ask for the gaps
   explicitly. "The backend redacts known fields, the frontend redacts nothing"
   is the single most useful sentence a logging policy can contain, because it
   tells everyone where care is actually required.

If they decline the whole block, record nothing rather than a default. A
logging policy nobody agreed to is worse than none: skills would cite it as
though it were decided.

## 4. Write it

**Read `references/workflow.config.schema.json` in this skill directory before
writing anything.** It is the authority on the file's shape, and the shape is
not guessable — `ghboard` reads specific paths (`.project.columns.backlog`,
`.tests.<name>.command`, `.capabilities.<name>.provider`) and a
plausible-looking structure with different key names fails at the first
command. Do not reconstruct it from this document or from memory.

The exact skeleton, which every key below must match:

```json
{
  "$schema": "https://raw.githubusercontent.com/amlwwalker/kanban-tdd/main/skills/board-setup/references/workflow.config.schema.json",
  "project": {
    "owner": "<login>",
    "ownerType": "user",
    "number": 0,
    "url": "https://github.com/users/<login>/projects/0",
    "statusField": "Status",
    "columns": {
      "backlog": "Backlog",
      "ready": "Ready",
      "inProgress": "In progress",
      "inReview": "In review",
      "done": "Done"
    }
  },
  "branches": {
    "production": "main",
    "integration": "dev",
    "featurePrefix": "feature/"
  },
  "tests": {
    "unit": {
      "dir": ".",
      "command": "npm test",
      "glob": "src/**/*.test.js",
      "language": "vitest"
    }
  },
  "capabilities": {
    "design-interview": { "provider": "auto" },
    "tdd-discipline":   { "provider": "auto" }
  },
  "labels": { "verificationFailed": "verification-failed" },
  "environments": { "dev": { "url": null } }
}
```

The optional blocks from 3b and 3c, when taken, sit alongside those at the top
level. Include only the ones actually answered:

```json
{
  "taxonomy": {
    "typeLabels": { "bug": "type:bug", "feature": "type:feature", "task": null },
    "serviceLabels": { "prefix": "svc:", "map": { "my-backend": "backend" } },
    "areaLabels": { "prefix": "area:", "values": ["billing", "auth"] },
    "titlePrefix": true
  },
  "priority": {
    "field": "Priority",
    "default": "P2",
    "levels": { "P0": "Production down, data loss, security, or revenue blocked." },
    "requireReasoning": true,
    "securityIsAlways": "P0"
  },
  "size": { "field": "Size", "values": ["XS", "S", "M", "L"], "anchors": { "S": "like #237" } },
  "testers": [ { "name": "Alex Walker", "github": "amlwwalker" } ],
  "logging": {
    "sink": "the hosted log service, or null if console only",
    "callPattern": "logger.info(message, context, meta)",
    "levels": { "INFO": "something happened someone may later ask about" },
    "logByDefault": ["api-calls", "user-actions", "state-changes", "errors"],
    "neverLog": ["tokens", "passwords", "full JWTs", "session cookies"],
    "sanitisation": "backend redacts known fields; frontend redacts nothing"
  },
  "apiConventions": {
    "errorShape": "{\"error\": \"...\", \"details\": {\"field\": \"...\"}}",
    "statusCodes": { "validation": "422", "malformed": "400" },
    "internalErrorsLeak": false,
    "partialUpdate": "PATCH with pointer fields; PUT with plain values",
    "listsAreNeverNull": true
  },
  "diagrams": { "validateWith": "none", "requiredWhen": ["crosses-service", "bug-in-multi-step-flow"] },
  "style": { "english": "british", "emDashes": "forbidden" }
}
```

A `null` in `typeLabels` is meaningful: the type exists as a concept but has no
label on the tracker yet, so it goes in the title instead. Do not replace a
`null` with an invented label.

Note the shapes that are easy to get wrong: `tests` is an **object keyed by
suite name**, not an array; each capability is an **object with a `provider`
key**, not a bare string; `columns` lives **under `project`**; and
`featurePrefix` is required.

```bash
mkdir -p .claude
```

Show the file before writing, and let them edit. Then confirm it parses and
that the keys resolve:

```bash
jq -e '.project.columns.backlog, .branches.integration,
       (.tests | keys[0])' .claude/workflow.config.json
```

## 5. Install the ghboard shim

Every skill writes `ghboard <command>` as a bare name, and the real script
lives inside the plugin where nothing can find it. Write a one-line shim into
the repo so the bare name resolves for both Claude and the human:

Try each plausible location rather than hardcoding one. `CLAUDE_PLUGIN_ROOT`
is set when a skill invokes the shim but **not** when a human runs it from
their own shell, and the install path differs between a marketplace install
and a local `--plugin-dir` checkout. A shim that guesses one path and `exec`s
it blindly fails later with a confusing error that looks like a board problem.

```bash
mkdir -p .claude/bin
cat > .claude/bin/ghboard <<'SHIM'
#!/usr/bin/env bash
# Shim: the real script ships inside the kanban-tdd plugin. Regenerate with
# /board-setup if the plugin moves.
for root in \
  "${CLAUDE_PLUGIN_ROOT:-}" \
  "$HOME/.claude/plugins/cache/amlwwalker/kanban-tdd" \
  "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/../kanban-tdd"
do
  [ -n "$root" ] || continue
  if [ -x "$root/skills/feature-workflow/scripts/ghboard" ]; then
    exec "$root/skills/feature-workflow/scripts/ghboard" "$@"
  fi
done
echo "ghboard: cannot find the kanban-tdd plugin. Rerun /board-setup." >&2
exit 127
SHIM
chmod +x .claude/bin/ghboard
```

Add any other root you actually found during exploration. The last entry
covers a sibling checkout, which is how the plugin looks when run with
`--plugin-dir` rather than installed.

Check it resolves, and say plainly if it does not — a shim pointing at a
missing file is worse than no shim, because the failure appears later and
looks like a board problem:

```bash
.claude/bin/ghboard --help >/dev/null && echo "shim ok"
```

Tell the user to add it to their PATH for interactive use, and that skills
find it either way:

```bash
export PATH="$PWD/.claude/bin:$PATH"     # or add to .envrc / shell profile
```

**Commit the shim, in the same commit as the config.** Not optional, and not
"suggest it later". An untracked `.claude/bin/ghboard` disappears the moment
anyone checks out a different branch — which is the very next thing that
happens, when work starts and a feature branch is cut. The failure then looks
like the plugin is broken rather than like a file that was never tracked.

```bash
git add .claude/workflow.config.json .claude/bin/ghboard
```

It is a dozen lines, and it means a colleague who clones the repo needs
nothing but the plugin.

If the repo's `.gitignore` excludes `.claude/`, say so and ask before adding
a negation — some teams deliberately keep that directory local, and that is
their call, not yours:

```gitignore
!.claude/workflow.config.json
!.claude/bin/ghboard
```

## 6. Validate against the live board

```bash
.claude/bin/ghboard validate
```

This is the step that catches a typo in a column name. If it fails, fix the
config — do not create columns to match a possible typo. A mistyped name and a
genuinely missing column look identical from here, and one is fixed by editing
a file while the other needs a human decision.

## 7. Offer the CLAUDE.md snippet

The process lives in the skills, so this stays short. Offer to append:

```markdown
## How this project is built

Work is tracked on [the board](<url>) and follows the `kanban-tdd` plugin:
a ticket before code, the user story agreed before the technical design, a
failing test committed before the code that passes it, and a written manual
step for anything only a human can confirm.

Start anything — a feature, a bug, a loose idea — with `feature-workflow`.

Project specifics that the plugin cannot know:

- <test framework constraints, e.g. "backend tests are Go's standard testing
  package, never testify">
- <directory conventions>
- <anything a newcomer would get wrong>
```

Keep it to that shape. Rules that belong to the process are already in the
skills and travel with the plugin; a copy in CLAUDE.md is a second source of
truth that will disagree after the first update.

## 8. Say what to do next

```bash
ghboard list        # see the board
ghboard next        # what to pick up
```

Then say the thing that actually matters for a first-time user: **they do not
invoke skills by name.** Describing a feature in their own words — "I want
users to be able to reset their password" — is what starts the flow, and the
first thing that happens is an interview, not code.

Then `feature-workflow` for anything else.
