---
name: browser-evidence
description: Run the browser suite to produce screenshots for a ticket, and publish them where a reviewer can see them. Use when a feature has visible behaviour and the ticket needs proof rather than a passing-test count, when preparing a handoff, or when a reviewer asks what it looks like. Produces evidence; it is never a merge gate. Triggers on "screenshots for the ticket", "show me what it looks like", "capture the screens", "run the browser tests", "attach the images", "visual evidence", "responsive check".
---

# Browser evidence

Unit and integration tests prove the logic is right. They cannot prove the user
can see the thing. **"42 tests passed" is worthless to a non-technical reviewer,
where a picture of the feature working is conclusive.**

This skill runs the browser suite for one ticket's behaviour and gets the images
onto the card.

**Skip in silence when the config has no `browser` block.** Nothing else depends
on this, and a repo without a UI has no use for it. Suggest `/browser-setup`
once if the ticket is visibly UI work and the block is absent, then move on.

## It produces evidence. It is not a gate.

This matters enough to state before anything else, because the instinct to make
it a gate is strong and wrong.

A browser suite needs the whole stack up against a seeded database, it is slow,
and it makes a flaky gate — **and a flaky gate gets ignored, which costs more
than it saves.** The unit and integration suites stay the merge gate.

So when the browser suite fails here:

- **Report it.** Say which spec, what it expected, what it saw.
- **Attach what it did capture.** A partial set of screenshots is still evidence,
  and the failure screenshot is often the most useful image of the run.
- **Do not block the handoff on it**, and do not move the card back.
- **Do flag it clearly**, because a browser failure on visible behaviour usually
  means a real bug that the fast suites missed. That is the whole reason this
  exists.

The judgement call: a browser failure that reproduces a *user-visible* break is
worth stopping for, and you should say so plainly and let the human decide. A
timeout on a cold dev server is not.

## 1. Read the config

```bash
jq '.browser' .claude/workflow.config.json
```

`command`, `screenshotDir`, `viewports`, `specCommand`, `seedCommand`. Absent
block, nothing to do.

## 2. Seed, if there is a seed command

```bash
<browser.seedCommand>
```

A suite that depends on what a previous run left behind passes once and then
rots. If there is no seed command and the suite needs fixture data, say so —
that gap is what stops this working in CI later.

## 3. Run it

One spec where possible, so a capture takes seconds rather than the whole suite:

```bash
<browser.specCommand with {spec} substituted>    # e.g. pnpm test:e2e checkout-screens
<browser.command>                                # whole suite, if there is no specCommand
```

**Use the configured command, never a raw `playwright test`.** The configured one
is what CI runs, and bypassing it is how local and CI drift apart.

If it fails, read the failure properly before rerunning. A browser suite rerun
blind is how an hour disappears. The HTML report and the trace are in
`e2e/.report` and `test-results` — the trace viewer is the fastest route to what
actually happened.

## 4. Name the images so they survive the ticket

The conventions matter more than they look, **because a screenshot is detached
from its run the moment it is attached to a ticket. The filename is all the
context it carries.**

| Pattern | Example | For |
|---|---|---|
| `<ticket>-<state>.png` | `153-saved.png`, `153-not-saved.png` | Single states |
| `<ticket><letter>-<state>.png` | `153b-fixed.png` | A later round after review feedback |
| `NN-<step>.png` | `01-product-card.png`, `02-basket.png` | A flow, so eight images sort into the right story |
| `<dir>/before/`, `<dir>/after/` | `brand/before/01-home.png` | A visual diff |
| `-<viewport>` suffix | `04-checkout-phone.png` | The viewport matrix |

Someone looking at the file six weeks later should know what it is and which
ticket it belongs to. `screenshot-3.png` fails that test.

The follow-up letter is load-bearing: `153b-` keeps the original round intact, so
a review thread stays readable in order rather than having images silently
replaced under earlier comments.

## 5. Capture what actually needs looking at

Four patterns, from `browser-setup/references/playwright-scaffold.md`. Pick by
what the ticket claims, not by habit.

**The viewport matrix** — every state at each `browser.viewports` width. One run
produces a full responsive review. This is the highest-value pattern and the
default for anything with layout.

**Reload at each width** when the screen decides its layout on first paint. A
resize alone shows a desktop page squeezed, which no phone user ever sees.

**Before/after via an env switch** for a visual change — the most persuasive
artefact you can put on a redesign ticket.

**Forced error states**, by intercepting the request and failing it. Failure UI
is the hardest thing to photograph and often the most important.

That last one is where this skill meets the ticket's failure-mode table: **a mode
identified in the interview can usually be photographed, not merely asserted.**
A 500 handled gracefully is a claim; a picture of the toast saying "not saved" is
evidence. When a ticket has a failure-mode table, walk it and capture the
in-scope rows.

## 6. Publish them

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/browser-evidence/scripts/publish-screenshots.sh" <ticket>
"${CLAUDE_PLUGIN_ROOT}/skills/browser-evidence/scripts/publish-screenshots.sh" <ticket> --dir checkout
"${CLAUDE_PLUGIN_ROOT}/skills/browser-evidence/scripts/publish-screenshots.sh" <ticket> --dry-run
```

It prints markdown ready to post. Pipe it into a comment, or patch an existing
one rather than posting a second:

```bash
gh issue comment <ticket> --body-file <path>
gh api -X PATCH repos/<slug>/issues/comments/<id> -f body="$(cat body.md)"
```

**If you have a browser open, dragging the PNG into the comment box is faster and
the script is unnecessary.** It exists for automation and for working over SSH.

### Why publishing is this awkward

**GitHub has no API for attaching an image to an issue or PR comment.** The
drag-and-drop uploader is web-UI only. So the script commits the images to an
orphan branch as real blobs and embeds them by raw URL, pinned to the commit.

Four details it encodes, each learned the hard way:

- **`.jpg`, not `.png`.** A PNG has been observed rendering as a broken-image
  icon with the blob present at that commit and the markdown identical.
- **The commit SHA is pinned**, never the branch name, so a link cannot change
  meaning when the branch moves.
- **`curl` cannot verify the result on a private repo.** Both a working and a
  broken image return 404 to an authenticated request, because a token is not a
  browser session. A `body_html` check only proves the markdown parsed.
- **Never the contents API's `download_url`.** It carries a short-lived
  `?token=` that expires, so the image works today and breaks next week.

### So ask a human to look

The script says this and it is not a formality. **Post the comment, then ask
someone to confirm the images render.** There is no programmatic check that
closes this loop, and an unrendered image on a ticket is worse than no image —
the reviewer assumes they have seen the evidence.

> Screenshots are on the ticket as comment 4:
> https://github.com/org/repo/issues/153
>
> I cannot verify they render — on a private repo curl gets a 404 either way —
> so could you open it and confirm you can see all three?

**Always the full URL, never `#153`.** The whole point of this message is to get
someone to go and look at the images, so make it one click:

```bash
gh issue view <ticket> --json url -q .url
```

## 7. Say what the pictures show

Do not post bare images. A reviewer should not have to work out what they are
looking at or what would be wrong:

```markdown
### Screenshots

**153-saved** — the toast after a successful save, with the title updated in the
list behind it.

**153-not-saved** — the same action with the PATCH forced to 500. The toast says
"not saved" and the title in the list is unchanged, which is the behaviour AC4
asks for. (If the title had changed here, the optimistic update would be wrong.)
```

The parenthetical is the valuable part: it tells a reviewer what failure would
have looked like, so they can genuinely check rather than nod.

## What this skill will not do

- Block a handoff, a merge or a card move on a browser failure.
- Run a raw `playwright test` instead of the configured command.
- Claim a published image renders without a human having looked.
- Post screenshots with no explanation of what they show.
- Commit the screenshot directory into the repo.
- Replace the manual checklist. Some things still need a human to drive — see
  `manual-test-design`.
