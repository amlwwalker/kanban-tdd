---
name: org-setup
description: Configure every git repository below the current directory for one shared board in a single pass. Interviews once for everything the repos have in common, detects each repo's stack and proposes its test command, and asks only about what genuinely differs. Use when a team keeps many repos in one folder and tracks them all on one project board. Run it from the parent directory, not inside a repo.
disable-model-invocation: true
---

# Org setup

`/board-setup` configures one repository. This configures a directory of them
against one shared board, asking once for everything they have in common.

Run it from the **parent** directory:

```bash
cd ~/dev/acme        # the folder holding the repos, not a repo itself
```

If you are inside a git repository, say so and offer `/board-setup` instead —
the two are not interchangeable, and running this from inside one repo will
try to configure its sibling directories.

## 1. Survey before asking anything

Find the repos and read their stacks. Do not ask a single question until you
can show the user what you found:

```bash
for d in */; do
  [ -d "$d/.git" ] || continue
  printf '%s\t%s\n' "${d%/}" "$(git -C "$d" remote get-url origin 2>/dev/null || echo NO-REMOTE)"
done
```

For each repo, detect the stack and the likely test command:

```bash
jq -r '.scripts.test // empty' <repo>/package.json 2>/dev/null
ls <repo>/go.mod <repo>/Makefile <repo>/pyproject.toml 2>/dev/null
grep -E '^test:' <repo>/Makefile 2>/dev/null
```

Present the survey as a table before anything else, grouped so the shape is
obvious:

> 33 repositories under `~/dev/acme`:
>
> - **18 node** — 12 vitest, 3 jest, 3 with no test script
> - **2 go** with a `make test` target
> - **1 python**
> - **12 with no test setup detected**
> - **1 with no git remote** (`beautful`) — it will be skipped
>
> Everything below is asked once and applied to all of them. I will come back
> to the test commands at the end, since those genuinely differ.

## 2. Ask the shared questions once

This is `/board-setup` section 3, asked **once** rather than per repo. Read
that skill and follow it for the substance of each question; the only
difference is scope.

The board, in particular, is the point of this skill: **one board, many
repos.** Say so explicitly, because it changes what the answers mean:

> All of these will file to the same board. Issue numbers are not unique
> across it, so every command will be scoped to whichever repo you are
> standing in — `ghboard list` shows that repo's cards, `ghboard list --all`
> shows everyone's.

Ask for: the board and its columns, the branch names, capabilities, and then
the optional blocks (taxonomy, priority, size, complexity, models, epics,
testers, style, logging, API conventions).

**Taxonomy deserves care here**, because it is the one shared block whose
value differs per repo. Ask for the service *naming convention* rather than a
list — a prefix, and whether the service name is the repo name, the repo name
minus a prefix, or something else:

> Your repos are `acme-api`, `acme-web`, `acme-worker`. Should the service
> labels be `svc:acme-api` and so on, or drop the common prefix to give
> `svc:api`, `svc:web`, `svc:worker`? I will build the map from the remotes
> either way, so you do not have to list them.

Show the derived map and let them correct individual entries before writing.

Write the **whole** map into every repo, not just that repo's own entry.
`ghboard` scopes its commands by the current repo regardless, so a complete
map costs nothing and means a ticket that references a sibling service
resolves rather than falling back to asking.

## 3. Ask the per-repo questions, batched

Only one thing genuinely differs and cannot be inferred with confidence: **the
test command.** Ask about it in groups rather than one repo at a time.

Propose from what you detected, and group identical proposals:

> **Test commands.** I can infer most of these:
>
> | Repos | Proposed | Confirm? |
> |---|---|---|
> | 12 node repos with `"test": "vitest"` | `npm test`, glob `src/**/*.test.{ts,tsx}` | |
> | 3 node repos with `"test": "jest …"` | `npm test`, glob `**/*.test.js` | |
> | `acme-api`, `acme-worker` (go + Makefile) | `make test`, glob `**/*_test.go` | |
> | 12 repos with nothing detected | **leave `tests` empty** | |
>
> Accept all, or tell me which groups to change.

**Never invent a test command.** For a repo where nothing was detected, write
no `tests` block at all and say which repos those are. A config naming a
command that does not exist fails on first use and looks like the plugin is
broken; an absent block is honest and `/board-setup` can fill it in later.

Where a detected command looks odd — a test script that is a placeholder, or
one pinned to a single file like `vitest tests/http-client.test.ts` — flag it
rather than copying it:

> `acme-sdk` has `"test": "vitest tests/http-client.test.ts"`, which runs one
> file rather than the suite. Use it as-is, or `npm test -- --run` for the
> whole suite?

### Verify before writing

For each distinct command, run it in one repo of its group:

```bash
( cd <repo> && <command> ) >/dev/null 2>&1 && echo pass || echo fail
```

A command that fails is reported, not written. One sample per group is enough;
running 33 test suites to configure a folder is not a good trade.

## 4. Show one config, then write them all

Write out the config for a single representative repo in full and get it
approved. The others differ only in `taxonomy.serviceLabels.map` and `tests`,
so approving one approves the shape of all of them.

Then write each, and the `ghboard` shim alongside it:

```bash
mkdir -p <repo>/.claude/bin
```

Skip any repo that already has a `workflow.config.json` — **never overwrite
one** — and list the skipped ones at the end. Someone configured those
deliberately.

Skip any repo with no `origin` remote and name it, rather than guessing its
service.

## 5. Validate a sample, not everything

```bash
( cd <repo> && .claude/bin/ghboard validate )
```

One repo proves the board mapping, which is the shared part and the thing most
likely to be wrong. Validating all 33 is 33 API round trips to learn the same
fact.

Then check the service map resolves for a couple of others, since that is the
part that differs:

```bash
( cd <other-repo> && .claude/bin/ghboard list )
```

## 6. Report honestly

Say how many were written, how many skipped and why, and name every repo
that needs a human:

> Written: 28. Skipped: 4 already configured (`api`, `web`, `worker`,
> `sdk`), 1 with no remote (`beautful`).
>
> **12 have no test command**, so their `tests` block is absent and
> `review-handoff` will refuse to hand off from them until one exists. They
> are: … Run `/board-setup` in each when you get to it.
>
> **3 are probably out of scope** — `scaffold`, `old-frontend` and
> `spike-branch-thing` have had no commit in over a year. They are configured,
> but you may want to delete the config rather than have them file tickets.

The last two paragraphs matter more than the count. A silent partial success
across thirty repos is how someone discovers in three weeks that half their
tickets went nowhere.

## 7. Committing

Each `.claude/workflow.config.json` and `.claude/bin/ghboard` belongs in its
own repo's git history, so colleagues inherit the setup. That is 30 commits
across 30 repos, which is the user's call and not something to do unasked:

> Each config wants committing in its own repo. Shall I stage and commit them
> all with the same message, open a PR per repo, or leave them for you?

Default to leaving them. Committing to thirty repositories on someone's
behalf is a large, visible action, and several may have branch protection
that turns it into thirty failed pushes.

## What this skill will not do

- Run inside a git repository. That is `/board-setup`.
- Overwrite an existing config.
- Invent a test command for a repo that has none.
- Write a `logging` or `apiConventions` block that was not asked about, on the
  assumption that repos in one folder share a language. They often do not.
- Commit or push anything without being asked.
