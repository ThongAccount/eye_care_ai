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
```

Both legal pages link to each other and back to the landing page with **relative** paths
(`../legal/privacy.html`, `../site/index.html`), so they work unchanged in every publishing
layout below.

---

## Option A — `gh-pages` branch (recommended)

Short URLs, and the Flutter `web/` build never gets published by accident.

**Layout on the `gh-pages` branch:**

```
index.html          <- copy of web/site/index.html
styles.css          <- copy of web/site/styles.css
favicon.png         <- copy of web/favicon.png
icons/              <- copy of web/icons/
legal/
  privacy.html      <- copy of web/legal/privacy.html
  terms.html        <- copy of web/legal/terms.html
```

**One-time publish (git only, no toolchain):**

```bash
cd /workspace/eye_care_ai
git fetch origin
git worktree add -b gh-pages /workspace/temp/gh-pages origin/main
cd /workspace/temp/gh-pages
git rm -rf .                                  # empty the branch
cp /workspace/eye_care_ai/web/site/index.html .
cp /workspace/eye_care_ai/web/site/styles.css .
cp /workspace/eye_care_ai/web/favicon.png .
cp -r /workspace/eye_care_ai/web/icons .
mkdir -p legal
cp /workspace/eye_care_ai/web/legal/privacy.html legal/
cp /workspace/eye_care_ai/web/legal/terms.html legal/
git add -A
git commit -m "docs: publish legal pages and landing site"
git push origin gh-pages
```

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

Two caveats: the repository root has no `index.html`, so `…/eye_care_ai/` itself returns 404, and
Flutter's `web/index.html` is published too (it will render broken, because its Flutter bootstrap
assets are not built) — harmless, but it is untidy.

Option A gives the shorter URLs and a clean root; prefer it.

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
