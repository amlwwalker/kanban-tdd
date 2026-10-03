# Contributing

Written for whoever picks this up next, which is usually a Claude instance. It
records the things that are not visible from reading the code, and the two
mistakes that cost real time.

---

## Release: bump `version`, or nobody gets it

**This is the one that silently wastes a release.**

Claude Code reads `version` from `.claude-plugin/plugin.json` first, and **a
pinned version keeps every installed user on their cached copy however many
commits you push.** Merging to `main` is not a release. Bumping the version is.

```jsonc
// .claude-plugin/plugin.json
"version": "0.4.0"      // ← change this, or the push reaches nobody
```

So, for any change users should receive:

1. Bump `version` in `.claude-plugin/plugin.json`.
2. Mention the upgrade path in the README if the change needs action from them.
3. Merge.

Users then run `/plugin update kanban-tdd@amlwwalker` and `/reload-plugins` —
**third-party marketplaces do not auto-update by default**, so nothing arrives
on its own.

The alternative is removing `version` from both `plugin.json` and
`marketplace.json`, which makes Claude Code fall back to the commit SHA and
gives users every push automatically. That is deliberately *not* what this repo
does: a pinned version is what lets a half-finished change sit on `main`
without shipping.

## Register a new skill in two places

A skill directory that exists but is not listed **does not load**, and nothing
warns you.

1. `.claude-plugin/plugin.json` → the `skills` array
2. `README.md` → the skills table

```bash
# Catches both halves of the mistake.
jq -r '.skills[]' .claude-plugin/plugin.json | while read -r s; do
  [ -f "${s#./}/SKILL.md" ] || echo "registered but missing: $s"; done
for d in skills/*/; do n="./${d%/}"
  jq -e --arg n "$n" '.skills|index($n)' .claude-plugin/plugin.json >/dev/null \
    || echo "present but unregistered: $n"; done
```

---

## Writing a skill

**The frontmatter `description` is the whole routing mechanism.** It is what
decides whether the skill fires, so it carries three things: what the skill does,
when to use it, and a `Triggers on "…", "…"` list of the words a person would
actually type. A skill with a tidy description nobody says out loud never runs.

**Say why, not just what.** Every rule in these skills should carry the reason
it exists, because a rule without one gets dropped the first time it is
inconvenient. "Commit the test alone" is a rule. "Commit the test alone, because
a reviewer must be able to check out that commit and watch it fail" survives
contact with a deadline.

**State what the skill will not do.** Every skill ends with that list. It is the
most load-bearing section: it is what stops a model being helpful in the one way
that breaks the process.

### Enforce a gate where the work happens, not only upstream

**This is the mistake that has actually escaped.** A ticket was implemented
straight out of Backlog, skipping the human approval gate entirely, because:

- the Ready gate lived in `ticket-authoring` and `ticket-refinement`, both
  *upstream* of implementation
- "implement #1448" matched `red-green`'s triggers much more strongly than
  `feature-workflow`'s, which were all vague phrasings
- so the router was bypassed exactly when the request was most specific, and
  `red-green` never checked the column

A gate enforced only in the skill that *usually* runs first is not a gate — it
is a convention that holds until someone phrases a request precisely. Ask of
every rule: **if a user jumps straight to the skill that does the work, does
anything still stop them?** If not, the check belongs in that skill too.

The same reasoning applies to triggers. A skill that should own an entry point
needs the *specific* phrasings as well as the vague ones, or the precise request
routes past it.

**Prose wraps at ~78 columns.** Tables, code blocks and frontmatter do not.

**British spelling**, except where a technical identifier demands otherwise —
CSS `color`, JSON keys, API fields.

**Long reference material goes in `references/`**, not inline. A `SKILL.md` past
~500 lines stops being navigable; `ticket-authoring` and `design-sketching` both
show the split.

### Capabilities, not providers

Skills name a **capability** (`tdd-discipline`) and never a provider (`tdd`).
Resolution is config → detect → ask once → record, and every capability has a
built-in fallback so the workflow runs with nothing else installed. See
`references/capabilities.md`.

A hard dependency on another plugin would mean a colleague's first ticket hits a
dead end. Do not add one.

### Config blocks are optional by default

Every block in `workflow.config.json` that a small project does not need should
be **skippable in silence** — `priority`, `logging`, `epics`, `browser` all work
this way. A skill reads the block, finds nothing, and moves on without comment.

New config goes in `skills/board-setup/references/workflow.config.schema.json`
with a `description` that says *why* the setting exists, not just what it is.

---

## Scripts

**Target bash 3.2.** macOS ships it, and it has **no `mapfile` and no
associative arrays** — both fail at runtime, not at parse time, so they survive
casual testing on a machine with a newer bash in `PATH`.

```bash
/bin/bash ./skills/.../your-script.sh     # the real test, not `bash`
```

`design-anchors.sh` carries a comment saying this. Do not "modernise" it.

**Verify exit codes, not just output.** Both scripts here are consumed by a gate
that branches on the exit code.

**`gh api` prints its error JSON to stdout on a 404.** So `X="$(gh api … || true)"`
captures `{"message":"Not Found",…}` rather than an empty string, and whatever
you do with `$X` next fails confusingly far from the cause. Validate the shape
of what came back:

```bash
case "$PARENT" in *[!0-9a-f]* | "") PARENT="" ;; esac
[[ ${#PARENT} -eq 40 ]] || PARENT=""
```

This cost a full publish run — twelve blobs uploaded, then a failure about
parent SHA length.

**`jq`'s `//` treats an explicit `null` as absent.** `.x.y // "default"` gives
`"default"` for both a missing key and `"y": null`. Where `null` is a
*deliberate opt-out*, distinguish the three cases by hand:

```bash
jq -r 'if .browser|has("assetsBranch")|not then "default"
       elif .browser.assetsBranch == null then "__DISABLED__"
       else .browser.assetsBranch end'
```

---

## Mermaid

GitHub renders it natively and **fails silently** — a syntax error is a blank
block nobody reports. Validate before merging:

```bash
mmdc -i diagram.mmd -o /tmp/out.svg      # npm i -g @mermaid-js/mermaid-cli
```

Coverage diagrams use four fixed hex values. **Do not substitute pale
pastels** — they are illegible on GitHub's dark theme, where plenty of people
read tickets:

```
classDef covered fill:#1b4332,stroke:#2d6a4f,color:#fff
classDef gap     fill:#7f1d1d,stroke:#b91c1c,color:#fff
```

Colour attaches to **nodes, not edges** — Mermaid has no per-edge `classDef`
that renders reliably on GitHub.

---

## Testing a change

There is no suite. The checks are these, and they are quick:

```bash
jq -e . .claude-plugin/plugin.json .claude-plugin/marketplace.json \
       skills/board-setup/references/workflow.config.schema.json

/bin/bash skills/review-handoff/scripts/design-anchors.sh --list
```

Plus every mermaid block, if you touched one.

**For anything non-trivial, dogfood it.** Create a throwaway private repo, run a
real feature through the gates, then delete it. The last three bugs found in
this plugin were all invisible to fixtures:

- the `gh api` 404-to-stdout problem only appears on the **first** run in a repo
  with no `assets` branch
- two Playwright assertions were wrong in ways that looked right until a real
  browser disagreed

`gh repo delete` needs the `delete_repo` scope, which is usually not on the
token. Ask rather than adding it.

---

## Documentation

**`WALKTHROUGH.md` is a recording, not a brochure.** Its screenshots come from
one real run. When a feature lands that postdates it, add a note saying so
rather than re-staging the images — a reconstruction that claims to be a
recording is worse than an honest gap.

**The README's worked examples are real exchanges.** Do not invent plausible
ones.

---

## Commits and PRs

Conventional prefixes, as the log shows: `feat:`, `fix:`, `docs:`, `test:`, with
an optional scope — `fix(browser-evidence):`.

The body says **why**, and names anything found the hard way. The commit
explaining that `gh api` writes 404s to stdout is worth more than the one-line
fix it accompanies.

**Use a PR; do not push to `main`.** No Claude attribution in commit messages or
PR descriptions.
