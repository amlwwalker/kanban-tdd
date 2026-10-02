---
name: browser-setup
description: One-time per-repo scaffold for browser-driven evidence — a real browser that walks the feature and photographs it, so a reviewer who does not read test output can see it working. Writes the config, the helpers and the gitignore, then records the `browser` block in workflow.config.json. Use once per repo, before the first screenshot-producing spec. Triggers on "/browser-setup", "set up playwright", "set up e2e", "browser tests", "screenshot tests", "visual testing setup".
---

# Browser setup

One-time, per repo. After this, `browser-evidence` runs per ticket.

**What this is for:** unit and integration tests prove the logic is right. They
cannot prove the user can see the thing. And "42 tests passed" is worthless to a
non-technical reviewer, where a picture of the feature working is conclusive.
This setup closes both gaps at once.

**What it is not for:** replacing the fast suites. A browser suite is slower,
more fragile, and worse at pinpointing a cause. It is a different instrument,
not a better one. The unit and integration suites stay the merge gate — see
`browser-evidence` for why that matters.

## Is this worth building here?

Ask, and accept no as an answer. Build it if **either** is true:

- **A bug has shipped that every unit test passed through.** The canonical shape
  is state logic that is individually correct but wrong in composition — a value
  handed to a parent, returned in a different form, re-read as something else.
  No amount of unit testing sees it; a real browser sees it immediately.
- **Tickets are reviewed by someone who does not read test output.** A
  screenshot converts "trust me" into "look".

Neither true? Say so and stop. An unused browser suite rots, and a rotted suite
is worse than none because its failures get ignored on the way to being deleted.

A repo with no UI does not need this at all.

## 1. Check what is already there

```bash
ls playwright.config.* cypress.config.* 2>/dev/null
jq -r '.browser // "none"' .claude/workflow.config.json 2>/dev/null
```

Already configured? Say what is there and ask whether to reconfigure rather than
overwriting a working setup.

A config block but no scaffold, or the reverse, is the interesting case: say
which half is missing and offer to complete it.

## 2. Interview — six questions

Short, because most answers are discoverable. Read the repo first and propose
defaults rather than asking blind.

**Which runner?** Playwright unless something else is already installed. It is
the recommendation, not a requirement: the trace viewer is the best diagnosis
tool of the three, and `getByRole` pushes you towards selectors that survive a
refactor. `references/playwright-scaffold.md` is the worked example.

**What starts the app, and on what URL?** Needed for the base URL default and
for the CI job. Check `package.json` scripts, `Makefile`, `docker-compose.yml`.

**Which widths matter?** Default `desktop 1280×900`, `ipad 820×1180`,
`phone 390×844`. A desktop-only internal tool needs one; a public site needs
three.

**How does a test sign in?** There must be a fixture user. If there is no way to
arrange one, say so — that is the blocker, not a detail, and it is worth fixing
before writing a spec.

**Is there a seed command?** One command that creates fixture users and content,
reproducibly. If not, note it as the gap that blocks CI later.

**Publish screenshots to the ticket automatically?** Yes writes an orphan
`assets` branch (see `browser-evidence`); no means the human drags images into
the comment box themselves, which is genuinely fine and much simpler.

## 3. Scaffold it

Follow `references/playwright-scaffold.md`. It carries the config with every
setting's reasoning, the six helpers, the four capture patterns, the spec
conventions and the CI job.

Four things are not optional, whatever the runner:

- **`screenshotDir` is git-ignored.** Screenshots are build artefacts. Committing
  them bloats the repo and puts stale images on tickets.
- **The base URL comes from an env var**, with a local default. It costs nothing
  now and it is the difference between pointing the suite at a deployed
  environment and rewriting it.
- **Sign in through the real form**, never by planting a session token. A planted
  token means a broken login page passes every test you have.
- **The suite arranges its own state.** Anything stateful — passwords, progress,
  flags, seeded rows — is set by the suite, not inherited from whatever the last
  run left behind.

Write `e2e/README.md` as you go: prerequisites, the run commands, and any trap
specific to this project. The next person to touch it will not read the specs.

## 4. Record the config block

```bash
jq '.browser = {
  "command": "pnpm test:e2e",
  "specCommand": "pnpm test:e2e {spec}",
  "screenshotDir": "e2e/screenshots",
  "baseUrlEnv": "E2E_BASE_URL",
  "seedCommand": "pnpm run seed",
  "viewports": [
    {"name": "desktop", "width": 1280, "height": 900},
    {"name": "ipad", "width": 820, "height": 1180},
    {"name": "phone", "width": 390, "height": 844}
  ],
  "assetsBranch": "assets",
  "imageFormat": "jpg"
}' .claude/workflow.config.json > /tmp/wc.json \
  && mv /tmp/wc.json .claude/workflow.config.json
```

**Without this block nothing else uses the suite.** `browser-evidence` and
`review-handoff` both read it, and both skip in silence when it is absent. A
scaffolded suite that no skill knows about is a suite nobody runs.

Keep `viewports` in step with the `VIEWPORTS` constant in the spec helpers. They
are the same decision recorded twice, and when they disagree the config is the
one the workflow believes.

## 5. The first spec, against a real bug

Do not write a smoke test. Write the spec for **a bug that actually happened** —
ideally the one that motivated building this — and then:

**Revert the fix and watch it fail.** A new test is worthless until you have seen
it go red. On the project this pattern came from, three separate tests passed
against knowingly broken code before that step was taken seriously.

Then put the fix back, watch it pass, and attach the screenshots to the ticket so
the first thing anyone sees of this setup is the thing it is for.

## 6. CI, written but not gating

Write the job and trigger it on `workflow_dispatch` only. Do not make it a
required check — see `references/playwright-scaffold.md` for the full argument
and the job itself.

Upload artefacts with `if: always()`. Locally you can rerun headed; in CI you get
one shot, so the report, the failure screenshots and the traces are the entire
diagnosis.

## What this skill will not do

- Scaffold a browser suite for a repo with no UI.
- Make the browser suite a merge gate.
- Plant a session token to skip the login form.
- Commit the screenshot directory.
- Write a smoke test as the first spec.
- Leave the `browser` config block unwritten after scaffolding.
