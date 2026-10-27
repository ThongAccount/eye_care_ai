# web/ — legal pages and landing site

Static, dependency-free pages for EyeCare AI. No build step, no npm, no CDN, no webfonts:
every file opens from disk and works offline.

```
web/
  legal/
    privacy.html      Privacy Policy  (grounded in the app code, 2026-10-23)
    terms.html        Terms of Service (grounded in the app code, 2026-10-23)
  site/
    index.html        Bilingual (EN / Tiếng Việt) landing page
    styles.css        Landing page styles — one "dim room" dark theme, no external assets
  index.html          Flutter's own web entry point — DO NOT TOUCH
  favicon.png, icons/ Flutter web assets
  og-image.png        Social preview card, 1200x630 (the og:image / twitter:image)
  robots.txt          Crawler rules for the published site
```

Publishing is done by [`scripts/publish-pages.sh`](../../scripts/publish-pages.sh), which rebuilds
the whole `gh-pages` tree from `web/` — no partial copies.

## The layout rule — read this before touching any link

**Links in `web/site/index.html` and `web/legal/*.html` are relative to the PUBLISHED root**:
`index.html` and `styles.css` sit at the root of the site, and `legal/` is a subfolder.
`web/site/` and `web/legal/` are **source folders, not URL folders**.

So:

- the landing page (published at the root) links to `legal/privacy.html`, `legal/terms.html`
  and `favicon.png`;
- the legal pages (published in `legal/`) link to each other with `privacy.html` /
  `terms.html`, and back to the landing page with `../index.html`.

Getting this wrong is not cosmetic: the links used to be written for the source layout
(`../favicon.png`, `../legal/privacy.html`, `../site/index.html`), so on the published site they
resolved one directory **too high** and returned **404** — the live home page could not open the
privacy policy, could not open the terms, had no icon, and the Home links inside both legal
pages were dead. When you move a file, fix its links against the published layout, never against
the repository layout.

---

## Option A — `gh-pages` branch (recommended)

Short URLs, and the Flutter `web/` build never gets published by accident.

**Layout on the `gh-pages` branch:**

```
index.html          <- copy of web/site/index.html
styles.css          <- copy of web/site/styles.css
favicon.png         <- copy of web/favicon.png
og-image.png        <- copy of web/og-image.png
icons/              <- copy of web/icons/
legal/
  privacy.html      <- copy of web/legal/privacy.html
  terms.html        <- copy of web/legal/terms.html
robots.txt          <- copy of web/robots.txt
```

**Publish (git only, no toolchain):**

```bash
cd /workspace/eye_care_ai
git fetch origin gh-pages
git worktree add --detach /workspace/temp/gh-pages FETCH_HEAD
scripts/publish-pages.sh --out /workspace/temp/gh-pages --push
```

Base the worktree on `origin/gh-pages`, never on `origin/main`: the published branch has a
history of its own, so a worktree built from `main` is rejected by the push as a
non-fast-forward. A detached worktree is what the CI workflow does too.

The script rebuilds the **whole** tree from `web/`, verifies every expected file is present and
non-empty before it commits, and only then pushes to `origin/gh-pages`. The old hand-written
recipe started with `git rm -rf .` and never copied `robots.txt`, so following it deleted the
live `robots.txt`; that class of mistake is now impossible.

Then in the repository: **Settings → Pages → Source: Deploy from a branch → `gh-pages` / `root`**.
The site is live about a minute later.

**Resulting URLs (recommended canonical):**

| Page | URL |
| --- | --- |
| Landing page | `https://thongaccount.github.io/eye_care_ai/` |
| Privacy Policy | `https://thongaccount.github.io/eye_care_ai/legal/privacy.html` |
| Terms of Service | `https://thongaccount.github.io/eye_care_ai/legal/terms.html` |

`https://thongaccount.github.io/eye_care_ai/` (project site, `/` root) is the URL to put in the
Play Console listing; the two `/legal/` URLs are the ones to wire into the app.

## Option B — Pages straight from `main` (root)

Settings → Pages → Source: Deploy from a branch → `main` / `/ (root)`.

**Resulting URLs:**

| Page | URL |
| --- | --- |
| Landing page | `https://thongaccount.github.io/eye_care_ai/web/site/` |
| Privacy Policy | `https://thongaccount.github.io/eye_care_ai/web/legal/privacy.html` |
| Terms of Service | `https://thongaccount.github.io/eye_care_ai/web/legal/terms.html` |

Three caveats: the repository root has no `index.html`, so `…/eye_care_ai/` itself returns 404;
Flutter's `web/index.html` is published too (it will render broken, because its Flutter bootstrap
assets are not built) — harmless, but it is untidy; and the shipped links are written for the
Option A layout, so in Option B the landing page's `legal/…` and `favicon.png` links resolve
inside `web/site/` and 404. Option B therefore needs the files published flat, the way
`scripts/publish-pages.sh` lays them out — it cannot publish the repository tree as-is.

Option A gives the shorter URLs, a clean root and links that resolve; prefer it.

---

## Keeping the URLs in one place

When a domain or a repository rename happens, only these two URLs change. Do not hardcode them
in more than one place in `lib/`. The handoff note in
[`handoff-legal-urls.md`](handoff-legal-urls.md) proposes a single `lib/config/legal_urls.dart`
constant file and names the exact call sites.

## Proving the verify job's wait

`.github/workflows/publish-pages.yml` publishes on every push to `main` that touches `web/`, then
a second job waits until GitHub Pages is really serving the new tree before asserting anything
about it. Three variables steer that wait. **CI sets none of them** — they exist so the same wait
logic can be exercised against a scratch site:

| Variable | Default | Effect |
|---|---|---|
| `PAGES_BASE_URL` | the URL the app itself uses (read from `lib/config/legal_urls.dart`) | Point the check at another site. |
| `PAGES_WAIT_ATTEMPTS` | `60` | How many times the wait looks at the site. |
| `PAGES_WAIT_PAUSE` | `10` | Seconds between checks. |

### The proof that was actually run

Not a hypothetical. This is how the wait was validated, in this order:

1. **The wait on a real, current site.** Dispatch the workflow on a branch whose `web/` tree
   already matches `main` (`workflow_dispatch`). The publish job logs `published 11 files` then
   `nothing changed, nothing to publish` — a no-op, because `web/` did not change — and the verify
   job logs `pages is serving this commit's whole tree (after 1 checks)`, then `200` on every URL
   including `/og-image.png`. A dispatch whose `web/` tree is unchanged is still a valid test of
   the wait: the wait is about Pages serving **this commit**, and a whole-tree match can only pass
   when it is.
2. **The case that failed before this fix** — a tree Pages has **not** built yet must NOT pass.
   Serve the previous tree and run the wait against it. Scratch under `/workspace/temp`, never
   `/tmp`:

   ```bash
   # the tree as it was BEFORE the publish: an older gh-pages, or the current one with the
   # file this commit adds removed - here the card, because main has already published it
   git worktree add --detach /workspace/temp/stale origin/gh-pages
   rm -f /workspace/temp/stale/og-image.png

   ( cd /workspace/temp/stale && python3 -m http.server 8792 )

   # the wait, exactly as the workflow runs it, extracted from the workflow itself
   python3 -c "import yaml;print(yaml.safe_load(open('.github/workflows/publish-pages.yml'))['jobs']['verify']['steps'][1]['run'])" \
     > /workspace/temp/wait.sh

   cd <checkout of this commit>
   PAGES_BASE_URL=http://127.0.0.1:8792 PAGES_WAIT_ATTEMPTS=6 PAGES_WAIT_PAUSE=1 \
     bash /workspace/temp/wait.sh
   ```

   Against that stale tree the loop prints `waiting for pages: check n/6, og-image.png is not
   this commit's file yet` and keeps waiting; copy the current tree in while it waits and it then
   passes. Left alone it exhausts the 6 checks and fails with an explicit error rather than a
   wrong assertion. The old single-file condition, given the same scratch site, passed on the
   first check and then failed the assertions — which is precisely what it did in CI.
3. Clean up: `git worktree remove /workspace/temp/stale`, then stop the server and delete
   `/workspace/temp/wait.sh`.

The negative case is proven locally against a deliberately stale site, and the positive case is
proven live with a real dispatch. If you change the wait, re-run both before trusting it.

## Verification checklist before publishing

1. Both legal pages open over HTTP (not `file://`) and return **200**.
2. Every `TODO` chip in both pages has been replaced by a real fact — see Appendix B of each page.
3. The effective date at the top of both pages is set and matches.
4. The Play Console **Data safety** form agrees with section 03 of the privacy policy
   (analytics = not collected; leaderboard + cloud backup = collected and shared with Google).
5. The app's Settings screen links to the published URLs, not to the local file paths.
6. On a phone-sized viewport: the language toggle switches all copy, the headings stay in order,
   and focus is visible on every link and button.
7. **Every relative link on the landing page resolves to 200** — check the resolved URL, not the
   file name, because a wrong `../` silently lands one directory above the project:
   `curl -s -o /dev/null -w '%{http_code}\n' https://thongaccount.github.io/eye_care_ai/{favicon.png,legal/privacy.html,legal/terms.html,robots.txt}`
8. The legal pages' Home links (`../index.html`) land on the landing page, not on a 404.
9. The landing page's `og:image` and `twitter:image` URLs resolve — a social preview that points
   at a missing file shows as a broken card, not as no card. They point at `og-image.png`, the
   1200x630 card in `web/`, which the publish script copies to the root of the published site:
   `curl -s -o /dev/null -w '%{http_code}\n' https://thongaccount.github.io/eye_care_ai/og-image.png`

## Notes on the two design registers

- **Landing page** — a deliberate single dark theme ("dim room"): the product exists to reduce
  screen strain, so a glaring white page would argue against it. Seafoam is the app's voice,
  amber marks the break. Type is system serif for display and system sans for body, so there is
  no font request at all.
- **Legal pages** — a quiet document register: near-white paper, one accent, a 70-character
  measure, a print stylesheet, and a wide data table that scrolls instead of breaking the page.
  Legal text needs to be read, not admired.

## Bilingual scope

The landing page ships both languages, switched with the `EN / VI` control in the header
(`data-lang` blocks, `document.documentElement.lang` updated, no cookies and no storage).
The legal pages are **English only** in this branch: the Vietnamese version is a legal translation
that needs a decision on which text prevails (open question 11 in Appendix B of each page).
