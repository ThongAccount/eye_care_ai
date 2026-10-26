# EyeCare AI — Master Plan (from Notion Page)

> Source: Notion page "PATCHES" (26/07/2026) + SETTINGS spec + Feature wishlist
> Status legend: ✅ Done · 🟡 Partial · ❌ Not Started
> **Current truth: § CURRENT GAPS — 2026-10-26 (top of file).**
> Historical layers kept for provenance:
> - § NOTION SYNC — 2026-10-26 — the Notion page reconciled against the code.
> - § CODE-VERIFIED REFRESH (2026-10-23) — the code-grounded baseline the 10-26 sync re-checks.
> - § NOTION REFRESH (2026-10-15) — Notion snapshot deltas.
> - § Aug-6 audit (below) — ⚠️ **HISTORICAL, superseded.** Its ❌ rows were re-verified
>   against the code on 2026-10-23 and several were wrong (features that shipped since).
>   Sections marked `[HISTORICAL]` are retained verbatim for the record; use the
>   code-verified tables instead of them.

---

## 🚧 CURRENT GAPS — 2026-10-26 (what is **not** available in the repo right now)

> **Why this section:** the layers below record what shipped. This one records the opposite —
> every feature that a user, a reviewer or a store can **not** get from the current build.
> **Method:** repo-wide sweep of `lib/`, `android/`, `ios/`, `web/`, `docs/` at `main` @ `a67e056`,
> live URL checks, a read of every open marker in this file, and a certificate check on the
> shipped build-98 artifacts. "0 references" means the string/symbol does not exist in the tree.
> **Headline:** the app is feature-rich and shippable as an alpha. What is missing clusters in
> **analytics, iOS, store submission and 8 wishlist features** — plus a few small in-app items and
> the user-side legal/store facts.

### ❌ A. Not available at all (code-verified absent)

| Item | Evidence |
|---|---|
| **Analytics event logging** | `analytics_service.dart:57` / `:63` are no-op stubs, and **0 call sites** invoke `logEvent` / `logScreenView` anywhere in `lib/`. The 87 events in `docs/growth/analytics-events.md` are spec-only. Consent capture works; the pipeline does not exist |
| **Analytics config** | `AnalyticsConfig` / `ANALYTICS_ENDPOINT` does not exist in `lib/config/` — there is nowhere to point a backend even if someone wanted to |
| **Snooze Duration** (notification) | 0 references in `lib/` |
| **Blink Reminder** | "blink" appears only as exercise copy (`app_strings.dart:416`, `:432`, `:448`), an achievement (`app_strings.dart:303`) and rank titles (`rank_tier.dart:70`, `:82`) — no reminder |
| **Blue Light Filter** | strings only in `AppStrings`; OS-level, unimplemented |
| **AI Voice** / **AI Sensitivity** (Low/Med/High) | 0 references in `lib/` (the only "sensitivity" string is eye-test *contrast* sensitivity) |
| **Daily Quests** (3/day, tied to Rank) | 0 word-boundary hits in `lib/` |
| **Recovery Day / streak protection** | 0 references; a missed day resets the streak to 0 — no grace token |
| **Adaptive Goals** (auto tighten / relax) | nothing adapts automatically; the app only *suggests* a lower break target in a user-driven dialog (`adjust_break_goal_dialog.dart`, called once per session from `main_shell.dart:157`) |
| **Personal Eye Profile** (data-derived) | 0 references. Only the manual "Vision Profile" setting exists (`SettingsProvider.visionProfile`) — no data-derived baseline |
| **"What if?" simulator** | 0 references |
| **Distance History** distribution | camera distance scoring was removed on 05/09; distance survives only as a live hint during the eye test |
| **AI Weekly Eye Coach** | the weekly report is **data-only** (`habit_provider.dart:417`, weekly notification `notification_service.dart:749`). The AI has chat + a one-shot Home auto-analysis of *current* state — no weekly aggregation, no coach persona |
| **Night phone-usage display** ("last activity 23:48, 5 of 7 nights") | only the sleep **estimate** in hours exists (`UsageService.getSleepEstimateMinutes()`); the Notion display does not |
| **Eye-exercise streak → leaderboard rank** | 0 references to an exercise streak. Habit streaks exist (`HabitProvider.streakDays`) but are not tied to eye-exercise completion |
| **Crash reporting** | no `sentry` / `firebase_crashlytics` in `pubspec.yaml` |
| **Store graphics for Play** | **0 files**: no 512×512 Play icon, no 1024×500 feature graphic, no phone/tablet screenshots. The repo only has `assets/icon/app_icon.png`, the adaptive-icon foreground and `web/icons/*` — none in Play's required sizes |
| **Firestore security rules** | not in the repo — only a suggested snippet in a comment (`leaderboard_service.dart:63-64`). The deployed rules are unverified; wrong read rules break the leaderboard in production |
| **App Store IPA** | `build-ios.yml` is `workflow_dispatch`-only and exports with `method: development` (`ios/ExportOptions.plist`) → no distributable IPA can be produced |
| **iOS build** | iOS **source** exists (`ios/Runner/AppDelegate.swift`, `Info.plist`, `Runner.entitlements`, `Assets.xcassets` — 49 files), but there is no macOS/Xcode runner, no iOS CI, and no signing → no iOS artifact can be produced here |
| **iOS feature parity** | Usage Access, exact alarms, the dark-room foreground service and the home-screen widget are **Android-only** — the iOS build would be missing the core of the product |
| **App-lock enforcement** | the gate can never fire: `armGate` is always called with an empty blocked-app list (`app_usage_monitor.dart:69`), the native watcher only shows the overlay when the foreground package is in that set (`AppLockOverlayManager.kt:169-175`), `showGateOverlay` has no Dart caller, and the `AppLockOverlay` Flutter screen (`app_lock_overlay.dart:17`) is never routed to. The settings sheet and the overlay **preview** work; the lock itself does not |
| **Contextual rating prompt** | 0 references — "Rate App" is a manual Settings tile only, never asked at a streak milestone or after a weekly report |
| **Guardian auto-send** | the worker + HTTPS send path shipped (`GuardianReminderWorker.kt`, `guardian_reminder_service.dart:32`), but **no endpoint value is configured anywhere** — `GUARDIAN_EMAIL_ENDPOINT` is only a dart-define constant. Without it the app falls back to opening a pre-filled mail client |
| **Play / App Store listing links** | `store_links.dart:17` `playListingPublished = false`, `:20` `appStoreListingPublished = false`, `:23` `appStoreId = ''` → `buildStoreUri` returns null on every platform, so "Rate App" always shows the fallback dialog (thanks → `mailto:eyecareai.app@gmail.com` → GitHub Releases) |
| **Social preview image** | no `og:image` and no `twitter:card` in `web/site/index.html` — shared links render with no preview image |
| **Landing page imagery** | 0 `<img>` tags in `web/site/index.html` — no screenshots, no phone mockups, no app icon on the page |
| **Vietnamese legal pages** | 0 `lang="vi"` in either legal page — the landing page's Vietnamese legal buttons open the **English** documents |
| **`LICENSE` file** | the repo has none (README says MIT, the terms page has a chip asking for it) → GitHub detects no licence for the repo |
| **`sitemap.xml` / 404 page** | absent; `robots.txt` exists **only on the `gh-pages` branch**, not in `main` |

### 🟡 B. Available but incomplete

| Item | What is there | What is missing |
|---|---|---|
| **App lock / usage limit** | the counter **is** implemented and wired: `usage_limit_provider.dart:66` ← `app_usage_monitor.dart:55` ← `main_shell.dart:97`/`:175`, fed by real UsageStats, with daily reset + a 5-minute "+5 min" grant; the overlay preview and the settings sheet both render | ⚠️ **enforcement never fires** — `armGate` is always called with an empty list (`app_usage_monitor.dart:69`, "chưa có blocked-app picker"), and the native watcher shows the gate only when the foreground package is in that set (`AppLockOverlayManager.kt:169-175`), so with an empty set the overlay **never appears**. `showGateOverlay` has no Dart caller and the `AppLockOverlay` Flutter screen (`app_lock_overlay.dart:17`) is never routed to. The budget is also only recomputed while the Dart process is alive |
| **Analytics** | consent screen + `pref_consent_given` + a toggle | no endpoint, no events, no schema test — so every experiment in `docs/growth/retention-plan.md` is currently unmeasurable |
| **Cloud sync** | backup/restore includes the daily snapshots (`cloud_backup_service.dart:31-32`) and writes them back on restore | it is a **manual** backup/restore, not live sync; no conflict resolution across devices. It also **defaults to ON** for signed-in users (`settings_more_provider.dart:34`, `:47`) → that must be declared in the Play Data Safety form, or flipped to opt-in |
| **Achievements / badges** | 9 badges whose progress is computed from real data (`_buildItems` in `home_screen.dart` uses `totalEyeBreaksAllTime` / `streakDays`) — the old hardcoded `unlocked: true` is gone | no distance- or environment-based tiers, and nothing outside break counts |
| **"Why did my score change?"** | day-over-day factor deltas (`habit_provider.dart:338-341`) and per-factor explainers | no points ledger ("−4 phone time, −2 dark room") |
| **Daily Eye Report** | Home "today's suggestions" + Weekly/Monthly tabs in Statistics + a scheduled **weekly report notification** (Mondays 07:30, `notification_service.dart:749-788`) | no dedicated daily report card, no 30-day daily view, no share card (sharing is limited to data/PDF export) |
| **Smart Notification Priority** | Focus mode blocks *other* apps' notifications (`focus_mode_service.dart`) | the app's own alerts are not de-duplicated — the water reminder rides along on the break notification |
| **AI Reminder Style** | the chosen style is injected into the AI context (`chat_screen.dart:103`, `home_screen.dart:337`) | no dedicated AI-settings screen |
| **Brightness Tips** | actionable — `smart_brightness_dialog.dart:72` calls `BrightnessService.applySystemBrightness(target)` | — |
| **Streak** | a real streak counter + a 21:00 reminder | it counts an **app-open check-in** (`device_data_service.dart:721` `_kCheckInPrefix`), so a user who never opens the app loses the streak |

### 🚫 C. Launch blockers that are **user-side** (no code can close them)

| Blocker | State |
|---|---|
| **Legal facts** | **44 unfilled markers live on the published pages**: 41 chip spans (27 in `privacy.html`, 14 in `terms.html`) of which 2 are legend examples → **39 question chips**, **plus 5 plain-text prose TODOs in the page footers** (privacy L801-803: legal entity name, postal address, privacy e-mail; terms L629-630: entity name, postal address). Distinct underlying facts: **36** counting each chip as its own question, **32** when a fact asked twice (body + footer, or on both pages) is merged — the footer prose repeats facts already asked in the body. Still needed: legal entity name, jurisdiction, registered address, contact e-mail, effective date, retention windows, NVIDIA sub-processor terms, Firestore rules, guardian-endpoint operator. ⚠️ **7 of the 39 chips are not collected in Appendix B** (privacy L477 usage-history window, L692 analytics-off, L705 Firestore rules, L715 publisher-structure clause, L761 security commitments; terms L494 explicit clause, L621 arbitration/mediation) → answering only Appendix B still leaves them open |
| **Play Developer account** + legal developer name | `docs/growth/app-listing.md:29` — **TODO, user must provide**; `:286` still asks personal vs organisation |
| **Play upload key** | CI signs with the app **release** key; only `android/app/ci-fallback-keystore.jks` sits in the repo. A dedicated upload key is required before the first Play upload |
| **Play listing fields** | `app-listing.md:22` iOS app name still `Eye Care Ai` (rename to `EyeCare AI`), `:157` privacy-policy URL still TODO (the page is live now — this one is fillable today) |
| **Store graphics** | the Play icon, feature graphic and 8 screenshots do not exist yet — they need a device and a design pass |
| **iOS** | Apple Developer account, `com.eyecare.eyeCareAi` distribution signing, an App Store ID, iOS screenshots/metadata, and a macOS build machine |
| **Guardian endpoint** | a real HTTPS endpoint URL to pass as `GUARDIAN_EMAIL_ENDPOINT` at build time |
| **Keystore rotation** | pending — the current key has signed every build since the start |
| **Vietnamese legal translation** + `LICENSE` file | still undecided |

### 🧹 D. Tech debt still physically in the repo

| Item | Evidence |
|---|---|
| 3 dead files, 0 references each | `lib/providers/usage_provider.dart`, `lib/widgets/usage_pie_chart.dart`, `lib/services/storage_service.dart` — still present, still unreferenced |
| Focus-mode DND grant not cached | `focus_mode_service.hasAccess()` → `FocusModeHandler.kt:42` `isNotificationPolicyAccessGranted` is re-checked every time, so the re-check banner can reappear |
| 3 unused Eye Test strings | `eyeTestHint`, `eyeTestInstruction`, `eyeTestTitle` — 0 call sites outside `app_strings.dart` |
| **No Pages automation** | nothing in `.github/workflows/` publishes `gh-pages` — every legal-page change needs a manual republish (in sync today). Worse, the publish recipe in `docs/web/README.md:44-57` does not copy `robots.txt`, so following it would **delete the live robots.txt** |
| **Broken favicon path** | `web/site/index.html:11` uses `href="../favicon.png"` → resolves to `https://thongaccount.github.io/favicon.png` → **404**; the file is at `/eye_care_ai/favicon.png` (200). One-line fix |
| **In-app terms date runs ahead of the pages** | the app shows "Terms Version 1.0 / Last Updated: October 2026" (`app_strings.dart:1070-1071`) while both published pages still carry the effective/last-updated dates as TODO |
| **Guardian copy overstates what ships** | the Settings copy implies an automatic guardian reminder, but no build has an endpoint configured — today the worker only writes a pending flag and opens the user's mail client |
| **Stale docs** | `docs/web/handoff-legal-urls.md:4`, `:38-39` ("nothing applied to `lib/`", "cards are still placeholders") are false since `6f00eef`; `docs/growth/app-listing.md:3` (grounded at an old SHA), `:156` ("marketing site in flight" — it is live), `:157` (privacy URL still TODO while the page is live) |
| **`web/index.html` is Flutter's untouched template** | harmless today (it is not deployed), but a trap if anyone ever publishes `web/` as a Flutter build |
| Analytics stub | `analytics_service.dart:57`, `:63` |
| Setup wizard asks for Usage Access first | `setup_wizard_screen.dart:44-51` — the permission-heavy step comes before notifications, which is the opposite of the "value first" onboarding in `docs/growth/retention-plan.md` Move 3 |
| Stale iOS HealthKit strings | `ios/Runner/Info.plist:66`, `:68` still declare `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` although the `health` package was removed — App Review will ask why |
| `docs/growth/app-listing.md` accuracy | `:187` says location is sampled "while the app is open" — stale, `ACCESS_BACKGROUND_LOCATION` is declared (`AndroidManifest.xml:68`) and a WorkManager outdoor sampler runs; `:193` says only the e-mail prefix is published — stale, the leaderboard publishes `displayName` **and** `avatarUrl` (`leaderboard_service.dart:80-95`); `:171-172` content-rating wording still says "nickname" |
| Toolchain drift | Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 — Flutter warns these will be dropped |

### 🕳️ E. Notion "15 idea groups" — what is actually there (verified 2026-10-26)

| # | Idea | State |
|---|---|---|
| 1 | Eye Health Score 2.0 | ✅ shipped, **4 factors** (no distance) |
| 2 | "Why did my score change?" | 🟡 deltas only, no points ledger |
| 3 | Daily Eye Report (7/30-day) | 🟡 weekly/monthly tabs + a weekly notification, no daily card |
| 4 | AI Weekly Eye Coach | ❌ not shipped |
| 5 | Adaptive Goals | 🟡 suggestion dialog only |
| 6 | Streak Protection (Recovery Day) | ❌ not shipped |
| 7 | Eye Health Timeline | ✅ shipped |
| 8 | Smart Notification Priority | 🟡 focus mode only |
| 9 | Distance History | ❌ not shipped |
| 10 | Sleep Pattern from night usage | 🟡 estimate shipped, the "23:48 · 5/7 nights" display is not |
| 11 | Eye Test History | ✅ shipped (no per-eye trend chart) |
| 12 | Achievements 2.0 | 🟡 9 badges, break-count based |
| 13 | Daily Quests | ❌ not shipped |
| 14 | Personal Eye Profile | ❌ not shipped |
| 15 | "What if?" simulator | ❌ not shipped |

### ✅ F. Rows that used to be gaps and are **not** any more

- `habitSubtitle('breaks')` — now "Manually and auto-counted breaks" (`app_strings.dart:687-702`); the old "Front camera gaze detection" text is gone.
- Achievement unlock logic — computed from real data, not hardcoded `unlocked: true` (`home_screen.dart` `_buildItems`).
- Brightness Tips — actionable (calls the brightness service).
- Health Connect setup guide — **obsolete**: the app does not use Health Connect at all (explicitly removed; sleep is estimated from usage times).
- Rate App + hosted Privacy/Terms — shipped; the HISTORICAL SETTINGS rows that still say "not implemented / in flight" were stale text.

### 🔐 G. Signing & key exposure — checked on the shipped build-98 artifacts

| Check | Result |
|---|---|
| **Which key signed the APK?** | The **real release key**: `CN = EyeCare AI, O = ThongAccount, C = VN`, alias `EYECARE_`, SHA-256 `BC:C2:3B:01:74:69:2F:4D:D3:76:83:4F:18:C9:1D:F1:AB:7A:01:71:BF:F5:D0:B1:36:BF:7F:84:F4:70:C0:11` — extracted from the APK's v2 signing block (`0x7109871a`) |
| **And the AAB?** | Identical certificate, same fingerprint (v1 signature `META-INF/EYECARE_.RSA`) |
| **Was it the committed fallback keystore?** | **No.** `android/app/ci-fallback-keystore.jks` holds a different cert — `CN = EyeCare AI CI Fallback`, SHA-256 `39:0C:E6:16:78:27:0E:46:E6:7B:0A:57:9C:02:12:C8:78:E6:AD:8D:1C:90:BB:AC:03:43:31:E4:F5:03:22:1A` |
| **Latent risk** | `build-apk.yml:142-145` **silently skips** the release-signing step when `KEYSTORE_BASE64` is missing, and `build.gradle.kts:74-105` then signs with the committed fallback. It did not happen in build 98, but it would sign with a key that is public in the repo. The build should **fail** instead of falling back |
| **Play upload key** | still not configured — only `release` / `ciFallback` exist, no Play App Signing upload config |
| **NVIDIA NIM key** | compiled into the binary (`--dart-define=NIM_API_KEY`, `build-apk.yml:227` / `:271`) → extractable from the downloaded APK. Move it behind a backend proxy before a public release |

---

## 📌 NOTION SYNC — 2026-10-26 (user-pasted page, reconciled against code)

> **Source:** the user pasted the live Notion page "Eye Care AI" into Product Lab on
> 2026-10-26 (PATCHES → Tiến độ → Target → 15 idea groups → SETTINGS → upcoming-features
> list) and asked for PLAN.md to be updated from it.
> **Method:** every ✅ / ❌ / open item in that paste was re-checked against the source
> tree at `main` @ `211ad17`. Notion is a wishlist snapshot; **the code is the truth.**
> Where they disagree, the code wins and the disagreement is recorded here instead of
> silently overwriting either side.
> **Net result:** 13 rows checked, **9 corrections**, 0 regressions. The Notion page is a *wishlist* —
> it lags the code in both directions (it still lists the custom notification sound as open, and
> still shows the old fork/merge state).

### 🔍 Notion row → what the code actually says

| Notion row | Notion says | Code says (verified 2026-10-26) | Action |
|---|---|---|---|
| Thêm âm thanh custom cho thông báo | `[ ]` open | ✅ **shipped** — `android/app/src/main/res/raw/eye_break_alert.wav` (49 KB) + Settings toggle; two channels (system/custom) because Android cannot change a channel's sound after creation; auto-falls back to the system sound | Notion stale → PLAN corrected |
| Lock ứng dụng khi reach usage limit | `[x]` + *"counter chưa hoàn thiện, overlay xong, đang ở fork, đợi merge với `main-merger`"* | ✅ shipped on `main` since v1.3.0+alpha (`AppLockOverlayManager.kt`, `lib/models/app_usage_limit.dart`, `lib/providers/usage_limit_provider.dart`, `lib/screens/app_lock_overlay.dart`, `lib/services/app_usage_monitor.dart`); the fork → `main-merger` → `main` path is **done**, so "đang ở fork / đợi merge" is stale. The usage-limit **counter** is still the rough edge | Notion note stale → PLAN corrected |
| "Áp dụng mục tiêu" không cập nhật Habits | `[x]` | ✅ genuinely fixed — `HabitProvider.applySurveyTargets()` (`habit_provider.dart:684`), awaited at `habits_survey_screen.dart:783`; timestamped targets, newest-wins against the Firestore overwrite | Notion ✅ confirmed |
| Nghỉ mắt: hết countdown mới tính 1 lần + gửi thông báo | `[x]` | ✅ fixed (real-clock countdown, no make-up cycles after long absence, decimal-`target` cast fix) | Notion ✅ confirmed |
| Chỉ đăng nhập 1 lần khi vừa tải app (lưu lịch sử, tài khoản, mật khẩu) | `[x]` | ✅ outcome true, **mechanism in PLAN was wrong**: `pref_guest_mode` no longer exists anywhere in `lib/` (0 hits). Session persistence is Firebase Auth's own — `authStateChanges` (`auth_provider.dart:11`), `currentUser` (`profile_provider.dart:29`). No plaintext password is stored; passwords only flow through Firebase Auth calls | PLAN evidence corrected |
| Target: "Apply Target" 4 mức (⭐/🙂/💪/✏️) | spec, no checkbox | ✅ fully implemented — see § TARGET below for the exact factors, the range rule and the **5th level Notion does not mention** | Plan spec enriched |
| Eye Health Score 2.0 mock: `📏 Khoảng cách 91%` | design mock | ⚠️ **the live score has 4 factors, not 5** — distance was dropped as a scoring factor on 05/09 (battery/privacy); `loadDailyFactorScores` returns null for `distanceScore` (`device_data_service.dart:588`). Live factors = screen time / environment / eye breaks / sleep. Outdoor is a habit, **not** a score factor | PLAN corrected |
| Chuỗi làm bài tập mắt → xếp hạng theo chuỗi | `[ ]` | ❌ genuinely absent — 0 references to an exercise streak. Habit streaks exist (`HabitProvider.streakDays`) but are **not** tied to eye-exercise completion | Notion `[ ]` confirmed |
| Đổi model AI (provider khác) | `[ ]` | still open — unchanged | no change |
| Việc check thời gian ngoài trời còn bất ổn | `[ ]` | still open — outdoor is GPS-based (`DeviceDataService.startOutdoorTracking`) | no change |
| "Repo github: `Supertime1236/eye_care_ai`" + *"todos có `*` đang ở fork `ThongAccount/eye_care_ai`, đang đợi merge với `main-merger`"* | fork pending | ⚠️ stale — the fork lane **has been merged** upstream through `main-merger` and into `main`. `main` is our release branch (`githubOwner = 'ThongAccount'`); `main-merger` is the upstream-sync staging branch and deliberately keeps `Supertime1236` as the updater owner | Notion note corrected |
| SETTINGS spec (Units / 20-20-20 / Notifications / AI / Privacy / Vision Profile / Reminder Style / Viewing Distance) | full tree | unchanged from § SETTINGS SPEC — the only newly-shipped entry is the custom notification **Sound** | Plan spec unchanged |
| "Tính năng sắp tới" wishlist (16 bullets) | list | unchanged from the 2026-10-15 table; Focus mode, PDF export, next-break countdown widget, night-read mode and the water reminder are all ✅ now — already recorded in § FEATURE WISHLIST | no change |

### 🧾 Rows edited by this sync

1. § Shipped features → **Scoring** row — factor list corrected to the live four.
2. § NOTION REFRESH 10-15 → **Custom notification sound** `[ ]` → `[x]` (shipped).
3. § NOTION REFRESH 10-15 → **Đăng nhập 1 lần** — `pref_guest_mode` evidence replaced with the Firebase Auth path.
4. § NOTION REFRESH 10-15 → **fork note** — "đang đợi merge" → merged.
5. § PATCHES 26/07 → **Remaining Polish** — custom sound `[ ]` → `[x]`.
6. § SETTINGS SPEC → **Notifications / Sound** — Partial → shipped.
7. § TECH DEBT → **Custom notification sound** `[ ]` → `[x]`.
8. § FEATURE WISHLIST → **Eye Health Score 2.0** — distance-factor caveat added.
9. § TARGET → formula factors, file:line evidence and the extra `keep` level added.

---

## ✅ CODE-VERIFIED REFRESH — 2026-10-23

> Method: every row below was checked against the actual source tree on 2026-10-23
> (`main` @ `ba547c0`, after the Eye-Timeline merge). Notion was **not** consulted — this
> section is ground truth for what is actually in the app today.
> Legend: ✅ shipped · 🟡 partial/stub · ❌ genuinely absent.

### 🔖 Release status — 2026-10-24

| Item | State |
|---|---|
| Version | Bumped `1.3.0+alpha` → **`1.4.0+alpha`** (minor, not patch: 46 commits of new features landed after the 1.3.0 cut on 2026-09-08). In-app it reads `EyeCare AI v1.4.0 (build N)`; `versionCode` = CI run number. Verified end-to-end on build 85 — APK manifest `versionName=1.4.0`, `versionCode=85`. |
| Play artifact | **Android App Bundle (`.aab`) now built alongside the APK** — Play rejects APK uploads for new apps. CI attaches `eye_care_ai-<version>-<sha>-build<N>.aab` to the same GitHub Release; Modal produces one with `--build-aab` (build 111 verified: signed with the release key, `versionName=1.4.0`, `versionCode=111`, INTERNET permission present). |
| CI gates | `flutter analyze` + `flutter test` now run **before** the release build — a failing test can no longer ship. |
| Legal | Privacy/Terms published and returning HTTP 200, and the live bytes match `main` (no drift). Still **44 unfilled markers**: 41 chip spans (27 privacy + 14 terms) of which 2 are legend examples → 39 question chips, **plus 5 plain-text prose TODOs in the page footers** (privacy L801-803, terms L629-630). Distinct facts: **36** counting each chip as its own question, **32** when a fact asked twice is merged. 7 of the 39 chips are not collected in Appendix B. Waiting on the user: legal entity name, jurisdiction, contact e-mail, effective date, registered address, and the data-retention / NVIDIA-endpoint details. |
| Versioning rule | The in-app updater compares **build numbers** (GitHub release tag `build-<N>` vs the installed `versionCode`), not the version name — so a version-string bump never affects the update flow. |
| Release notes | The CI generates the GitHub release body from **every** commit between the previous release and this build — subject + description, plain text, Conventional Commit prefix stripped. That body is exactly what the in-app "Update Available" modal and the changelog screen render, so **every commit must carry a description body**. Legacy bodies are cleaned by `UpdateService.sanitizeNotes()`. |

### 📦 Shipped features (verified in code)

| Area | Feature | Evidence |
|---|---|---|
| Reminders | 20-20-20 break reminders + persistent countdown notification + repeating native alarm + vibration | `NotificationService`, `ReminderProvider`, `eye_break_screen.dart` |
| Reminders | Water reminder tied to break cycles | `ReminderProvider`, `eye_break_screen.dart` |
| Reminders | Focus mode (notification blocking) | `focus_mode_service.dart` |
| Reminders | Custom notification sound | ✅ `res/raw/eye_break_alert.wav` + Settings toggle; two channels (system / custom) because Android cannot change a channel's sound after creation; auto-falls back to the system sound if the raw file is unusable *(mobile P0, 2026-10-23)* |
| Scoring | Eye Health Score — **4 live factors: screen time / environment / eye breaks / sleep**, with day-over-day deltas. Distance was **dropped** as a scoring factor on 05/09 (battery/privacy) and there is no separate outdoor factor | `statistics_screen.dart`, `HabitProvider` (`screenTimeScore`, `environmentScore`, `eyeBreaksScore`, `sleepScore`), `device_data_service.dart:588` |
| Scoring | Streaks + achievements | `HabitProvider.streakDays`, `_AchievementPage` |
| Scoring | Duolingo-style ranks (7 tiers) + Firestore leaderboard | `rank_screen.dart`, `leaderboard_service.dart` |
| Environment | Dark-room foreground service (native Kotlin) | `dark_room_background_service.dart` |
| Environment | Brightness service + auto night mode (sunrise/sunset) | `brightness_service.dart`, `night_mode_advisor_service.dart`, `solar_service.dart` |
| Camera | Opt-in ML Kit eye-open / distance checks (no auto permission; camera closed after each sample) | `distance_service.dart`, `AndroidManifest` `CAMERA` |
| Tracking | GPS outdoor tracking | `DeviceDataService.startOutdoorTracking` |
| Tracking | Eye Health Timeline — sensor-event feed | `eye_timeline_service.dart`, `eye_timeline_screen.dart` *(merged 2026-10-23)* |
| Testing | Daily Eye Test + history (no self-diagnosis claims) | `eye_test_screen.dart` |
| Training | Guided eye exercises | `eye_exercise_screen.dart` |
| Reports | Weekly Eye Health Report + **real PDF export** (`pdf` package → A4 `eyecare_ai_report.pdf`) | `settings_more_provider.dart:203-234` |
| Home | Home-screen widget: score, streak, next-break countdown | `home_widget_service.dart`, `EyeWidgetProvider.kt` |
| Updates | In-app update from GitHub Releases + changelog + skip-version memory | `update_service.dart` |
| Data | Cloud backup/restore + JSON export + reset statistics | `cloud_backup_service.dart`, `settings_more_provider.dart` |
| Data | Habits survey → personalized 30-day targets, timestamped, newest-wins | `HabitsSurveyScreen.applySurveyTargets()` |
| AI | NVIDIA NIM chat assistant, ask-before-act confirm UI, auto-analysis on Home | `eye_chat_service.dart`, `chat_screen.dart`, `home_screen.dart` |
| AI | AI Sensitivity / AI Voice | ❌ spec only, not implemented |
| Guardian | Guardian reminder — native WorkManager check every 30 min; POSTs to a build-time HTTPS endpoint, `mailto:` fallback when none is set | `GuardianReminderWorker.kt`, `guardian_reminder_service.dart` |
| Release | **INTERNET permission added to the release manifest** — release builds previously had *no* network access (the permission existed only in the debug/profile manifests) | `android/app/src/main/AndroidManifest.xml` |
| Store | Rate App — store deep link, with GitHub Releases + feedback fallback while the listing is unpublished | `rate_app_service.dart`, `store_links.dart` |
| Legal | Privacy Policy + Terms published on GitHub Pages and linked from Settings; in-app text is a summary, not the full document | `legal_urls.dart`, `web/legal/` |
| i18n | English + Tiếng Việt | `LanguageProvider`, `AppStrings` |
| UX | App border/frame, dark mode, accent colour + font, units (m/cm/ft/in) | `ThemeProvider`, `SettingsProvider` |

### ⚙️ Settings — code-verified truth

- ✅ **Brightness Tips** — live (`settings_screen.dart:261`); the Aug-6 audit marked it ❌ wrongly.
- ✅ **Eye Exercise** — live (`eye_exercise_screen.dart`); Aug-6 audit marked it ❌ wrongly.
- ✅ **Backup / Restore** — live cloud backup (`cloud_backup_service.dart`); Aug-6 audit marked it ❌ wrongly.
- ✅ **AI Suggestions** — live NVIDIA NIM chat + Home auto-analysis; Aug-6 audit's "AI Chat disabled" was wrong.
- ✅ **Camera Permission** — declared and used (opt-in ML Kit checks). The Aug-6 note
  "not used (no camera features)" was **wrong**.
- 🟡 **Analytics** — `analytics_service.dart` is a **stub**: 2 open TODOs (`:57`, `:63`), no real event logging.
- 🟡 **AI Reminder Style** — the user's reminder style is injected into AI context
  (`chat_screen.dart:103`, `home_screen.dart:337`); no dedicated AI setting screen.
- ✅ **Privacy Policy / Terms** — published at `thongaccount.github.io/eye_care_ai/legal/privacy.html` and `…/legal/terms.html` (branch `gh-pages`), linked from Settings and Help; the in-app cards carry real summaries instead of placeholders.
- ❌ **Snooze Duration** — genuinely absent (zero references anywhere in the tree).
- ❌ **Blink Reminder** — genuinely absent; "blink" appears only as exercise/achievement copy.
- ❌ **Blue Light Filter** — strings only in `AppStrings`, no implementation (OS-level).
- ✅ **Rate App** — shipped (`rate_app_service.dart`). Opens the Play/App Store listing when published, otherwise falls back to GitHub Releases + a feedback e-mail. Flip `StoreLinks.playListingPublished` when the Play listing goes live.
- ✅ **Custom notification sound** — shipped with a Settings toggle; two notification channels are used because Android cannot change a channel's sound after creation.

### 🧹 Dead code — corrected (the old list was wrong)

| File | Verdict |
|---|---|
| `lib/providers/usage_provider.dart` | ❌ truly unreferenced → safe to delete |
| `lib/widgets/usage_pie_chart.dart` | ❌ truly unreferenced → safe to delete |
| `lib/services/storage_service.dart` | ❌ truly unreferenced → safe to delete |
| `lib/services/usage_service.dart` | ⚠️ **KEEP** — used by `setup_provider.dart:8` |
| `lib/services/eye_chat_service.dart` | ⚠️ **KEEP** — used by `chat_screen.dart:11` (live AI chat) |

> The Aug-6 list ("remove `UsageService`, `eye_chat_service.dart`") would have broken the
> setup flow and the AI assistant. Do not delete those two.

### 📚 Launch docs (new)

| Doc | What it gives you |
|---|---|
| `docs/web/README.md` | How the legal pages are published (gh-pages branch) and the verification checklist |
| `docs/web/handoff-legal-urls.md` | The legal-URL wiring map + the open legal questions |
| `docs/growth/app-listing.md` | Play + App Store listing copy, keywords, content rating, data-safety answers |
| `docs/growth/screenshots-outline.md` | Which real screen goes in each of the 8 Play / 10 App Store slots |
| `docs/growth/handoff-rate-app.md` | The rate-app flow (now applied) + the prompt rules for after launch |
| `docs/growth/analytics-events.md` | Event taxonomy for the analytics stub, with the PII rules |
| `docs/growth/retention-plan.md` | The 15 wishlist ideas mapped to what ships + the 3 retention moves |

### 🧱 Remaining technical debt

- Guardian email: the background trigger and the HTTPS send path have shipped, but **no endpoint is configured yet** — pass `GUARDIAN_EMAIL_ENDPOINT` at build time to enable automatic mail; without it the worker defers to the `mailto:` fallback.
- Analytics logging stub (2 TODOs).
- Stale string `habitSubtitle('breaks')` ("Front camera gaze detection" vs manual/auto-detect).
- Health Connect setup guide missing from the Permissions sheet.
- Focus-mode DND grant state not persisted (re-check banner reappears).
- iOS build blocked on Mac/Apple Developer account.
- No crash reporting (Sentry/Crashlytics).
- Keystore rotation still pending.
- Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 — Flutter warns these will be dropped soon.

---

## 🔄 NOTION REFRESH — 2026-10-15

> Source: Notion "Eye Care AI" (`3f2e05fc-8fdb-8219-bd37-01b9af46f1a0`) + 16 subpages,
> fetched 2026-10-15T14:35Z via mcp-gateway `notion-search`/`notion-fetch`.
> This section records **deltas vs the Aug-6 audit**; original sections below are untouched.

### 📋 PATCHES — status deltas
- [x] **Lock ứng dụng khi reach usage limit** — DONE since audit (was absent from PLAN).
  Shipped in `Release v1.3.0+alpha` (`feat/app-lock` merged to main + main-merger, branch deleted).
  *2026-10-26: the "usage-limit counter unfinished" note is **stale** — the counter is implemented and
  wired end-to-end (`usage_limit_provider.dart:66` ← `app_usage_monitor.dart:55` ← `main_shell.dart:97`/`:175`,
  fed by real UsageStats, daily reset + 5-minute extra-time grant). ⚠️ But the **enforcement never fires**:
  `armGate` always passes an empty blocked-app list (`app_usage_monitor.dart:69`), the native watcher only
  shows the gate for a package in that set (`AppLockOverlayManager.kt:169-175`), `showGateOverlay` has no
  Dart caller and `AppLockOverlay` (`app_lock_overlay.dart:17`) is never routed to. The UI preview works;
  the lock does not.*
- [~] **Guardian email** — Notion now *(Partial)* (PLAN had it ❌ missing). Still no background auto-send.
- [~] **Cập nhật trực tiếp (không xóa cài lại)** — Notion [x] + "*Đang cải thiện*":
  in-app update via GitHub Releases now implemented (`UpdateService`, manual check button,
  changelog screen, skip-version memory). PLAN's "not implemented" is stale.
- [ ] **Đổi model AI / provider khác** — still open (*"currently working on this"*, rate limits).
- [ ] **Chuỗi bài tập mắt → xếp hạng** — open.
- [ ] **Check thời gian ngoài trời còn bất ổn** — open.
- [x] **"Áp dụng mục tiêu" không cập nhật Habits** — FIXED: `applySurveyTargets()` with full
  `await`, timestamped targets (newest wins vs Firestore overwrite), `pref_survey_result` (12/10 log).
- [x] **Nghỉ mắt: hết countdown mới tính 1 lần + gửi通知** — FIXED (real-clock countdown,
  no make-up cycles after long absence, decimal-`target` cast fix) (12/10 log).
- [x] **Đăng nhập 1 lần, giữ phiên** — DONE (Firebase Auth persists the session, no plaintext
  password). ⚠️ **2026-10-26:** the old evidence `pref_guest_mode` **no longer exists** in `lib/`
  (0 hits) — persistence now runs through Firebase Auth's own `authStateChanges`
  (`auth_provider.dart:11`) / `currentUser` (`profile_provider.dart:29`). (12/10 log)
- [x] **Custom notification sound** — ✅ **SHIPPED** (2026-10-23, mobile P0): `res/raw/eye_break_alert.wav`
  + Settings toggle, two channels (system/custom) because Android cannot change a channel's sound
  after creation. *The 2026-10-15 "still open (both sources agree)" note was stale.*
- Note: todos marked `*` live on fork `ThongAccount/eye_care_ai`, merged upstream via `main-merger`.
  *2026-10-26: the fork lane has since been merged upstream through `main-merger` **and** into
  `main` — "đang ở fork / đợi merge" in the Notion page is stale.*

### 📓 Tiến độ — 13 dated logs (condensed)
- **31/08**: AI quick-prompts always visible; Eye Test Count habit (7-day count, tap → `EyeTestScreen`);
  water-reminder option in break settings; dark-room moved to native Kotlin (`lux=null` fix);
  OS repeating alarms for breaks; update notice badge → home-corner icon; AGP 8.11.1 / Kotlin 2.2.20 / minSdk 26.
- **01/09**: Eye Test latency — 700ms debounce removed, per-frame check; ML Kit eye-open probability
  for cover/close eye check; pause screen shows reason (too near/far, close left/right).
- **03/09**: dark-room anti-false-positive — lux ≥ 10 resets session; proximity-covered = skip, keep session.
- **04/09**: one alert per dark session; Eye Score = average of non-null factors (ex. 82);
  5-min sampling (lux + front-camera snapshot, camera closed immediately); no auto camera-permission;
  15-min sustained-dark rule + `Handler` re-check; chart label interval/tooltip/streak-badge/changelog/bilingual fixes.
- **05/09**: `distanceScore` dropped from total (marked 🧪 experimental); Mon-07:00 eye-test + 20:00 habit
  reminders (zoned schedules, toggles truly schedule/cancel); alarm state survives restart; sleep
  explanation fixed (phone-gap estimate + manual entry); dark-room needs Usage Access;
  `Long`-vs-`Int` crash fix in `DarkRoomForegroundService.kt`; Java 8 vs Gradle-11+ env blocker noted.
- **06/09**: rank/streak Firestore always-update fix; streak rule (score ≥ 80 that day; 0 if < 80 or
  app unopened — threshold later lowered, see 22/09); 🔥 badge always visible + tap for rules.
- **14/09**: cloud backup/restore (auto-download on re-login, instant backup on break-setting change);
  yesterday-vs-today comparison → max 3 suggestions; jitter-free reminder chips; async/null fixes.
- **22/09**: "Lưu ý & gợi ý hôm nay" card; day-over-day compare (screen/sleep/outdoor/breaks);
  next-break countdown card (hh:mm:ss, live, hidden if reminders off); streak threshold **80 → 60**,
  snapshot-based (no daily app-open required); keep both 20:00 + 23:55 notifications.
- **24/09**: trend deltas next to each `_ScoreCard` factor; snapshot extended (`outdoorMinutes`,
  `breaksCount`, backward compatible); fixed duplicate `DailySnapshotWorker` declaration
  (class lives **only** in `DailySnapshotWorker.kt`) + missing Kotlin imports.
- **26/09**: camera distance scoring removed (battery/privacy); AI "ask-before-act" confirm UI
  (Đồng ý / Từ chối, preview split from execute); AI gains vision-profile / reminder-style /
  auto-break actions.
- **27/09**: auto break ticks every 15s + per-second UI counter; outdoor GPS relaxed (nearest-location
  + higher sample rate); AI auto-review on Home (respects ask-before-act); auto/manual counters
  made mutually exclusive.
- **10/10**: `app_icon.dart` emoji-mapping gaps filled (Material icons); score circle 120 → 104;
  21:00 daily streak reminder (shares habit-tracking toggle); AI auto-analysis on every Home entry
  (≤8s habit-data wait, inline error card); outdoor → GPS-only (drop `lux ≥ 600`, `forceLocationManager`,
  no stale-location reuse); AI connectivity checklist (integrate.api.nvidia.com).
- **12/10**: break-mode fixes (auto = real clock; manual "Xong" only closes; >3 missed cycles shift
  forward); Environment score starts 100%/day minus dark-time share; survey-target Firestore guard
  (timestamps + instant backup); login persistence (`pref_guest_mode`); 21:00 streak-notif refresh;
  build hygiene (`HabitData`/`DeviceDataService` intact, `PATCHES_README.dart` stays out of `lib/`);
  AI-connection triage (network → Cold Boot / DNS 8.8.8.8 → `flutter run` log).

### ✨ Tính năng sắp tới — deltas vs wishlist table
Progress-annotated items from Notion (new info in **bold**): Focus-mode notification blocking **100%**;
water reminder **80%**; Duolingo-style rank **50%**; Achievements **20%**; Weekly Eye Health Report;
Habit streaks; Firebase sync; AI Eye Health Score; auto Outdoor Detection; home-screen widgets
(incl. **next-break countdown widget**); PDF export; eye-improvement chart; guided eye exercises;
**sunset/sunrise night-read mode (existing GPS)**; long-term week/month trend comparison.

### ⚙️ SETTINGS — deltas
Spec structure unchanged (Account / Eye Care / Screen / Units / Notifications / Language /
Date&Time / Data / AI / Privacy / About + Vision Profile / Reminder Style / Viewing Distance).
Confirmed details: 20-20-20 rule uses **20 feet** (keep Imperial); distance units m/cm/ft/in;
AI Sensitivity Low/Medium/High still spec-only.

### 💡 15 idea groups (Nhóm 1–5, condensed — full text in Notion page body)
1. Eye Health Score 2.0 (per-factor: screen/distance/environment/breaks/sleep) — ✅ largely live, but
   **the live score has 4 factors, not 5**: distance was dropped as a scoring factor on 05/09
   (battery/privacy — `loadDailyFactorScores` returns null for `distanceScore`,
   `device_data_service.dart:588`), and outdoor is a habit, not a score factor. The Notion mock
   still shows "📏 Khoảng cách 91%".
2. "Why did my score change?" attribution (e.g. −4 phone time, −2 dark-room, +1 breaks).
3. Daily Eye Report (+ 7/30-day views).
4. AI Weekly Eye Coach on aggregated data (NVIDIA NIM; **AI must not invent data**).
5. Adaptive Goals (auto tighten on success / relax on failure).
6. Streak Protection ("Recovery Day", 1×/week).
7. Eye Health Timeline (readable sensor-event feed).
8. Smart Notification Priority (merge/dedup concurrent alerts).
9. Distance History distribution (avg + week-over-week).
10. Sleep Pattern from night phone usage (labeled estimate, not exact bedtime).
11. Eye Test History (20/20 log, trend note, **no self-diagnosis**).
12. Achievements 2.0 (consistency / distance / breaks / environment).
13. Daily Quests (3/day, tied to Rank).
14. Personal Eye Profile (1–2 wks data → basis for all recommendations + coach).
15. "What if?" simulator (sliders, clearly labeled **estimate**, not medical prediction).

### Repo state at refresh
```
59dfffa Release v1.3.0+alpha
eef9226 merge: integrate upstream eye-test nav, dark-room service, changelog (5 commits)
2bf5c74 feat: Add changelog screen to display release history and notes
788d4ed feat: Enhance Eye Health Score features and improve chat functionality
56a2bd9 fix: Correct eye probability assignment for accurate UI representation in distance measurement
7cb31a6 feat: Implement DarkRoomForegroundService for continuous light monitoring and enhance battery optimization handling
```
Merged as `0ca34f1` (7 upstream commits, one merge commit) and pushed to `origin/main`
(Oct-16 session). *Correction 2026-10-23: `main-merger` sync done; the remaining upstream commit
(Eye Timeline, `eb39a7c`) was merged as `3bdfe1a` → `ba547c0` on `main` and shipped via Modal build 109.*

**2026-10-24 integration round** — three lanes merged into `main` and shipped:
mobile P0 (custom break alert sound, guardian-email background worker, the
release-manifest `INTERNET` fix), web/legal (published Privacy Policy + Terms +
bilingual landing page on the `gh-pages` branch), and growth (store listing pack,
screenshot outline, rate-app flow, analytics taxonomy, retention plan).
Modal build 110 verified the mobile lane; CI builds 83+ cut the releases.

---

## 🔄 NOTION CLI TREE — 2026-10-16

> Source: `ntn` CLI (user login flow, skill `notion-cli`), fetched 2026-10-16.
> Canonical pages designated by user (top-level unless noted):
> - Eye Care AI — `f6a51d95-e215-8330-8916-01b479b38b6b` (top-level, created 04:17Z)
> - ✨ **Tính năng sắp tới (CORRECT one)** — `3fb51d95-e215-8099-ba4c-efad19e90303`
>   (top-level, created 04:15Z) — NOT the `4a451d95-…` child copy under the Eye Care AI tree.
> - Tiến độ — `f7351d95-e215-82cf-8f6a-815d2c1428f9` (child of Eye Care AI tree) + 13 dated children:
>   - 31/08: `5a451d95-e215-8207-8083-814def2009bb`
>   - 01/09: `f1f51d95-e215-8393-b175-011be60caca8`
>   - 03/09: `bb451d95-e215-83ab-ba36-016f9ecee5e1`
>   - 04/09: `14351d95-e215-822c-8994-81883fc1b6c7`
>   - 05/09: `06851d95-e215-836c-ae0d-012e6be7271a`
>   - 06/09: `97d51d95-e215-8210-8cfe-81877a9f01a2`
>   - 14/09: `11951d95-e215-83d3-b35d-01ea50632d6d`
>   - 22/09: `f3551d95-e215-83bd-95de-810a0f92310c`
>   - 24/09: `5f351d95-e215-8265-8cb8-814771fc1390`
>   - 26/09: `f3451d95-e215-834d-b700-0167ae26bc32`
>   - 27/09: `0cc51d95-e215-830e-8de5-81fc4db9497b`
>   - 10/10: `e1a51d95-e215-835c-81e4-816ad9f0a7a2`
>   - 12/10: `d2a51d95-e215-8327-9dcd-81c9ed077a6f`
> - SETTINGS — `da451d95-e215-8271-a431-01cd5c38a811` (child of Eye Care AI tree)
>
> Content parity: spot-verified **identical** to § NOTION REFRESH 2026-10-15
> (PATCHES todos, 16 upcoming bullets, SETTINGS spec, dated-log samples) —
> no new actionable items, so content is NOT duplicated here; this section
> records provenance only.
> Note: the older MCP-gateway copy (`3f2e05fc-…`) returns `404 object_not_found`
> under this CLI login — the CLI tree above is authoritative. Same-session
> siblings (also created today, possibly related): top-level **To Do List**
> (`3fb51d95-e215-80a5-8a65-d43be9d2f27c`) + one database with 2 entries.

---

## 📋 PATCHES (26/07/2026)

> ⚠️ [HISTORICAL — Aug-6 audit body; superseded by § CODE-VERIFIED REFRESH.
> Rows below are kept verbatim except where a code-verified correction was applied on 2026-10-23.]

### Core UI/UX
- [x] **Viền app** — App border/frame styling
- [x] **Cài thêm ngôn ngữ Tiếng Việt** — Vietnamese localization (`LanguageProvider`, `AppStrings`)
- [x] **Chỉnh sửa chữ khi nền tối** (95%) — Dark mode text colors fixed (`AppTheme.dark`, `AppColors.darkSurface`)
- [x] **Đổi Eye Test thành cài nhắc nghỉ mắt sau…tg** — Replaced with Eye Break Reminder (`EyeBreakScreen`)
- [x] **Chỉnh sửa Habits: chỉ hiện progress, lấy thông tin từ đt** — Read-only habit cards, real device data (`HabitProvider` + `DeviceDataService`)
- [x] **Setting: đơn vị mét & ngôn ngữ từ toggle → danh sách chọn** — `_SelectableOption` widgets in `SettingsScreen`
- [x] **Habits Survey wizard** — Per-question flow, mandatory on first launch, retry from Home (`HabitsSurveyScreen`, `_AppGate`)

### Guardian & Notifications
- [~] **Thêm mục liên kết với email người bảo hộ** → Gửi mail nhắc nhở khi quá giờ dùng thiết bị
  - UI exists: `SettingsProvider.guardianEmail`, dialog in `SettingsScreen`
  - **Missing**: Background trigger when screen time > target; actual email send (currently only `mailto:` test)
  - *2026-10-23: mobile track is adding a `GUARDIAN_EMAIL_ENDPOINT` dart-define as the real send path.*
- [x] **Break Reminder: quay lại app vẫn hiện còn bao nhiêu phút, hết giờ hiện thông báo + chuông báo thức cho đến khi tắt**
  - Ongoing notification countdown (`NotificationService.updateOngoingCountdown`)
  - Repeating native alarm with `insistent` flag (`scheduleRepeatingBreakAlarm`)
  - Full-screen intent + vibration pattern

### Data & Persistence
- [x] **Dữ liệu ban đầu = 0, có chỗ lưu dữ liệu** — `SharedPreferences` keys, daily snapshots (`DeviceDataService`)
- [x] **Đổi đơn vị toàn bộ dự án vào Settings** — Metric/Imperial toggle (`SettingsProvider.useMetric`)

### Auto-Update
- [x] **Cập nhật ứng dụng không cần xóa cài lại** — In-app update via GitHub Releases
  - `update_service.dart`; manual "check for updates" button, changelog screen, skip-version memory
  - *The Aug-6 note "Not implemented" was stale — verified 2026-10-23.*

### Permissions & App Usage
- [x] **Quyền dữ liệu sử dụng ứng dụng trong Settings, giảm bước** — Direct intent to Usage Access (`DeviceDataService.openUsageAccessSettings`), brand-specific guides (`_showUsagePermissionGuide`)
- [x] **Thống kê: biểu đồ tròn phân chia thời gian theo app, tổng ở giữa, bấm xem chi tiết** — `_AppUsageBreakdownCard` in `StatisticsScreen`
- [x] **Khảo sát lần đầu: chỉnh ngôn ngữ, màu nền ở góc trên** — `AppBar` actions in `HabitsSurveyScreen`
- [x] **Thêm đơn vị cho Change Target (Habits)** — Unit labels in `_ChangeTargetSheet`
- [x] **Phone usage hiển thị sai** — Fixed via `MainActivity.getUsageBreakdown` (Digital Wellbeing parity)
- [x] **Chênh lệch App Usage vs Digital Wellbeing → thêm "Khác"** — `otherSeconds` aggregation in `_AppUsageBreakdownCard`
- [x] **Thống kê: số điểm + chuỗi, ngày chưa tới vẽ đoạn thẳng chưa hoàn thành** — `habitsCompletionPercent`, `streakDays`, null snapshots render as incomplete
- [x] **Lưu tùy chọn người dùng (Ngôn ngữ, màu nền...)** — All providers persist to `SharedPreferences`
- [x] **Outdoor Time khảo sát lần đầu hiển thị sai (mặc định 90p)** — Fixed via `HabitProvider.ready` future + `markSurveyCompleted` order

### Remaining Polish
- [x] **Thêm âm thanh custom cho thông báo** — ✅ SHIPPED 2026-10-23 (mobile P0):
  `android/app/src/main/res/raw/eye_break_alert.wav` (49 KB) + Settings toggle; two channels
  (system/custom) because Android cannot change a channel's sound after creation; falls back to
  the system sound if the raw asset is unusable. *The old "`_useCustomSound = false` hardcoded" note was stale.*
- [x] **Thoát vào lại app phải thêm quyền chuông thông báo** — `requestExactAlarmsPermission` (once), `requestIgnoreBatteryOptimizations` (once)

---

## 🎯 TARGET: Improve "Apply Target" Post-Survey

> **Status**: ✅ **Fully Implemented** in `HabitsSurveyScreen._buildResults`
> Re-verified against the code on **2026-10-26** (the Notion paste of the same spec) — the factors
> and ranges below are the ones the app really uses.

### Spec from Notion
- [x] Per-habit steps: Screen Time → Outdoor → Sleep → Eye Breaks
- [x] Each step shows: Current, Recommended, 4 target levels
- [x] **⭐ Recommended (default)**: `Target = Current + (Recommended - Current) × 0.5`
- [x] **🙂 Easy**: Closer to Current (less change) — **`× 0.25`** (`eye_health_standards.dart:79`)
- [x] **💪 Challenge**: Closer to Recommended (more change) — **`× 0.75`** (`eye_health_standards.dart:81`)
- [x] **✏️ Custom**: User input with validation range
  - Decrease metrics (Screen Time): `[Recommended, Current]`
  - Increase metrics (Outdoor, Sleep, Breaks): `[Current, Recommended]`
  - Error if outside range — `EyeHealthStandards.inCustomRange` (`eye_health_standards.dart:92`)
- [x] Summary screen "Your Personalized Plan" after 4 steps — `AppStrings.targetYourPlan` (`app_strings.dart:618`)
- [x] Only apply on "Apply" button; exit mid-way = no changes
- [x] Implemented in `EyeHealthStandards.calculateTargetValue` (`eye_health_standards.dart:72`) + `inCustomRange`
- [x] **5th level not in the Notion spec**: `TargetLevel.keep` ("Giữ nguyên") — offered when the habit is
  already at the standard, so the user can keep the current value instead of moving.

---

## ⚙️ SETTINGS SPEC (from Notion)

> ⚠️ [HISTORICAL — Aug-6 audit body; corrected against the code on 2026-10-23.
> See § CODE-VERIFIED REFRESH for the authoritative settings table.]

### 👤 Account / Tài khoản
- [x] Account / Tài khoản — Profile header in `SettingsScreen` (tap → `EditProfileScreen`)
- [x] Edit Profile / Chỉnh sửa hồ sơ — `EditProfileScreen` (name, avatar)
- [x] Sign out / Đăng xuất — `AuthProvider.signOut` via `_MenuItem`
- [x] Delete Account / Xóa tài khoản — `SettingsMoreProvider.deleteAccount` → `AuthService.deleteAccount`

### 👁️ Eye Care / Chăm sóc mắt
- [x] Eye Reminder / Nhắc nghỉ mắt — `EyeBreakScreen` (interval, start/stop)
- [x] Reminder Interval / Chu kỳ nhắc — ChoiceChips (10/20/30/45 min) in `EyeBreakScreen` + `ReminderProvider`
- [x] 20-20-20 Rule / Quy tắc 20-20-20 — Core logic in `EyeHealthStandards`, `EyeBreakScreen` UI
- [x] Eye Exercise / Bài tập mắt — **Implemented** (`eye_exercise_screen.dart`, guided exercises with moving dot)
- [ ] Blink Reminder / Nhắc chớp mắt — **Not implemented** (only exercise/achievement copy mentions "blink")

### 📱 Screen
- [x] Brightness Tips / Gợi ý độ sáng — **Implemented** (`settings_screen.dart:261` + `brightnessTipsBody`)
- [ ] Blue Light Filter / Bộ lọc ánh sáng xanh — **Not implemented** (OS-level only)
- [x] Dark Mode / Chế độ tối — `ThemeProvider` (Light/Dark/System)
- [x] Theme / Giao diện — Accent color (`AccentColorProvider`), Font (`FontProvider`)

### 📏 Units / Đơn vị
- [x] Distance Unit / Đơn vị khoảng cách
  - [x] Metric (Meters) / Mét
  - [x] Imperial (Feet) / Feet
  - Note: 20-20-20 uses **20 feet** → Imperial kept for this rule
  - Extended: Meter, Centimeter, Feet, Inch — `SettingsProvider.useMetric` + `AppStrings.habitUnit`

### 🔔 Notifications / Thông báo
- [x] Enable Notifications / Bật thông báo — Master toggle via individual toggles
- [x] Sound / Âm thanh — ✅ **shipped**: system sound **and** a custom alert
  (`res/raw/eye_break_alert.wav`) on a separate notification channel — Android cannot change a
  channel's sound after the channel exists
- [x] Vibration / Rung — `vibrationPattern` in `NotificationService._details`
- [ ] Snooze Duration / Thời gian hoãn — **Not implemented** (confirmed still absent 2026-10-23 — zero references in the tree)

### 🌐 Language / Ngôn ngữ
- [x] English
- [x] Tiếng Việt — `LanguageProvider.toggleVietnamese`

### 📅 Date & Time / Ngày & Giờ
- [x] 12-hour Clock / Định dạng 12 giờ
- [x] 24-hour Clock / Định dạng 24 giờ — `SettingsProvider.is24Hour`

### 📊 Data
- [x] Export Data / Xuất dữ liệu — `SettingsMoreProvider.exportMyData` (JSON + snapshots)
- [x] Backup / Sao lưu — **Implemented** (`cloud_backup_service.dart`, auto-backup on habit/break-setting change)
- [x] Restore / Khôi phục — **Implemented** (auto-download on re-login)
- [x] Reset Statistics / Đặt lại thống kê — `SettingsMoreProvider.deleteAllLocalData` (clears SharedPreferences)

### 🤖 AI
- [x] AI Suggestions / Gợi ý AI — **Live** (NVIDIA NIM chat, ask-before-act confirm UI, auto-analysis on Home)
- [~] AI Reminder Style / Kiểu nhắc của AI — **Partial**: the current reminder style is injected into the AI
  context (`chat_screen.dart:103`, `home_screen.dart:337`); no dedicated AI setting screen
- [ ] AI Voice / Giọng AI — **Not implemented**
- [ ] AI Sensitivity / Độ nhạy AI (Low/Medium/High) — **Not implemented** (spec only)

### 🔒 Privacy
- [x] Privacy / Quyền riêng tư — `SettingsMorePage` (Privacy section)
- [x] Permissions / Quyền truy cập — `_showPermissionSettings` bottom sheet (Usage, Location, Activity, Full-screen, Battery)
- [x] Camera Permission / Quyền Camera — **Used** (opt-in ML Kit eye-open/distance checks; declared in AndroidManifest, never auto-requested)
- [x] Usage Access / Quyền truy cập sử dụng — Direct intent + guides
- [~] Analytics / Chia sẻ dữ liệu phân tích — `SettingsMoreProvider.dataCollection` → `AnalyticsService` — **STUB**: 2 open TODOs (`analytics_service.dart:57`, `:63`), no real event logging yet

### ℹ️ About
- [x] About / Giới thiệu — `SettingsMorePage` (Help section)
- [x] Version / Phiên bản — Footer in `SettingsScreen`
- [x] Contact Us / Liên hệ — `feedback_form.dart` → email
- [x] Rate App / Đánh giá ứng dụng — **shipped** (`rate_app_service.dart`); opens the store listing once
  `StoreLinks.playListingPublished` flips to true, otherwise falls back to GitHub Releases + a feedback e-mail.
  *2026-10-26: this row previously said "Not implemented (no store link; handoff in flight)" — stale text.*
- [x] Privacy Policy / Chính sách quyền riêng tư — published at `thongaccount.github.io/eye_care_ai/legal/privacy.html`
  (HTTP 200), linked from Settings + Help; the in-app card carries a summary, not the full document.
  *2026-10-26: this row previously said "in-app static text only; hosted page in flight on `feat/web-legal`" — stale.*
- [x] Terms of Service / Điều khoản sử dụng — published at `thongaccount.github.io/eye_care_ai/legal/terms.html`
  (HTTP 200), linked from Settings + Help.
  *2026-10-26: this row previously said "in-app static text only; hosted page in flight on `feat/web-legal`" — stale.*

---

## 🎨 EYECARE-SPECIFIC SETTINGS (from Notion)

### 👓 Vision Profile / Hồ sơ thị lực
- [x] Glasses / Đeo kính
- [x] Contact Lens / Kính áp tròng
- [x] No Vision Correction / Không sử dụng kính — `SettingsProvider.visionProfile` + dialog

### 🎯 Reminder Style / Kiểu nhắc
- [x] Gentle / Nhẹ nhàng
- [x] Normal / Thông thường
- [x] Strict / Nghiêm ngặt — `SettingsProvider.reminderStyle` + dialog

### 📍 Viewing Distance / Khoảng cách xem
- [x] Auto Detect / Tự động phát hiện
- [x] Manual / Thủ công — `SettingsProvider.viewingDistanceMode` + dialog

---

## 🚀 FEATURE WISHLIST (from Notion "Cho riêng app EyeCare")

> ⚠️ [HISTORICAL — table below re-verified against the code on 2026-10-23.]

### 1. Habits Survey (✅ Done)
- [x] Questions: phone hrs, PC hrs, break freq, distance, sleep hrs, outdoor mins, brightness, glasses
- [x] Score + 30-day targets with progress bar
- [x] Implemented: `HabitsSurveyScreen` wizard (6 questions) → `EyeHealthStandards.evaluateSurvey`

### 2. Eye Test → Eye Break (✅ Done)
- [x] Interval picker: 20/30/45/60 min
- [x] Notification: "Đã đến lúc nghỉ mắt" + [Nghỉ ngay] [Bỏ qua]
- [x] Implemented: `EyeBreakScreen`

### 3. Additional Features

| Feature | Status | Notes |
|---------|--------|-------|
| 📊 Weekly Eye Health Report | ✅ | Weekly report + PDF export via the `pdf` package |
| 📈 Streak cho Habits | ✅ | `HabitProvider.streakDays`, `RankProvider`, leaderboard |
| 🏆 Achievement/Badges | 🟡 | `_AchievementPage` ships; unlock logic still partly hardcoded |
| ☁️ Đồng bộ Firebase | 🟡 | Leaderboard + cloud backup/restore (`cloud_backup_service.dart`); the backup **includes the daily snapshots** (`daily_snapshot_`, `daily_factors_` — `cloud_backup_service.dart:31-32`) and restores them, so habit history moves between devices. But it is a manual backup/restore, not live sync, and there is no conflict resolution |
| 🤖 AI Eye Health Score | ✅ | Live NVIDIA NIM assistant + Home auto-analysis (ask-before-act) |
| 🌳 Outdoor Detection (tự động) | ✅ | GPS-based in `DeviceDataService.startOutdoorTracking` |
| 📱 Widget màn hình chính | ✅ | `home_widget_service.dart` + `EyeWidgetProvider.kt` |
| 📤 Export PDF Report | ✅ | Real A4 PDF (`settings_more_provider.dart:203-234`) + JSON export |
| Xếp hạng/rank giống Duolingo | ✅ | `RankScreen`, `RankTiers` (7 tiers), Firestore leaderboard |
| Biểu đồ cải thiện mắt | ✅ | `StatisticsScreen` weekly/monthly line charts |
| Bài tập mắt có hướng dẫn | ✅ | `eye_exercise_screen.dart` (guided exercises) |
| Chế độ "Focus" chặn thông báo | ✅ | `FocusModeService` + `ReminderProvider.focusModeEnabled` |
| Widget countdown lần nghỉ tiếp theo | ✅ | Part of the home-screen widget |
| So sánh xu hướng tuần/tháng | ✅ | `StatisticsScreen` tabs (Weekly/Monthly) |
| Chế độ đọc ban đêm (sunset/sunrise GPS) | ✅ | `night_mode_advisor_service.dart` + `solar_service.dart` |
| Nhắc uống nước kèm nghỉ mắt | ✅ | `ReminderProvider` + `eye_break_screen.dart` |
| 👁️ Eye Health Timeline | ✅ | `eye_timeline_service.dart` + `eye_timeline_screen.dart` (merged 2026-10-23) |

---

## 📦 TECH DEBT & INFRASTRUCTURE

> ⚠️ [HISTORICAL — corrected against the code on 2026-10-23.]

- [x] **Auto-update via GitHub Releases** — ✅ done (`update_service.dart`)
- [x] **Custom notification sound** — ✅ done (`res/raw/eye_break_alert.wav`; separate notification channel)
- [ ] **Guardian Email auto-send** on screen time overuse
- [ ] **Remove dead code**: `usage_provider.dart`, `usage_pie_chart.dart`, `storage_service.dart`
  - ⚠️ Do **NOT** remove `usage_service.dart` (used by `setup_provider.dart`) or `eye_chat_service.dart` (used by `chat_screen.dart`)
- [ ] **Implement analytics logging** — `analytics_service.dart` is a stub (2 TODOs)
- [ ] **Fix stale strings**: `habitSubtitle('breaks')` ✅ **fixed** (now "Manually and auto-counted breaks",
  `app_strings.dart:687-702`); still open: remove the 3 unused Eye Test strings (`eyeTestHint`,
  `eyeTestInstruction`, `eyeTestTitle` — 0 call sites)
- [ ] **iOS build** — Resolve Mac/Apple Dev blocker
- [ ] **Crash reporting** (Sentry/Crashlytics)
- [ ] **Keystore rotation** (noted in project note)
- [x] ~~**Health Connect setup guide** in Permissions bottom sheet~~ — **OBSOLETE**: the app does not use
  Health Connect at all (the `health` package and the Health Connect permission were removed; sleep is
  estimated from usage times). There is nothing to guide.
- [ ] **Persist Focus Mode DND grant state** to avoid re-check banner — still open
  (`focus_mode_service.hasAccess()` → `FocusModeHandler.kt:42`, re-checked every time)

---

## 📝 GIT LOG (Recent)

```
ba547c0 feat: merge upstream Eye Timeline feature (event logging + timeline screen)
3bdfe1a feat: merge upstream Eye Timeline feature (event logging + timeline screen)
884e6f3 session: track a past OMP session
18c4ce0 docs: track PLAN.md
eb39a7c feat: Add Eye Timeline feature with event logging and display
595623f fix: implement onUpdate in EyeWidgetProvider with view binding
e29f196 fix: concrete EyeWidgetProvider subclass for home-screen widget
db0ae85 security: add shareable gitleaks config with nvapi- rule
7d42821 security!: share pre-push secret guard for nvapi- and common tokens
ba4f4de fix: redact leaked NIM key from local_env.dart to placeholder
71a5ee9 feat: home-screen widget with today score, streak and next break
b5878b9 feat: weekly eye health report reminder every Monday
2cfd84b feat: extend achievements with streak-starter and break milestones
c90e0dc feat: guided eye exercise sessions with animated dot
0dc92a4 feat: export weekly eye health report as real PDF
eb754b5 feat: auto night reading mode from sunset/sunrise GPS location
0ca34f1 merge: integrate upstream daily tracking, material icons, auto-break refactor (7 commits)
643fefe Refactor AutoBreakProvider for improved eye break reminders and UI synchronization
036505d feat: enhance eye-care tracking with daily check-in and streak reminders
b2d2254 feat: replace emoji with Material Icons for consistency across the app
```

---

## 🎯 PRIORITY ORDER FOR NEXT SPRINT

### P0 (Critical)
1. **Set a guardian endpoint** — the worker and send path shipped; supply `GUARDIAN_EMAIL_ENDPOINT` at build time or automatic mail stays off
2. **Replace the legal TODO chips** — entity name, jurisdiction, contact e-mail, effective date (blocks the Play submission)
3. **Create the Play Developer account + listing** — `docs/growth/app-listing.md` is ready to paste

### P1 (Code Health)
4. **Remove dead code** — `usage_provider.dart`, `usage_pie_chart.dart`, `storage_service.dart` (only — keep `usage_service.dart` + `eye_chat_service.dart`)
5. **Implement analytics logging** — `analytics_service.dart` TODOs at `:57` / `:63`; the event schema is specced in `docs/growth/analytics-events.md`
6. **Fix stale strings** — `habitSubtitle('breaks')` ✅ fixed; remove the 3 unused Eye Test strings
   (`eyeTestHint`, `eyeTestInstruction`, `eyeTestTitle` — 0 call sites)

### P2 (Features)
7. **Snooze Duration** — the one notification setting still missing
8. **Achievement/Badges dynamic** — Replace hardcoded `_AchievementPage` with real unlock logic
9. **Health Connect guide** — Add to Permissions bottom sheet
10. **Persist Focus Mode state** — Avoid re-check banner
11. ~~**Brightness Tips → actionable**~~ — ✅ **done**: `smart_brightness_dialog.dart:72` calls
    `BrightnessService.applySystemBrightness(target)`

### P3 (Platform)
12. **iOS build** — Mac/Apple Dev account
13. **Crash reporting** — Sentry/Crashlytics
14. **Keystore rotation**
15. **Toolchain bump** — Gradle 9.1+ / AGP 9.0.1+ / Kotlin 2.3.20+ before Flutter drops support