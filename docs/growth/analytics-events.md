# Analytics event taxonomy — implementation handoff

**Owner:** next implementation round (not this branch). **Author:** GrowthLead.
**Scope:** the app's analytics service is a **stub** — `lib/services/analytics_service.dart`
has two open TODOs (`:57` for `logEvent`, `:63` for `logScreenView`) and performs no real
logging. This document defines the schema so that, when it is implemented, the events are
correct from day one and the Play Data Safety form stays truthful.

---

## 1. What exists today (so nobody re-discovers it)

| Piece | State | File |
|---|---|---|
| `AnalyticsService.instance` | Singleton, consent + toggle gate | `lib/services/analytics_service.dart` |
| `isEnabled` | Persisted in `SharedPreferences` under `data_collection_enabled`, **defaults to `true`** | `analytics_service.dart:16-37` |
| `consentGiven` / `consent_timestamp` | Persisted; set by the first-launch consent screen | `analytics_service.dart:17-50` |
| `logEvent(name, [params])` | **No-op** (TODO at `:57`) | `analytics_service.dart:55` |
| `logScreenView(name)` | **No-op** (TODO at `:63`) | `analytics_service.dart:61` |
| User-facing switch | Settings → Privacy → "Data Collection" | `lib/widgets/privacy_security_section.dart:26-31` |
| Firebase Analytics | **Not enabled** — no `firebase_analytics` dependency in `pubspec.yaml` | — |

**Decision to make now (recommended):** keep the default endpoint **empty**
(`ANALYTICS_ENDPOINT` unset ⇒ nothing is ever sent). The app then keeps behaving exactly
as today, the Play Data Safety form can honestly say "no analytics are collected", and
enabling collection becomes a build-time choice rather than a behaviour change.

---

## 2. Privacy rules — non-negotiable

> **Rule 0: no measurement of the user's eyes, body or screen habits ever leaves the device.**

The app's inputs to the Eye Health Score are screen time, break completion, ambient light
and estimated sleep. Transmitting any of them — even bucketed, even one day — lets a
receiver reconstruct the user's health profile. So:

### 2.1 Never log (denylist, enforced by review)

| Forbidden | Why |
|---|---|
| Eye Health Score (value, delta, factor %, bucket) | the score itself, and its parts, are health-adjacent |
| Screen-time minutes, sleep hours, outdoor minutes, reading minutes | direct score inputs |
| Break-completion counts or rates per day | direct score input |
| Light/lux samples, "low light" duration | direct score input |
| Eye-test results (per-eye level, contrast level, the result label) | health measurement |
| Viewing distance in cm, eye-open ratio | camera-derived measurement |
| AI chat text, AI replies, the habit "context block" sent to NIM | free-text health context |
| Location (coordinates, place names, GPS samples) | location data |
| Installed app names / package names / the app-usage breakdown | third-party app inventory |
| E-mail address, display name, guardian e-mail, the leaderboard display name and profile-photo URL | direct identifier |
| Hardware identifiers (IMEI, Android ID, MAC, advertising ID) | prohibited |
| Exact timestamps of sensor events or activity | reconstructable timeline |

### 2.2 Allowed properties (allowlist — everything else is dropped at runtime)

| Property | Type | Notes |
|---|---|---|
| `install_id` | string (UUID v4) | Random, generated on first launch, stored in `SharedPreferences`, rotatable via "Delete All Local Data" / "Delete Account". **Not** derived from hardware. Must be declared in Play Data Safety ("Device or other IDs", not used for tracking). |
| `session_id` | string (UUID v4) | New value each time the app is foregrounded |
| `app_version`, `build_number` | string / int | From `PackageInfo` |
| `platform` | enum | `android` / `ios` |
| `locale` | enum | `en` / `vi` |
| `days_since_install` | int | Day index, not a calendar date |
| `consent_given`, `data_collection_enabled` | bool | Consent state at emit time |
| `source` | enum | e.g. `manual`, `auto_detected`, `notification_tap`, `app_open` |
| `interval_minutes_bucket` | enum | `5`, `10`, `15`, `20`, `30`, `45`, `60plus` — the *user's chosen reminder interval*, a preference, not a measurement |
| `duration_bucket` | enum | `<10s`, `10-60s`, `60-300s`, `300s+` — interaction durations only |
| `count_*` | int | Counts of **UI interactions** (questions answered, permissions granted), never counts of measured behaviour |
| `has_*` | bool | Capability flags (camera available, listing published) |
| `result_state` | enum | `completed`, `abandoned`, `failed` |
| `tier_id` | enum | **Review before use** — the rank tier is a coarse function of streak days, which is itself a function of the score. If the reviewer is uncomfortable, drop it and keep the milestone events (`streak_started`, `streak_broken`). |

### 2.3 Other rules

- No health data in **event names** either — names describe interactions, not states.
- Events are only sent after `consentGiven == true`. The consent screen already gates the
  first launch, so this holds automatically as long as `AnalyticsService.init()` is called
  after the consent gate.
- The Data Collection switch must stop collection immediately, including the offline queue
  (flush the queue on disable, then stop).
- Nothing is shared with ad networks, and no third-party analytics SDK is added. The
  endpoint is **first-party or self-hosted** (the code comment in `analytics_service.dart:8`
  already names self-hosted PostHog as the intended direction).

---

## 3. Naming conventions

- `snake_case`, past-tense verb or noun phrase: `break_completed`, `survey_started`.
- One event = one user-visible moment. Never reuse a name for two meanings.
- Version the schema, not the names: bump `schema_version` in the envelope when the
  meaning of an event changes; keep old names stable.

---

## 4. The funnel (the eight requested steps)

| # | Funnel step | Event that marks it | Extra events for diagnosis | Conversion metric |
|---|---|---|---|---|
| 1 | Install | `install_completed` | `consent_accepted`, `consent_declined` | installs |
| 2 | Habits survey | `habits_survey_completed` | `habits_survey_started`, `habits_survey_abandoned` | survey_completed / install_completed |
| 3 | First break reminder | `break_completed` (first occurrence) | `break_reminder_scheduled`, `break_reminder_disabled` | break_completed / survey_completed |
| 4 | First eye test | `eye_test_completed` | `eye_test_started`, `eye_test_abandoned` | eye_test_completed / install_completed |
| 5 | Streak started | `streak_started` | `streak_broken`, `streak_milestone` | streak_started / break_completed |
| 6 | Rank / share | `rank_viewed` + `share_action_completed` | `streak_card_shared` *(proposed, not implemented)* | rank_viewed / streak_started |
| 7 | Weekly report opened | `weekly_report_opened` | `report_exported` | weekly_report_opened / install_completed |
| 8 | In-app update | `update_installed` | `update_check_completed`, `update_available_shown`, `update_download_started`, `update_skipped` | update_installed / install_completed |

> **No baseline exists.** There is no analytics today, so every rate above starts at
> "unknown". The first two weeks of data set the baseline; do not invent a target number
> before then. Suggested decision rule once a baseline exists: flag any step whose
> conversion is **below half of the median of the other steps** — that is the step worth
> fixing first.

---

## 5. Event catalogue

Every row: **name · trigger · properties · notes.** All properties are from the allowlist
in §2.2; anything not listed there is a bug.

### 5.1 Lifecycle, consent, onboarding

| Event | Trigger | Properties |
|---|---|---|
| `consent_accepted` | User taps "Accept & Continue" on `ConsentScreen` | `locale`, `app_version` |
| `consent_declined` | User taps "Decline" (app exits) | `locale` |
| `install_completed` | First successful app start **after** consent is stored | `locale`, `platform`, `app_version`, `build_number`, `days_since_install` |
| `permissions_prompt_shown` | A permission explainer is displayed | `permission_kind` (`usage_access`, `notifications`, `camera`, `location`, `battery_optimization`, `full_screen_intent`, `exact_alarm`, `notification_policy`) |
| `permission_result` | The user comes back from the system settings screen | `permission_kind`, `result_state` (`granted`, `denied`, `skipped`) |
| `onboarding_setup_completed` | Setup wizard finished | `count_permissions_granted` |
| `habits_survey_started` | `HabitsSurveyScreen` opens | `survey_revision` |
| `habits_survey_step_answered` | One question answered | `step_index`, `is_final` — **never the answer itself** |
| `habits_survey_completed` | Targets applied (`applySurveyTargets()`) | `count_questions`, `count_targets_set`, `duration_bucket` |
| `habits_survey_abandoned` | User leaves the survey mid-way | `step_index` |
| `habits_target_changed` | User edits a target manually | `habit_kind` (`breaks`, `phone`, `sleep`, `outdoor`, `reading`) only — the **target value is not logged**: targets are the yardstick the score is measured against, so the value is health-adjacent context. |

### 5.2 Breaks and reminders

| Event | Trigger | Properties |
|---|---|---|
| `break_reminder_scheduled` | Reminders armed (first time in a session) | `interval_minutes_bucket`, `has_auto_detect`, `has_focus_mode`, `has_water_reminder` |
| `break_reminder_disabled` | Reminders turned off | `interval_minutes_bucket` |
| `break_completed` | A break is recorded (manual "done", or auto-detected) | `source` (`manual`, `auto_detected`) |
| `break_skipped` | User dismisses the time-up alert without completing | `source` |
| `focus_mode_activated` | Notification blocking engaged | `duration_bucket` |

**Caveat to document in code:** the reminder is delivered by a native alarm
(`NotificationService.scheduleRepeatingBreakAlarm`). If the process is dead, the Dart side
cannot observe the alarm firing — so "the reminder fired" is **not** directly measurable.
The honest proxies are `break_reminder_scheduled` (we armed it) and `break_completed` (the
user acted on it). Do not emit a fake `break_reminder_fired` from the Dart side.

### 5.3 Eye test, exercises, timeline

| Event | Trigger | Properties |
|---|---|---|
| `eye_test_started` | `EyeTestScreen` intro → start | `attempt_index` (`1`, `2`, `3plus`) |
| `eye_test_completed` | Result card shown | `attempt_index`, `duration_bucket`, `count_steps_completed` |
| `eye_test_abandoned` | User leaves before the result | `attempt_index`, `step_index` — **no result values** |
| `exercise_started` | `EyeExerciseScreen` starts | `exercise_id` (enum of the guided exercises) |
| `exercise_completed` | Guided exercise finished | `exercise_id`, `duration_bucket` |
| `timeline_viewed` | `EyeTimelineScreen` opened | `count_events_bucket` (`0`, `1-5`, `6-20`, `20plus`), `day_index` |

### 5.4 Score, streak, ranks

| Event | Trigger | Properties |
|---|---|---|
| `score_viewed` | Home score card rendered (throttle: once per session) | `factor_count_available` (int count of factors with data — a count, not a value) |
| `score_factor_explained` | User taps a factor row to see how it is calculated | `factor_kind` (`screen_time`, `environment`, `eye_breaks`, `sleep`) |
| `streak_started` | `streakDays` transitions 0 → 1 | — |
| `streak_broken` | `streakDays` resets to 0 | `days_since_last_streak_event` |
| `streak_milestone` | Streak crosses 3 / 10 / 20 / 40 / 70 / 120 days | `milestone_days` (3, 10, 20, 40, 70, 120) |
| `rank_viewed` | `RankScreen` opened | `has_leaderboard_entry` |
| `achievements_page_viewed` | `_AchievementPage` opened | `count_badges_unlocked` — a count of UI state, acceptable; drop if the reviewer objects |

### 5.5 Reports, sharing, updates

| Event | Trigger | Properties |
|---|---|---|
| `weekly_report_opened` | `StatisticsScreen` opened on the Weekly tab | `period` (`weekly`, `monthly`), `count_entries_bucket` (`0`, `1-3`, `4-7`) |
| `report_exported` | PDF or JSON export completes | `format` (`pdf`, `json`) |
| `share_action_completed` | `share_plus` share sheet completes | `format` (`pdf`, `json`) — the only sharing the app does today |
| `streak_card_shared` | *(proposed)* user shares a streak/score card | `tier_id` — needs a feature first; see `retention-plan.md` |
| `update_check_completed` | GitHub Releases check finishes | `result_state` (`up_to_date`, `update_available`, `failed`) |
| `update_available_shown` | Update dialog appears | `from_build_number`, `to_build_number` |
| `update_download_started` | User starts the APK download | `to_build_number` |
| `update_installed` | Next launch reports a higher build number | `from_build_number`, `to_build_number` |
| `update_skipped` | User skips this version | `to_build_number` |

### 5.6 AI assistant

| Event | Trigger | Properties |
|---|---|---|
| `ai_assistant_opened` | `ChatScreen` opened | `has_context_block` |
| `ai_message_sent` | A message is sent to NIM | `message_length_bucket` — **never the text** |
| `ai_response_completed` | Streaming reply finished | `result_state`, `duration_bucket` |
| `ai_action_proposed` | The model returns an action | `action_kind` (`set_habit_target`, `set_vision_profile`, `set_reminder_style`, `toggle_auto_break`) |
| `ai_action_accepted` | User taps Accept | `action_kind` |
| `ai_action_declined` | User taps Decline | `action_kind` |
| `ai_auto_analysis_completed` | Home auto-analysis finishes | `result_state`, `duration_bucket` |

### 5.7 Settings, privacy, rating

| Event | Trigger | Properties |
|---|---|---|
| `data_collection_toggled` | The Data Collection switch flips | `enabled` (bool) |
| `cloud_backup_toggled` | Cloud backup switch flips | `enabled` |
| `data_exported` | "Export My Data" completes | `format` (`json`) |
| `data_deleted` | Local data / cloud data / account deleted | `scope` (`local`, `cloud`, `account`) |
| `rate_prompt_shown` | Contextual rating prompt appears | `trigger_kind` (`streak`, `weekly_report`) |
| `rate_prompt_accepted` | User taps Rate | `platform` |
| `rate_prompt_dismissed` | User dismisses | `trigger_kind` |

---

## 6. Implementation contract

`lib/services/analytics_service.dart` keeps its current public API (`logEvent`,
`logScreenView`, `isEnabled`, `consentGiven`) so no call site has to change. What changes:

```dart
// lib/config/analytics_config.dart
class AnalyticsConfig {
  const AnalyticsConfig._();

  /// First-party or self-hosted endpoint. EMPTY = no events are ever sent.
  /// Wired at build time: --dart-define=ANALYTICS_ENDPOINT=https://…
  static const String endpoint = String.fromEnvironment('ANALYTICS_ENDPOINT');

  static const bool enabled => endpoint.isNotEmpty;

  /// Retention at the endpoint: raw events 90 days, aggregates longer.
  static const int rawRetentionDays = 90;

  /// Batching.
  static const int maxBatchSize = 20;
  static const Duration flushInterval = Duration(minutes: 2);
}
```

Implementation rules:

1. **Allowlist scrubber.** `logEvent` drops any property key that is not in the global
   allowlist, and drops any value that is not a `bool`, `int`, `double` or `String`. It
   also drops the whole event if its name is not in the known-event list. This is the
   mechanism that enforces §2 — a typo or a copy-pasted health value cannot escape.
2. **Offline queue.** Events are appended to a `SharedPreferences` queue
   (`analytics_queue`), flushed in batches of ≤ 20 every 2 minutes and on app pause,
   with exponential backoff. Drop anything older than 7 days.
3. **Consent + toggle gates.** Nothing is queued or sent unless `consentGiven` is true.
   When the user turns Data Collection off, flush what is pending and then stop (or drop
   it — decide and write it down; recommended: flush, so the user is not silently robbed
   of the last events).
4. **Envelope.** `{schema_version, install_id, session_id, event, props, ts}` — `ts` is the
   server-side receipt time; the client sends a coarse `day_index` only.
5. **Endpoint.** POST JSON over HTTPS, no third-party SDK, no advertising identifiers.
6. **No PII in URLs** — POST a body, never query parameters (query strings end up in
   access logs).

### Test that keeps us honest

`test/analytics_event_schema_test.dart` (pure Dart — no device needed):

- every event name used anywhere in `lib/` exists in `const knownEvents`;
- every property key used anywhere in `lib/` exists in `const allowedProps`;
- `logEvent` with a disallowed key drops that key;
- `logEvent` with a non-primitive value drops that value;
- nothing is sent while `consentGiven` is false or the endpoint is empty.

This test is the only thing standing between a future developer and a health-data leak, so
it should be merged with the first implementation, not later.

---

## 7. Where each event should be called from

| Event | Call site |
|---|---|
| `consent_accepted` / `consent_declined` | `lib/screens/consent_screen.dart:80, 98` |
| `install_completed` | `lib/main.dart` after the consent gate, once per install (guard with a `SharedPreferences` flag) |
| `permission_result` | `lib/utils/permission_helper.dart` + the setup wizard (`lib/screens/setup_wizard_screen.dart`) |
| `habits_survey_*` | `lib/screens/habits_survey_screen.dart` (`applySurveyTargets()` for the completion event) |
| `break_reminder_scheduled` / `break_completed` / `break_skipped` | `lib/screens/eye_break_screen.dart` (`recordEyeBreak` path) and `lib/providers/habit_provider.dart` (`recordEyeBreak`) |
| `eye_test_*` | `lib/screens/eye_test_screen.dart` (start / result / dispose) |
| `exercise_*` | `lib/screens/eye_exercise_screen.dart` |
| `timeline_viewed` | `lib/screens/eye_timeline_screen.dart` |
| `streak_started` / `streak_broken` / `streak_milestone` | `lib/providers/habit_provider.dart` where `streakDays` is computed (`device_data_service.dart` `calculateStreakDays`) |
| `rank_viewed` | `lib/screens/rank_screen.dart` |
| `weekly_report_opened` | `lib/screens/statistics_screen.dart` |
| `report_exported` / `share_action_completed` | `lib/providers/settings_more_provider.dart:155, 233` (the two `Share.shareXFiles` calls) |
| `update_*` | `lib/services/update_service.dart` + `lib/widgets/update_dialog.dart` + `lib/providers/update_provider.dart` |
| `ai_*` | `lib/screens/chat_screen.dart` (send/response/confirm) and `lib/screens/home_screen.dart` (`_runAnalysis`) |
| `data_collection_toggled` | `lib/providers/settings_more_provider.dart` (`setDataCollection`) |
| `rate_prompt_*` | the new rating flow (see `handoff-rate-app.md`) |

---

## 8. Volume, cost and effort

Assume 500 installs/month and ~6 events per active day:

| | Estimate |
|---|---|
| Events / month | ≈ 5,000–15,000 (trivial for any self-hosted endpoint) |
| Storage | < 50 MB/year of raw events at that rate |
| Implementation effort | 1–2 days for the service + scrubber + queue, 1 day for the call sites, 0.5 day for the schema test |
| Why bother | without it, every decision in `retention-plan.md` is a guess; with it, the next three experiments can be measured |

---

## 9. Open questions for the user

1. **Endpoint choice** — self-hosted PostHog, a tiny first-party collector, or "no
   analytics at all"? Recommendation: first-party collector, because PostHog's own
   default capture includes things we do not want to audit.
2. **Default on or off?** Recommendation: off until the endpoint exists (today's behaviour
   is unchanged, so no user-visible change and no Data Safety change).
3. **Retention** — 90 days of raw events (recommended) or 30?
4. **Does `tier_id` survive the privacy review?** If in doubt, drop it.
