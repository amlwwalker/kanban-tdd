# Migrating from the Hiway standards skills

If you installed the Hiway standards repo with `standards/claude/install.sh`,
three of its skills now overlap with this plugin and will compete for the same
triggers. This is how to switch across cleanly.

**Do the removal first, then install.** Two skills that both answer "file a
ticket" means neither is reliably the one that runs.

---

## What clashes, and what does not

| Hiway skill | Status | Why |
|---|---|---|
| `write-ticket` | **Remove** | Folded into `ticket-authoring`, which keeps the type decision tree, service-from-git-remote, priority with stated reasoning and the tester block, and adds a user-story gate and criteria bound to tests. |
| `ship-pr` | **Remove** | Folded into `review-handoff`, including the merged-PR preflight, the `Refs` not `Closes` rule and the two-part Testing section. |
| `promote-release` | **Remove** | Folded into `release-to-production`, including both promotions and the batched board moves. |
| `bootstrap-machine` | **Remove** | Not ported. `/plugin install` handles distribution, and the useful checks (gh scopes, the deny block) moved into `board-setup` and `standards-init`, where they run at the moment they matter. |
| `weekly-settlement` | **Keep** | Business logic, not process. Nothing here replaces it. |
| `wallet-design-bundle` | **Keep** | Same. |
| The global `CLAUDE.md` | **Keep for now** — see below | |

---

## 1. Check what you have

`install.sh` creates **symlinks**, so removal is a matter of deleting links
rather than files. Nothing in the standards repo is touched.

```bash
ls -la ~/.claude/skills/ | grep -E "write-ticket|ship-pr|promote-release|bootstrap-machine"
```

Each line should end in `-> …/standards/claude/skills/<name>`. If one is a
real directory rather than a symlink, someone copied it by hand — move it
aside rather than deleting, so nothing is lost:

```bash
mv ~/.claude/skills/write-ticket ~/.claude/skills/write-ticket.bak
```

## 2. Remove the four that clash

```bash
for s in write-ticket ship-pr promote-release bootstrap-machine; do
  [ -L "$HOME/.claude/skills/$s" ] && rm "$HOME/.claude/skills/$s" && echo "removed $s"
done
```

Only symlinks are removed — the `[ -L ]` test means a real directory is left
alone and reported by its absence from the output.

Confirm the business-logic skills survived:

```bash
ls ~/.claude/skills/
```

## 3. Install this plugin

```
/plugin marketplace add amlwwalker/kanban-tdd
/plugin install kanban-tdd
```

Restart Claude Code so the skill list is re-read.

## 4. Set up the repos

If your repos live together in one folder — which is the usual Hiway layout —
do the whole directory in one pass from the **parent**:

```bash
cd ~/dev/hiway
```
```
/org-setup
```

It surveys every repo below, asks the shared questions once, and batches the
one thing that genuinely differs per repo: the test command. It never invents
one, so a repo with no test setup gets no `tests` block and is named in the
report rather than given a command that fails on first use.

For a single repo — or one that lives somewhere else — use:

```
/board-setup
```

Either way it reads your live board rather than assuming, so it picks up the
seven columns the Hiway flow uses. Answer the questions with what the Hiway standards
already decided, and they become config rather than skill text:

| Hiway had | Answer with |
|---|---|
| 13 `svc:` labels | the repo-to-service map, when asked about taxonomy |
| P0–P5 with definitions | the priority levels, and **P2 as the default** |
| The seven-status lifecycle | "a PR per environment" when asked how you ship |
| The named tester block | the four names, when asked about testers |
| BetterStack, the logger call | the logging interview in section 3c |

The `readyForProd` gate behaves exactly as the Hiway design specified: a
production promotion PR carries only cards a human moved there after testing
on staging.

## 5. The global CLAUDE.md

Hiway's `~/.claude/CLAUDE.md` is a symlink into the standards repo and covers
more than this plugin does — security, secrets, logging, style. **Keep it.**

Two things in it are now also enforced by skills, so they can be shortened to
a pointer rather than repeated in full:

- The ticket and PR process, which `feature-workflow` and its skills own.
- The TDD loop, which `red-green` owns, including making the red commit
  checkable rather than only stating the rule.

Everything else — the secrets rules, the `permissions.deny` block, the
build-config-is-security-sensitive rule, British English, no em dashes —
should stay exactly where it is. If you would rather rebuild it as an
interview than edit it by hand:

```
/standards-init
```

That writes a CLAUDE.md from answers you give, and mirrors the
machine-readable parts (logging, API conventions, style) into
`.claude/workflow.config.json` so skills can act on them.

## 6. Check nothing is competing

Ask for something that would have triggered the old skills:

> file a ticket for the thing we just fixed

You should see `ticket-authoring` run, starting with the user story rather
than going straight to labels. If you see `write-ticket`, a symlink survived —
check step 2 and restart.

---

## What you gain

The three absorbed skills kept everything that made them good. What is new:

- **The user story is a gate.** No technical design until the story is agreed.
- **Every acceptance criterion has a test**, and refinement rejects a ticket
  with an orphaned one.
- **The red commit is evidence.** `test(red):` alone, watched failing,
  never squashed — and `review-handoff` checks the log rather than trusting it.
- **A failure path.** A failed manual check labels the ticket, sends the card
  back to In progress, and the fix starts with a red test reproducing it.
- **Logging as a design question**, answered in the ticket rather than
  remembered at review.
- **`ghboard`**, a tested CLI for the board, with cross-repo scoping so one
  board can serve several repos without commands acting on the wrong card.

## What you lose

Nothing that was not replaced, with one exception worth stating: Hiway's
`write-ticket` filed every ticket to one fixed tracker (`HiwayDev/Hiway`).
This plugin resolves the repo from git and the board from config, so a shared
board is supported but the destination is no longer hardcoded. If you rely on
filing from an unrelated repo into that tracker, set `project.owner` and
`project.number` the same in each repo's config — see
[One board, several repos](README.md#one-board-several-repos).
