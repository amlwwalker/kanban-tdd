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

**The board.** If `gh project list` shows one obviously matching this repo,
propose it. Otherwise ask for the number or URL, or offer to create one:

```bash
gh project create --owner "@me" --title "<repo name>"
```

Read the live Status options rather than assuming the defaults:

```bash
gh project field-list <number> --owner <owner> --format json \
  | jq -r '.fields[] | select(.name=="Status") | .options[].name'
```

Map each to a phase key — `backlog`, `ready`, `inProgress`, `inReview`, `done`.
The five phases are fixed; their display names are not. A board calling them
"Icebox / Up next / Building / Testing / Shipped" works fine.

If the board has fewer than five columns, say which phase has nowhere to live
and offer to add it. Do not silently collapse two phases into one — the gates
between them are the process.

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

**Capabilities.** For each of `design-interview`, `tdd-discipline`,
`ticket-slicing`, `code-review`: if a provider is already installed, record it
and say so in half a sentence. If none is, leave `"auto"` — the consuming skill
will ask when it first needs it, which is a better moment than now.

Mention once, without pressing:

> These skills delegate the thinking — design interviews, TDD discipline, code
> review — to whatever you already use. Matt Pocock's skills
> (`claude plugins install mattpocock-skills`) cover all four and are what this
> was built against; superpowers covers two. Neither is required.

For `ui-style` there is no default. Ask whether they have a house design skill;
if not, omit the key entirely rather than writing a placeholder.

**Environments.** Where can a human try the integration branch? A null URL is
honest and fine — manual checklists will say the URL is unknown rather than
writing "open dev".

## 4. Write it

```bash
mkdir -p .claude
```

Write `.claude/workflow.config.json` with the `$schema` key pointing at the
plugin's copy, so editors give autocomplete and inline docs:

```json
{
  "$schema": "https://raw.githubusercontent.com/amlwwalker/kanban-tdd/main/skills/board-setup/references/workflow.config.schema.json"
}
```

Show the file before writing, and let them edit.

## 5. Validate against the live board

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/feature-workflow/scripts/ghboard" validate
```

This is the step that catches a typo in a column name. If it fails, fix the
config — do not create columns to match a possible typo. A mistyped name and a
genuinely missing column look identical from here, and one is fixed by editing
a file while the other needs a human decision.

## 6. Offer the CLAUDE.md snippet

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

## 7. Say what to do next

```bash
ghboard list        # see the board
ghboard next        # what to pick up
```

Then `feature-workflow` for anything else.
