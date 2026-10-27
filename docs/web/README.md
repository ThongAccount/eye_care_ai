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
