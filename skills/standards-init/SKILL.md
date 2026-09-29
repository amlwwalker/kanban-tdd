---
name: standards-init
description: Interview the user and write their engineering standards — security and secrets rules, logging policy, API conventions, TDD discipline, house style — to a global CLAUDE.md or a project one. Use when setting up a machine, writing down how a team works, or when rules that should be shared exist only in one person's head. Run once per machine for the global file, and again per project for anything genuinely project-specific.
disable-model-invocation: true
---

# Standards init

Writes the rules that should apply to every project, or to one project, from
an interview rather than a template. The output is a `CLAUDE.md` the user
agreed to, not a default they inherited and never read.

**Ask, never assume.** Every question below has a house answer somewhere, and
it is rarely the one a template would guess. A standards file full of rules
nobody chose is worse than none: it gets cited as though it were decided.

## 1. Decide where it goes

Two files, and the split matters. Get it wrong and the global file becomes
20KB that nobody reads.

| Goes global (`~/.claude/CLAUDE.md`) | Goes per-project (`./CLAUDE.md`) |
|---|---|
| Security and secrets | The frameworks and idioms of this codebase |
| TDD discipline | Directory layout and where things live |
| Logging *policy* (levels, never-log) | Logging *mechanics* (the module, the import) |
| API conventions | Domain rules and business logic |
| House style | Anything only true here |

Ask which they are writing. If a global file already exists, read it first and
offer to extend rather than replace — and never overwrite without showing the
diff.

## 2. Security and secrets

Ask, but propose these as the baseline. They are dull and they are the part
that matters most:

- **Never print, echo, `cat` or paste the contents of a credential file** into
  a session, a commit, a PR body, or a ticket. Covers `.env*`, key files,
  anything holding a token.
- **Never commit a secret.** If one is found in history, stop and escalate
  rather than quietly rewriting history to hide it.
- **Build config and setup scripts are security-sensitive** — postcss/next/
  vite config, seed and bootstrap scripts, `package.json` scripts, git hooks.
  Any change to them is called out explicitly in the PR body, on its own line.
  This is the file class supply-chain injections use, precisely because nobody
  reads a config diff.
- **No dependency pinned to a mutable ref.** A version or a commit SHA, never
  a branch.
- **Never add a package, plugin or marketplace** without naming it in the PR
  and saying why.
- **Never disable, weaken or delete a test, lint rule or type guard** to make
  something pass. If one is genuinely wrong, change it deliberately and say so.

Then offer the one control that does not depend on a model's cooperation:

> Rules in a CLAUDE.md are instructions I follow. A `permissions.deny` block in
> `~/.claude/settings.json` is enforced by the harness, and it is the only
> control here I cannot talk myself past. Shall I add one for `.env*`,
> `~/.ssh/**`, `~/.aws/**`, `**/id_rsa*` and `**/*.pem`?

Use the `update-config` skill to write it if available, rather than editing
`settings.json` by hand. Show the block and confirm before writing — a deny
rule that blocks something they need is a bad first experience.

## 3. Logging

The longest section, and the one that changes the most behaviour. Read the
codebase before asking, and propose from evidence:

```bash
grep -rlE "winston|pino|bunyan|zap|logrus|slog|structlog|log4j|serilog" \
  --include=package.json --include=go.mod --include=pyproject.toml \
  --include=*.csproj . 2>/dev/null | head
grep -rhoE "(logger|log)\.(debug|info|warn|error)\(" \
  --include=*.ts --include=*.js --include=*.go --include=*.py . 2>/dev/null \
  | sort | uniq -c | sort -rn | head -5
```

Six questions:

1. **Where do logs end up so they can be queried later?** A hosted service, a
   file, a collector — or nowhere, and they stay on the console. **Null is a
   fine answer.** A log nobody can query after the fact is not much use, and
   recording that plainly is more useful than pretending otherwise.

2. **What is the exact call?** One line, verbatim, so skills copy it rather
   than inventing an idiom per file. If the grep found a dominant form,
   propose it.

3. **What does each level mean here?** Teams genuinely disagree about where
   INFO ends and DEBUG begins. Offer as a starting point, and expect edits:
   DEBUG local diagnosis, off in production · INFO something happened that
   someone may later ask about · WARN recovered, but a human should know ·
   ERROR the operation failed.

4. **What gets a log line as a matter of course?** API calls, user actions,
   state changes, errors, slow requests. This list becomes the design question
   `ticket-authoring` asks of any feature that touches one of them.

5. **What must never be logged, at any level?** Propose tokens, passwords,
   full JWTs, API keys, session cookies, card details, and anything read from
   a credential file. Let them add.

6. **What is sanitised automatically, and what is not?** Push for the gaps.
   "The backend redacts known fields, the frontend redacts nothing" is the most
   useful sentence a logging policy can contain, because it says where care is
   actually required rather than implying it is handled everywhere.

Write the answers to `logging` in `.claude/workflow.config.json` as well as the
prose, when that file exists. The skills read the config; the CLAUDE.md is for
the human.

## 4. API conventions

Skip entirely for a project that serves no API.

- **The error body**, as a literal example. One shape everywhere.
- **Which status for which failure** — validation versus malformed versus not
  found versus unauthorised. They are different failures and a caller needs to
  tell them apart.
- **Do internal errors leak detail?** Propose no: logged in full, returned
  bare, with a test asserting nothing leaks.
- **Partial versus full update.** If they have one of PUT/PATCH they almost
  certainly want both, and a test for each.
- **Empty collections** serialise as `[]`, not `null`.

## 5. TDD discipline

Most teams say they do TDD. Ask what they actually enforce:

- Is the failing test written first, always, or only for non-trivial changes?
- **Does every bug fix start by converting the bug into a failing test?** A
  test written after the fix passes immediately, which proves nothing — it
  never demonstrated it could catch the bug.
- Is the red→green commit pair kept, or squashed?

If they use this plugin's `red-green` skill, the mechanics live there and the
CLAUDE.md just needs to say the rule holds. Do not duplicate the skill.

## 6. House style

- British or American English.
- Em dashes: allowed, or rewritten as two sentences? If forbidden, say that it
  applies to UI copy, error messages, ticket text, PR bodies **and diagram
  labels** — the last is where it gets forgotten.
- Anything else they find themselves correcting repeatedly.

## 7. Write it

Show the whole file before writing. Let them edit. Then:

```bash
# Global
mkdir -p ~/.claude && cat > ~/.claude/CLAUDE.md <<'EOF'
...
EOF
```

Keep it **short and numbered**. A rule nobody can find is a rule nobody
follows. Anything longer than about 200 lines wants splitting: the detail goes
in a skill, and the CLAUDE.md keeps the rule and a pointer.

If a project config exists, mirror the machine-readable answers into it:

```bash
jq '.logging = {...} | .apiConventions = {...} | .style = {...}' \
  .claude/workflow.config.json > /tmp/c.json && mv /tmp/c.json .claude/workflow.config.json
```

## 8. Say what changed

One short message: which file, which sections are new, and whether a deny
block was added. If they declined a section, say it was skipped rather than
leaving them to notice its absence later.

## What this skill will not do

- Write a rule the user did not agree to.
- Overwrite an existing CLAUDE.md without showing the diff first.
- Put project-specific detail in the global file, or vice versa.
- Add a `permissions.deny` block without confirmation.
