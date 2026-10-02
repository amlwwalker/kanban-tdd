# The Playwright scaffold

The worked example for `browser-setup`. Playwright and Chromium, because the
trace viewer is the best diagnosis tool of any of them and `getByRole` pushes
you towards selectors that survive a refactor. A Cypress or Puppeteer shop
configures `browser.command` differently and skips this file.

Copy each piece, then **re-decide every setting** — the comments exist so the
next person knows what they are overriding.

## Install and structure

```bash
pnpm add -D @playwright/test
pnpm exec playwright install chromium
```

```
playwright.config.ts
e2e/
  README.md            run instructions, kept next to the code
  helpers.ts           sign-in, db access, screenshot helper, safe selectors
  .gitignore           screenshots/ .report/ test-results/
  *.spec.ts            one file per ticket or per flow
```

`e2e/.gitignore`:

```
screenshots/
.report/
test-results/
```

**Screenshots are build artefacts, not source.** They are regenerated on demand
and published deliberately. Committing them bloats the repo and puts stale
images on tickets.

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:headed": "playwright test --headed",
    "test:e2e:ui": "playwright test --ui"
  }
}
```

| Command | Use |
|---|---|
| `pnpm test:e2e` | Headless. The normal one. |
| `pnpm test:e2e:headed` | Watch the browser do it. Best for debugging a selector. |
| `pnpm test:e2e:ui` | Step through interactively, inspect the DOM at each step. |
| `pnpm test:e2e <name>` | One spec only. |

## The config

```ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",

  // One at a time: these share one database and one set of fixture users, so
  // parallel runs fight over the same rows.
  workers: 1,
  fullyParallel: false,

  // No retries. A flaky test that passes on retry hides the flake, and these
  // are run by a person watching the result — the first answer is the real one.
  retries: 0,

  reporter: [["list"], ["html", { open: "never", outputFolder: "e2e/.report" }]],

  // A cold local dev server is slow to first paint. 30s was not enough.
  timeout: 60_000,

  use: {
    // The single most important line for CI-readiness: point this at a deployed
    // environment and the whole suite runs against it with no code change.
    baseURL: process.env.E2E_BASE_URL || "http://localhost:3002",

    // Safety net for diagnosis. The *deliberate* screenshots are taken
    // explicitly in the specs — this is not how the ticket images are made.
    screenshot: "only-on-failure",
    trace: "retain-on-failure",

    // Traces are more useful than video and far smaller.
    video: "off",
  },

  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
```

**On `workers: 1`.** If the tests share a database, parallelism is a bug
generator, not a speed-up. Relax it later with per-worker fixture isolation; do
not start there.

**On `retries: 0`.** The one people most often flip. A retry converts a real
intermittent failure into a silent pass, and intermittent failures in a browser
suite are usually genuine race conditions in the app. Revisit only for CI.

**On `baseURL`.** Read it from an env var from day one even if you only ever run
locally. It costs nothing and it is the difference between CI-ready and needing
a rewrite.

## helpers.ts — the reusable spine

Six things belong here.

### Sign in through the real form

```ts
export async function signIn(page: Page, user = LEARNER) {
  await ensurePassword(user);

  await page.goto("/login");
  await page.getByText("Sign in with password instead").click();
  await page.getByLabel(/email/i).fill(user.email);
  await page.getByLabel(/password/i).fill(user.password);
  await page.getByRole("button", { name: /^sign in$/i }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"), {
    timeout: 20_000,
  });
}
```

**Do not plant a session token.** It is faster, and it means a broken login page
passes every test you have. The login flow is part of what a user does.

### Arrange your own state

```ts
/**
 * Force the fixture user's password to the known one before signing in.
 * Anything touching the local database — including a person poking at it by
 * hand — can change it, and a suite that fails with "invalid login
 * credentials" tells you nothing about the feature under test.
 */
async function ensurePassword(user: { email: string; password: string }) {
  const serviceKey = process.env.SERVICE_ROLE_KEY;
  if (!serviceKey) return; // Nothing to do; the sign-in will report the truth.
  // ... call your auth provider's admin API to set the password
}
```

This is what makes the suite CI-viable: **it arranges the state it needs rather
than depending on what a previous run left behind.** Apply it to anything
stateful — progress, flags, seeded rows.

### Direct database access

```ts
/** A one-off query against the local database. */
export function sql(statement: string): string {
  const out = execFileSync("psql", [DB_URL, "-A", "-t", "-c", statement], {
    encoding: "utf8",
  }).trim();

  // psql prints a command tag after the rows — "INSERT 0 1", "UPDATE 2" — so
  // an `INSERT ... RETURNING id` comes back as "<uuid>\nINSERT 0 1" and every
  // later query built from it is malformed. Keep the first line.
  return out.split("\n")[0]!.trim();
}
```

### Poll, never query straight after a click

```ts
/**
 * The UI often fires its request and updates the screen without awaiting the
 * response — deliberately, so the user is never blocked. That means the screen
 * runs AHEAD of the database, and a query taken the instant a dialog closes
 * finds nothing. Polling asserts the same thing without a fixed sleep that
 * would be either flaky or slow.
 */
export async function waitForRow(
  query: string,
  matches: (value: string) => boolean,
  timeoutMs = 10_000,
): Promise<string> {
  const deadline = Date.now() + timeoutMs;
  let last = "";
  while (Date.now() < deadline) {
    last = sql(query);
    if (matches(last)) return last;
    await new Promise((r) => setTimeout(r, 200));
  }
  return last;
}
```

### Export safe selectors for anything ambiguous

```ts
/**
 * The pager buttons, scoped by exact label: a loose /next/i also matches the
 * dev-tools button the dev server injects into the page.
 */
export const nextButton = (page: Page) =>
  page.getByRole("button", { name: /^next\s*→?$/i });
export const previousButton = (page: Page) =>
  page.getByRole("button", { name: /^←?\s*previous$/i });
```

Any selector that has bitten you once becomes a named export, so it bites once
rather than once per spec.

### The screenshot helper

```ts
/** Screenshot into e2e/screenshots, ready to attach to a ticket. */
export async function shot(page: Page, name: string) {
  await page.screenshot({ path: `e2e/screenshots/${name}.png`, fullPage: false });
}
```

## The four capture patterns

### 1. The viewport matrix

The highest-value pattern. Capture each state at three widths, so one run
produces a full responsive review.

```ts
const VIEWPORTS = [
  { name: "desktop", width: 1280, height: 900 },
  { name: "ipad",    width: 820,  height: 1180 },
  { name: "phone",   width: 390,  height: 844 },
] as const;

async function capture(page: Page, name: string) {
  for (const vp of VIEWPORTS) {
    await page.setViewportSize({ width: vp.width, height: vp.height });
    await page.waitForTimeout(400);          // let the layout settle
    await page.screenshot({
      path: `e2e/screenshots/checkout/${name}-${vp.name}.png`,
      fullPage: true,
    });
  }
  await page.setViewportSize({ width: 1280, height: 900 });  // reset for the next step
}
```

Keep these in step with `browser.viewports` in the config, so the skill and the
suite agree on what a responsive review covers.

### 2. Reload at each width, when layout is decided on first paint

A resize alone shows a desktop page squeezed, which no phone user ever sees.
Screens that decide their layout when they first open — a contents panel that
starts closed on mobile, anything reading width at mount — need a real reload:

```ts
async function capture(page: Page, name: string, { reload = false } = {}) {
  for (const vp of VIEWPORTS) {
    await page.setViewportSize({ width: vp.width, height: vp.height });
    if (reload) {
      await page.reload();
      await page.waitForLoadState("networkidle");
    }
    await page.waitForTimeout(400);
    await page.screenshot({ path: `…/${name}-${vp.name}.png`, fullPage: true });
  }
}
```

Make it opt-in. Reloading every capture is slow and most screens do not need it.

### 3. Before/after via an env switch

One spec, two output directories, for showing a visual change side by side:

```ts
const SET = process.env.BRAND_SHOTS || "after";
// → e2e/screenshots/brand/${SET}/${name}-${vp.name}.png
```

```bash
git stash                                   # or check out the base commit
BRAND_SHOTS=before pnpm test:e2e brand-screens
git stash pop
pnpm test:e2e brand-screens                 # writes to after/
```

The most persuasive artefact you can put on a redesign ticket.

### 4. Force error states rather than waiting for them

Failure UI is the hardest thing to photograph and often the most important.
Intercept the request and fail it:

```ts
await page.route("**/courses/**", (route) =>
  route.request().method() === "PATCH"
    ? route.fulfill({ status: 500, body: "{}" })
    : route.continue(),
);

await title.pressSequentially(" broken", { delay: 30 });
await expect(page.getByTestId("save-toast")).toContainText(/not saved/i);
await page.screenshot({ path: "e2e/screenshots/153-not-saved.png" });
```

This pattern is why the ticket's failure-mode table and the browser suite belong
together: a mode identified in the interview can usually be *photographed*, not
just asserted.

## Writing a spec

### Clean up after yourself

A spec that creates data must remove it; a spec that edits a value must put the
original back. Otherwise run two is not run one.

```ts
const startedAt = new Date().toISOString();

test.beforeAll(() => {
  courseId = sql(`INSERT INTO courses (…) VALUES (…) RETURNING id;`);
  sql(`DELETE FROM baskets WHERE user_id = '${learnerId}';`);
});

test.afterAll(() => {
  const mine = `SELECT id FROM purchases
                WHERE purchased_by = '${learnerId}' AND created_at >= '${startedAt}'`;
  sql(`DELETE FROM seat_allocations WHERE purchase_id IN (${mine});`);
  sql(`DELETE FROM purchases WHERE id IN (${mine});`);
  sql(`DELETE FROM courses WHERE id = '${courseId}';`);
});
```

Scoping cleanup by `created_at >= startedAt` means a failed run never deletes
someone else's data.

For an in-place edit, capture and restore:

```ts
const original = sql(`SELECT title FROM courses WHERE id = '${courseId}';`);
// … edit, capture …
sql(`UPDATE courses SET title = '${original.replace(/'/g, "''")}' WHERE id = '${courseId}';`);
```

### Reset state in `beforeEach`

Progress, answers, flags, passwords — anything a previous test mutated. Without
this the suite passes once, then the next run resumes partway through and times
out. **The single most common reason a new browser suite rots.**

### Document the run command in the spec header

```ts
/**
 * The buying flow at desktop, iPad and phone widths (#285), for checking
 * against the design before anything is pushed.
 *
 *   pnpm test:e2e checkout-screens   -> e2e/screenshots/checkout/…
 */
```

Whoever needs these screenshots in three months is not going to read the whole
file.

## CI

**Start by not making it a gate.** The instinct is to add it to the PR checks.
Resist it: a browser suite needs the whole stack up against a seeded database,
it is slow, and browser tests make flaky gates — and a flaky gate gets ignored,
which costs more than it saves. Unit and integration stay the merge gate.

| Trigger | Good for |
|---|---|
| `workflow_dispatch` | Start here. Run it when you want it. |
| Nightly `schedule` | Catches drift without blocking anyone. |
| A `run-e2e` label on the PR | Opt in per PR when the change is visual. |
| Required check on PRs | Only once it has been stable for weeks. |

```yaml
e2e:
  name: Browser tests
  runs-on: ubuntu-latest
  if: github.event_name == 'workflow_dispatch'
  steps:
    - uses: actions/checkout@v4
    - uses: pnpm/action-setup@v4
    - uses: actions/setup-node@v4
      with: { node-version: 20, cache: pnpm }

    # Pin the version — resolving "latest" calls the GitHub API unauthenticated
    # on every run, shared across all runners, and dies with "rate limit
    # exceeded" before anything executes.
    - uses: supabase/setup-cli@v1
      with: { version: 2.117.0 }
      env: { GITHUB_TOKEN: "${{ secrets.GITHUB_TOKEN }}" }

    - run: supabase start
    - id: creds
      run: |
        echo "service_role_key=$(supabase status -o json | jq -r .SERVICE_ROLE_KEY)" >> $GITHUB_OUTPUT
        echo "db_url=$(supabase status -o json | jq -r .DB_URL)" >> $GITHUB_OUTPUT

    - run: pnpm install --frozen-lockfile
    - run: pnpm exec playwright install --with-deps chromium

    - run: pnpm run seed          # fixture users and content

    - name: Start the stack
      run: |
        pnpm api:dev &
        pnpm portal:dev &
        npx wait-on http://localhost:3001/health http://localhost:3002 -t 120000

    - run: pnpm test:e2e
      env:
        E2E_BASE_URL: http://localhost:3002
        SERVICE_ROLE_KEY: ${{ steps.creds.outputs.service_role_key }}
        DATABASE_URL: ${{ steps.creds.outputs.db_url }}

    # Without this, a CI failure is far harder to diagnose than a local one.
    - uses: actions/upload-artifact@v4
      if: always()
      with:
        name: e2e-artifacts
        path: |
          e2e/.report/
          e2e/screenshots/
          test-results/

    - if: always()
      run: supabase stop
```

**Two settings to revisit for CI.** `retries: 1` is defensible for an unattended
runner so a single network blip does not fail the build — accept that it hides
flakes and check the report. `workers` stays at `1` until fixture isolation
exists; do not raise it to make CI faster.

**Artefact upload is not optional.** Locally you can rerun with `--headed`. In
CI you get one shot, so the HTML report, the failure screenshots and the traces
are the entire diagnosis. Upload with `if: always()`.

## Traps

Every one of these has cost real time.

**Reset state in `beforeEach`.** Otherwise the suite passes once, then the next
run resumes partway into the flow and times out.

**The screen runs ahead of the database.** Requests fired without awaiting the
response mean a query taken the instant a dialog closes finds nothing. Use
`waitForRow`, not a bare query and not a fixed sleep.

**Dev-server UI pollutes selectors.** Next.js injects a dev-tools button that
matches `/next/i`. Any framework overlay can do this. Export exact-match
selector helpers.

**Installing a package breaks a running dev server.** `pnpm add` rewrites
`node_modules` under the running process, which then 500s with `Cannot find
module 'next/dist/pages/_error'`. Restart the dev server after any install.

**A green summary can hide files that never ran.** Watch for `Test Files X
passed (Y)` where `X < Y` — files failed to load and their tests never executed,
while the summary still printed green. Check the error count, not the colour.

**`INSERT … RETURNING` through a CLI returns two lines.** The command tag comes
back with the value. Take the first line.

**A new test is worthless until you have watched it fail.** Revert the fix,
watch it go red, put it back. On the tickets this pattern came from, three
separate tests passed against knowingly broken code before that step was taken
seriously.
