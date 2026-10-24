# Handoff — legal page URLs and the app-side wiring

For: **Chief** (owns `lib/`). Nothing in this note has been applied to `lib/`; the branch only
contains the pages themselves.

## 1. What is on this branch

| File | Purpose |
| --- | --- |
| `web/legal/privacy.html` | Privacy Policy — every claim derived from the shipping code on 2026-10-23 |
| `web/legal/terms.html` | Terms of Service — same discipline, medical disclaimer stated plainly |
| `web/site/index.html` | Bilingual (EN / Tiếng Việt) static landing page |
| `web/site/styles.css` | Landing page styles (single dark "dim room" theme, no external assets) |
| `docs/web/README.md` | How to publish (gh-pages branch vs Pages from `main`) and how to verify |

## 2. Recommended canonical URLs

Publish with **Option A** in `docs/web/README.md` (a `gh-pages` branch), which gives:

```dart
const privacyPolicyUrl = 'https://thongaccount.github.io/eye_care_ai/legal/privacy.html';
const termsOfServiceUrl  = 'https://thongaccount.github.io/eye_care_ai/legal/terms.html';
const landingPageUrl     = 'https://thongaccount.github.io/eye_care_ai/';
```

Fallback if Pages is served from `main` root instead: prefix every path with `/web/`
(`…/eye_care_ai/web/legal/privacy.html`, `…/eye_care_ai/web/site/`).

## 3. Suggested wiring (one file, three call sites)

Create `lib/config/legal_urls.dart` with the constants above, then:

1. **`lib/screens/settings_more_page.dart`** — the page already renders two cards,
   `PrivacySecuritySection` and `TermsOfServiceSection` (`SettingsMoreSection.privacy` /
   `.terms`). Add a third nav tile ("Privacy Policy (online)" / "Terms of Service (online)") that
   opens the URL with `url_launcher` (`launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)`).
   `url_launcher` is already a dependency.
2. **`lib/widgets/terms_of_service_section.dart`** — the six cards in there are still placeholders
   ("Placeholder body — replace with your real App Usage Policy text."). Two options:
   - point the "Chính sách bảo vệ dữ liệu / Data Protection Policy" card and the "Chính sách sử
     dụng ứng dụng / App Usage Policy" card at the published pages, and
   - replace the remaining placeholder bodies with the short summaries that already exist in
     sections 02–04 of `web/legal/terms.html` (medical disclaimer, AI disclaimer, user
     responsibilities), so the in-app text stops saying "placeholder".
   The version footer (`strings.termsVersion` / `strings.termsLastUpdated` in
   `lib/models/app_strings.dart`) should show the same version and date as the published pages.
3. **`lib/widgets/help_support_section.dart`** — the "Help & Support" card is a natural second
   home for the privacy-policy link.

Keep the URLs in `lib/config/legal_urls.dart` only; do not paste them into `app_strings.dart` as
duplicated string literals.

## 4. Legal facts still needed from the user

These are the four the user was already asked for, plus the content-level questions. They are
marked inline as `TODO` chips in the pages and collected in Appendix B of each page.

**Blocking (cannot publish without them):**

1. Legal entity / company name and registered address.
2. Governing jurisdiction (and venue for disputes).
3. Official privacy contact address — the in-app support mailbox is `eyecareai.app@gmail.com`;
   say whether that is also the legal contact.
4. Effective date for both pages.

**Should be answered before the Play submission (not strictly blocking):**

5. Confirm the app stays free, with no ads and no in-app purchases (the code agrees today).
6. Confirm the leaderboard entry can be deleted by the user, and its retention period.
7. Confirm cloud backup should be opt-in rather than automatic for signed-in users, and its
   server-side retention.
8. Confirm NVIDIA's retention / model-training terms for `integrate.api.nvidia.com`, and whether
   the embedded API credential should be replaced by a publisher-owned relay.
9. Confirm the minimum age and the Google Play Families policy classification.
10. Confirm the exact in-app menu labels used in privacy section 04 and 12 (Delete local data /
    Export my data / Data collection) against the current build.
11. Decide whether a Vietnamese translation of the legal pages is published, and which version
    prevails.
12. Add a `LICENSE` file to the repository and state in terms section 05 which licence governs
    the source code.

## 5. One cross-lane dependency

**Guardian email (MobileLead's mobile-P0 branch).** The privacy policy currently states that the
guardian feature only opens the user's own mail client with the address pre-filled
(`mailto:`). When the optional `GUARDIAN_EMAIL_ENDPOINT` path lands, rows 12 of the data table
(privacy) and section 10 (sharing) must be rewritten to describe the real flow — endpoint host,
payload, and who receives the reminder. The page already carries a `TODO` at that row.

## 6. Play Console consistency

The Data safety form must match privacy section 03 exactly:

- **Analytics:** not collected (the analytics service is a stub — two open TODOs in
  `lib/services/analytics_service.dart`).
- **Collected and shared with Google:** account data (Firebase Auth), leaderboard entry,
  cloud-backup contents.
- **Collected, sent to a third party:** AI chat messages and their context (NVIDIA).
- **On device only:** camera frames, ambient light, GPS coordinates, eye-test history, daily
  scores, timeline events.
- **Not collected:** advertising ID, precise location history beyond the one-shot fixes described,
  contacts, SMS/call logs, photos, files.

`docs/growth/app-listing.md` (GrowthLead's lane) should quote the same table; if the two
documents disagree, the code wins and the other document is corrected.

## 7. Publishing checklist

See `docs/web/README.md` for the `gh-pages` commands and the six-point verification list. The
short version: publish → confirm the three URLs return 200 → replace every `TODO` chip → wire the
app → then submit the Play listing with the privacy-policy URL filled in.
