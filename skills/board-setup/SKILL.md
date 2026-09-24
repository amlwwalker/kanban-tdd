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
