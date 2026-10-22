# EyeCare AI — Master Plan (from Notion Page)

> Source: Notion page "PATCHES" (26/07/2026) + SETTINGS spec + Feature wishlist
> Status: Based on codebase audit (2026-08-06) — ✅ Done, 🟡 Partial, ❌ Not Started
> Refreshed: Notion snapshot 2026-10-15 merged in § NOTION REFRESH below — Aug-6 audit preserved as-is underneath.

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
(Oct-16 session). `main-merger` sync still pending.

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

### Core UI/UX
- [x] **Viền app** — App border/frame styling
- [x] **Cài thêm ngôn ngữ Tiếng Việt** — Vietnamese localization (`LanguageProvider`, `AppStrings`)
- [x] **Chỉnh sửa chữ khi nền tối** (95%) — Dark mode text colors fixed (`AppTheme.dark`, `AppColors.darkSurface`)
- [x] **Đổi Eye Test thành cài nhắc nghỉ mắt sau…tg** — Replaced with Eye Break Reminder (`EyeBreakScreen`)
- [x] **Chỉnh sửa Habits: chỉ hiện progress, lấy thông tin từ đt** — Read-only habit cards, real device data (`HabitProvider` + `DeviceDataService`)
- [x] **Setting: đơn vị mét & ngôn ngữ từ toggle → danh sách chọn** — `_SelectableOption` widgets in `SettingsScreen`
- [x] **Habits Survey wizard** — Per-question flow, mandatory on first launch, retry from Home (`HabitsSurveyScreen`, `_AppGate`)

### Guardian & Notifications
- [ ] **Thêm mục liên kết với email người bảo hộ** → Gửi mail nhắc nhở khi quá giờ dùng thiết bị
  - UI exists: `SettingsProvider.guardianEmail`, dialog in `SettingsScreen`
  - **Missing**: Background trigger when screen time > target; actual email send (currently only `mailto:` test)
- [x] **Break Reminder: quay lại app vẫn hiện còn bao nhiêu phút, hết giờ hiện thông báo + chuông báo thức cho đến khi tắt**
  - Ongoing notification countdown (`NotificationService.updateOngoingCountdown`)
  - Repeating native alarm with `insistent` flag (`scheduleRepeatingBreakAlarm`)
  - Full-screen intent + vibration pattern

### Data & Persistence
- [x] **Dữ liệu ban đầu = 0, có chỗ lưu dữ liệu** — `SharedPreferences` keys, daily snapshots (`DeviceDataService`)
- [x] **Đổi đơn vị toàn bộ dự án vào Settings** — Metric/Imperial toggle (`SettingsProvider.useMetric`)

### Auto-Update
- [ ] **Cập nhật ứng dụng không cần xóa cài lại** — Auto-update via GitHub Releases checking
  - **Not implemented**: No `upgrader` package, no version check on startup

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

### 👤 Account / Tài khoản
- [x] Account / Tài khoản — Profile header in `SettingsScreen` (tap → `EditProfileScreen`)
- [x] Edit Profile / Chỉnh sửa hồ sơ — `EditProfileScreen` (name, avatar)
- [x] Sign out / Đăng xuất — `AuthProvider.signOut` via `_MenuItem`
- [x] Delete Account / Xóa tài khoản — `SettingsMoreProvider.deleteAccount` → `AuthService.deleteAccount`

### 👁️ Eye Care / Chăm sóc mắt
- [x] Eye Reminder / Nhắc nghỉ mắt — `EyeBreakScreen` (interval, start/stop)
- [x] Reminder Interval / Chu kỳ nhắc — ChoiceChips (10/20/30/45 min) in `EyeBreakScreen` + `ReminderProvider`
- [x] 20-20-20 Rule / Quy tắc 20-20-20 — Core logic in `EyeHealthStandards`, `EyeBreakScreen` UI
- [ ] Eye Exercise / Bài tập mắt — **Not implemented** (placeholder in `HabitData.reading` = "Eye Test Count", `isComingSoon: true`)
- [ ] Blink Reminder / Nhắc chớp mắt — **Not implemented**

### 📱 Screen
- [ ] Brightness Tips / Gợi ý độ sáng — **Not implemented**
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
- [ ] Snooze Duration / Thời gian hoãn — **Not implemented**

### 🌐 Language / Ngôn ngữ
- [x] English
- [x] Tiếng Việt — `LanguageProvider.toggleVietnamese`

### 📅 Date & Time / Ngày & Giờ
- [x] 12-hour Clock / Định dạng 12 giờ
- [x] 24-hour Clock / Định dạng 24 giờ — `SettingsProvider.is24Hour`

### 📊 Data
- [x] Export Data / Xuất dữ liệu — `SettingsMoreProvider.exportMyData` (JSON + snapshots)
- [ ] Backup / Sao lưu — **Not implemented** (Firebase sync only for leaderboard)
- [ ] Restore / Khôi phục — **Not implemented**
- [x] Reset Statistics / Đặt lại thống kê — `SettingsMoreProvider.deleteAllLocalData` (clears SharedPreferences)

### 🤖 AI
- [ ] AI Suggestions / Gợi ý AI — **Disabled** (NVIDIA NIM test only)
- [ ] AI Reminder Style / Kiểu nhắc của AI — **Not implemented**
- [ ] AI Voice / Giọng AI — **Not implemented**
- [ ] AI Sensitivity / Độ nhạy AI (Low/Medium/High) — **Not implemented**

### 🔒 Privacy
- [x] Privacy / Quyền riêng tư — `SettingsMorePage` (Privacy section)
- [x] Permissions / Quyền truy cập — `_showPermissionSettings` bottom sheet (Usage, Location, Activity, Full-screen, Battery)
- [ ] Camera Permission / Quyền Camera — **Not used** (no camera features)
- [x] Usage Access / Quyền truy cập sử dụng — Direct intent + guides
- [x] Analytics / Chia sẻ dữ liệu phân tích — `SettingsMoreProvider.dataCollection` → `AnalyticsService`

### ℹ️ About
- [x] About / Giới thiệu — `SettingsMorePage` (Help section)
- [x] Version / Phiên bản — Footer in `SettingsScreen`
- [x] Contact Us / Liên hệ — `feedback_form.dart` → email
- [x] Rate App / Đánh giá ứng dụng — **Not implemented** (no store link)
- [ ] Privacy Policy / Chính sách quyền riêng tư — **Not implemented** (no web URL)
- [ ] Terms of Service / Điều khoản sử dụng — `SettingsMorePage` (Terms section, static content)

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
| 📊 Weekly Eye Health Report | ❌ | Email/PDF export not implemented |
| 📈 Streak cho Habits | ✅ | `HabitProvider.streakDays`, `RankProvider`, leaderboard |
| 🏆 Achievement/Badges (20%) | 🟡 | `_AchievementPage` exists (hardcoded), not dynamic |
| ☁️ Đồng bộ Firebase | 🟡 | Leaderboard only; no habit/cloud backup sync |
| 🤖 AI Eye Health Score | ❌ | AI Chat disabled |
| 🌳 Outdoor Detection (tự động) | ✅ | GPS-based in `DeviceDataService.startOutdoorTracking` |
| 📱 Widget màn hình chính | ❌ | Not implemented |
| 📤 Export PDF Report | 🟡 | Text export only (`downloadEyeHealthReport`) |
| Xếp hạng/rank giống Duolingo (50%) | ✅ | `RankScreen`, `RankTiers` (7 tiers), Firestore leaderboard |
| Biểu đồ cải thiện mắt | ✅ | `StatisticsScreen` weekly/monthly line charts |
| Bài tập mắt có hướng dẫn | ❌ | `HabitData.reading` = "Eye Test Count" (coming soon) |
| Chế độ "Focus" chặn thông báo | ✅ | `FocusModeService` + `ReminderProvider.focusModeEnabled` |
| Widget countdown lần nghỉ tiếp theo | ❌ | Home screen widget not implemented |
| So sánh xu hướng tuần/tháng | ✅ | `StatisticsScreen` tabs (Weekly/Monthly) |
| Chế độ đọc ban đêm (sunset/sunrise GPS) | ❌ | Not implemented |
| Nhắc uống nước kèm nghỉ mắt | ❌ | Not implemented |

---

## 📦 TECH DEBT & INFRASTRUCTURE

- [ ] **Auto-update via GitHub Releases** (upgrader package)
- [ ] **Custom notification sound** (`eye_break_alert.mp3` in `res/raw/`)
- [ ] **Guardian Email auto-send** on screen time overuse
- [ ] **Remove dead code**: `UsageProvider`, `UsageService`, `UsagePieChart`, `AppUsage`, `storage_service.dart`, `eye_chat_service.dart`
- [ ] **Fix stale strings**: `habitSubtitle('breaks')` says "Front camera gaze detection" but uses manual/auto-detect
- [ ] **iOS build** — Resolve Mac/Apple Dev blocker
- [ ] **Crash reporting** (Sentry/Crashlytics)
- [ ] **Keystore rotation** (noted in project note)
- [ ] **Health Connect setup guide** in Permissions bottom sheet
- [ ] **Persist Focus Mode DND grant state** to avoid re-check banner

---

## 📝 GIT LOG (Recent)

```
b2c826d feat: Implement Eye Break feature with Focus Mode and Notification enhancements
8a30e67 fix: Update model string to include free version for EyeChatService
42602ea Add push trigger for main branch to build APK workflow
a3bfdb0 feat: Add focus mode strings and integrate rank teaser card in home screen
ceb86a3 feat: Implement ranking system with focus mode and leaderboard
5ae205e Alpha v1.2 Refactor MainShell and SettingsScreen; remove unused imports and simplify navigation
93648af Enhance app features, improve workflows, and update configurations (#1)
b81d890 Final release Alpha v1.1: feat: add usage permission guide for various device brands in settings
e28710e feat: update AI model to google/gemma-4-31b-it:free; add release keystore
e2a79e3 Cap nhat keystore va SHA-1 moi
c637320 Cap nhat google-services.json voi SHA-1 keystore moi
725fec2 feat: update google-services.json and chat handling; fix bugs and improve user experience
7bebf79 Go keystore va key.properties khoi git, dung GitHub Secrets thay the
37cb6f7 Gỡ keystore & key.properties khỏi git, dùng GitHub Secrets thay thế
1d40eee Alpha v1.0 feat: update UI components to use dynamic theme colors for improved consistency
2049fa9 feat: remove android_alarm_manager_plus dependency and refactor notification handling for break reminders
f521a1e feat: update AndroidManifest and various components to support android_alarm_manager_plus; fix bugs and impro...
6fbe0d6 feat: integrate android_alarm_manager_plus for repeating break reminders and enhance notification service
b4db60d feat: update notification service to handle custom sound and improve error logging for alarm scheduling
b6258ce feat: update OpenRouter API key and model in EyeChatService; add debug prints in chat screen
```

---

## 🎯 PRIORITY ORDER FOR NEXT SPRINT

### P0 (Critical)
1. **Guardian Email auto-reminder** — Background check + mailto:/SMTP send
2. **Auto-update (upgrader)** — Check GitHub Releases on startup
3. **Custom notification sound** — Add `eye_break_alert.mp3`, enable `_useCustomSound`

### P1 (Code Health)
4. **Remove dead code** — `UsageProvider`, `UsageService`, `UsagePieChart`, `AppUsage`, `storage_service.dart`, `eye_chat_service.dart`
5. **Fix stale strings** — `habitSubtitle('breaks')`, remove unused Eye Test strings

### P2 (Features)
6. **Achievement/Badges dynamic** — Replace hardcoded `_AchievementPage` with real unlock logic
7. **Health Connect guide** — Add to Permissions bottom sheet
8. **Persist Focus Mode state** — Avoid re-check banner

### P3 (Platform)
9. **iOS build** — Mac/Apple Dev account
10. **Crash reporting** — Sentry/Crashlytics
11. **PDF Export** — Replace text report with PDF
12. **Home screen widget** — Countdown + habit summary