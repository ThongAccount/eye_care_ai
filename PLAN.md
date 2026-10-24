# EyeCare AI — Master Plan (from Notion Page)

> Source: Notion page "PATCHES" (26/07/2026) + SETTINGS spec + Feature wishlist
> Status legend: ✅ Done · 🟡 Partial · ❌ Not Started
> **Current truth: § CODE-VERIFIED REFRESH — 2026-10-23 (top of file).**
> Historical layers kept for provenance:
> - § NOTION REFRESH (2026-10-15) — Notion snapshot deltas.
> - § Aug-6 audit (below) — ⚠️ **HISTORICAL, superseded.** Its ❌ rows were re-verified
>   against the code on 2026-10-23 and several were wrong (features that shipped since).
>   Sections marked `[HISTORICAL]` are retained verbatim for the record; use the
>   code-verified tables instead of them.

---

## ✅ CODE-VERIFIED REFRESH — 2026-10-23

> Method: every row below was checked against the actual source tree on 2026-10-23
> (`main` @ `ba547c0`, after the Eye-Timeline merge). Notion was **not** consulted — this
> section is ground truth for what is actually in the app today.
> Legend: ✅ shipped · 🟡 partial/stub · ❌ genuinely absent.

### 📦 Shipped features (verified in code)

| Area | Feature | Evidence |
|---|---|---|
| Reminders | 20-20-20 break reminders + persistent countdown notification + repeating native alarm + vibration | `NotificationService`, `ReminderProvider`, `eye_break_screen.dart` |
| Reminders | Water reminder tied to break cycles | `ReminderProvider`, `eye_break_screen.dart` |
| Reminders | Focus mode (notification blocking) | `focus_mode_service.dart` |
| Reminders | Custom notification sound | ✅ `res/raw/eye_break_alert.wav` + Settings toggle; two channels (system / custom) because Android cannot change a channel's sound after creation; auto-falls back to the system sound if the raw file is unusable *(mobile P0, 2026-10-23)* |
| Scoring | Eye Health Score (screen / breaks / environment / sleep / outdoor) with day-over-day deltas | `statistics_screen.dart`, `HabitProvider` |
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
  Beta: overlay finished + testable, usage-limit counter unfinished. Shipped in
  `Release v1.3.0+alpha` (`feat/app-lock` merged to main + main-merger, branch deleted).
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
- [x] **Đăng nhập 1 lần, giữ phiên** — DONE (Firebase persists session, `pref_guest_mode`,
  no plaintext password) (12/10 log).
- [ ] **Custom notification sound** — still open (both sources agree).
- Note: todos marked `*` live on fork `ThongAccount/eye_care_ai`, merged upstream via `main-merger`.

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
1. Eye Health Score 2.0 (per-factor: screen/distance/environment/breaks/sleep) — ✅ largely live.
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
- [ ] **Thêm âm thanh custom cho thông báo** — `_useCustomSound = false` hardcoded; need `eye_break_alert.mp3` in `res/raw/`
- [x] **Thoát vào lại app phải thêm quyền chuông thông báo** — `requestExactAlarmsPermission` (once), `requestIgnoreBatteryOptimizations` (once)

---

## 🎯 TARGET: Improve "Apply Target" Post-Survey

> **Status**: ✅ **Fully Implemented** in `HabitsSurveyScreen._buildResults`

### Spec from Notion
- [x] Per-habit steps: Screen Time → Outdoor → Sleep → Eye Breaks
- [x] Each step shows: Current, Recommended, 4 target levels
- [x] **⭐ Recommended (default)**: `Target = Current + (Recommended - Current) × 0.5`
- [x] **🙂 Easy**: Closer to Current (less change)
- [x] **💪 Challenge**: Closer to Recommended (more change)
- [x] **✏️ Custom**: User input with validation range
  - Decrease metrics (Screen Time): `[Recommended, Current]`
  - Increase metrics (Outdoor, Sleep, Breaks): `[Current, Recommended]`
  - Error if outside range
- [x] Summary screen "Your Personalized Plan" after 4 steps
- [x] Only apply on "Apply" button; exit mid-way = no changes
- [x] Implemented in `EyeHealthStandards.calculateTargetValue` + `inCustomRange`

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
- [x] Sound / Âm thanh — **Partial**: uses system alarm sound; [ ] Custom sound (see PATCHES)
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
- [ ] Rate App / Đánh giá ứng dụng — **Not implemented** (no store link; handoff in flight on `docs/growth-store-launch`)
- [~] Privacy Policy / Chính sách quyền riêng tư — in-app static text only; hosted page in flight on `feat/web-legal`
- [~] Terms of Service / Điều khoản sử dụng — in-app static text only; hosted page in flight on `feat/web-legal`

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
| ☁️ Đồng bộ Firebase | 🟡 | Leaderboard + cloud backup/restore (`cloud_backup_service.dart`); no cross-device habit sync |
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
- [ ] **Custom notification sound** (`eye_break_alert.mp3` in `res/raw/`)
- [ ] **Guardian Email auto-send** on screen time overuse
- [ ] **Remove dead code**: `usage_provider.dart`, `usage_pie_chart.dart`, `storage_service.dart`
  - ⚠️ Do **NOT** remove `usage_service.dart` (used by `setup_provider.dart`) or `eye_chat_service.dart` (used by `chat_screen.dart`)
- [ ] **Implement analytics logging** — `analytics_service.dart` is a stub (2 TODOs)
- [ ] **Fix stale strings**: `habitSubtitle('breaks')` says "Front camera gaze detection" but uses manual/auto-detect
- [ ] **iOS build** — Resolve Mac/Apple Dev blocker
- [ ] **Crash reporting** (Sentry/Crashlytics)
- [ ] **Keystore rotation** (noted in project note)
- [ ] **Health Connect setup guide** in Permissions bottom sheet
- [ ] **Persist Focus Mode DND grant state** to avoid re-check banner

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
6. **Fix stale strings** — `habitSubtitle('breaks')` *(fixed in mobile P0)*, remove unused Eye Test strings

### P2 (Features)
7. **Snooze Duration** — the one notification setting still missing
8. **Achievement/Badges dynamic** — Replace hardcoded `_AchievementPage` with real unlock logic
9. **Health Connect guide** — Add to Permissions bottom sheet
10. **Persist Focus Mode state** — Avoid re-check banner
11. **Brightness Tips → actionable** — text exists; wire it to the brightness service

### P3 (Platform)
12. **iOS build** — Mac/Apple Dev account
13. **Crash reporting** — Sentry/Crashlytics
14. **Keystore rotation**
15. **Toolchain bump** — Gradle 9.1+ / AGP 9.0.1+ / Kotlin 2.3.20+ before Flutter drops support