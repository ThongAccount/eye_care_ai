# Usage-Limit App Lock — Plan (rev. 2: block OTHER apps)

> Rev 2 — 2026-08-10 on branch `feat/app-lock`. Rev 1 planned a
> self-lock (app blocks ITSELF after in-app usage limit); on-device
> feedback killed it: "it locks its own when reaching limit — how does
> THAT make sense". The point of an eye-care app is to get you OUT of
> distracting apps, not lock you out of the health app.
>
> New direction = Digital-Wellbeing-style: EyeCare AI stays accessible;
> the *distracting* apps get gated once the phone-usage budget is spent.

## Goal

User sets a daily phone-usage budget (e.g. 90 min of screen time).
When the budget is exhausted, launching a **blocked app** shows a
full-screen "time's up" gate over that app. EyeCare AI itself is
**never blocked** — it's the escape hatch / safe screen.

## Hard Android constraint (why "block" is a soft block)

A normal app **cannot force-stop or kill another app** on stock
Android (needs root or same-uid). Best-effort enforcement = a
**system overlay** (`SYSTEM_ALERT_WINDOW`) rendered on top of the
foreground app the moment it's detected:

- Overlay appears full-screen above the blocked app → user can't
  interact with the app underneath
- Home button / recents still work (overlay can't trap the user)
- The blocked app is never actually closed; it's *covered* by the gate
- Optional hard close needs **AccessibilityService** (performGlobalAction
  BACK / switch-to-home) — fragile, OEM-quirky, Phase 3 only

Device: CPH2461 (Oppo/ColorOS). ColorOS kills background services
aggressively → the gate must be *foreground-detection driven*, not a
long-lived service. When user switches to a blocked app, gate shows
within ~1s; when they leave, gate auto-dismisses.

## Existing building blocks (all in repo)

- `android/.../UsageStatsHandler.kt` — `queryEvents` +
  `MOVE_TO_FOREGROUND` scanning (sleep-estimate path already uses it),
  `checkUsagePermission()`, `openUsageSettings()`: reuse for
  foreground detection + budget accounting
- `MainActivity.kt` — MethodChannel `eye_care_ai/usage_events`,
  `setMethodCallHandler` pattern: add channel `eye_care_ai/app_lock`
- Manifest: `PACKAGE_USAGE_STATS` already present; add
  `SYSTEM_ALERT_WINDOW` (install-time normal permission; runtime grant
  via `Settings.ACTION_MANAGE_OVERLAY_PERMISSION`)
- `lib/services/app_usage_monitor.dart` (Phase-1 rev-1) — repurpose:
  no longer pushes a Flutter lock route; becomes a thin Dart client of
  the native gate (budget state, remaining time, config push)
- `lib/providers/usage_limit_provider.dart` — keep; config surface:
  enabled, budgetMinutes, blockedPackage list, graceSeconds

## Phase 1 — native overlay gate (this branch)

Native (Kotlin):
- `AppLockHandler.kt` — MethodChannel `eye_care_ai/app_lock`:
  - `setConfig({enabled, budgetMinutes, blockedPackages, graceSeconds})`
    → persists prefs, restarts polling
  - `getBudgetState()` → `{remainingMinutes, lastResetDate}` (same
    yyyyMMdd reset rule as rev-1 model)
  - `grantExtra(minutes)` → +5/+"10 more" with 1-grant-per-hour cooldown
  - `dismissOnce()` → per-launch snooze
- Foreground watcher: `UsageStatsManager.queryEvents` poll every 3–5s;
  on `MOVE_TO_FOREGROUND` of a package in `blockedPackages` while
  budget exhausted → show overlay; on `MOVE_TO_BACKGROUND` (or Home)
  → dismiss overlay
- Overlay: `WindowManager.LayoutParams(TYPE_APPLICATION_OVERLAY)`,
  full-screen, below `FLAG_NOT_FOCUSABLE` toggle, dark theme, shows
  remaining 0 + buttons (+5 min / Open EyeCare AI / Settings)
- Budget source: total foreground time from UsageStats since
  `lastResetDate` — same numbers Home/Statistics show (their weekly
  usage path), so the gate never contradicts the app

Flutter (Dart):
- Repurpose `lib/screens/app_lock_overlay.dart` → only used as the
  in-app *settings* sheet (keep `AppLockSettingsSheetHost`); the
  runtime gate is native, NOT a Flutter route
- `lib/services/app_usage_monitor.dart` → `AppLockClient` calling
  `app_lock` channel; `UsageLimitProvider` = settings model
- Settings tile already added ("Usage Limit") → expand: budget picker
  (30/45/60/90/120/180 min) + blocked-app list (pick from installed
  apps via `getInstalledApps` MethodChannel call) + overlay-permission
  deep-link button
- Setup wizard: optionally add an 8th step "block distracting apps"
  (reuse `SetupStepId` pattern; all steps skippable)

## Phase 2 — niceties (later)

- Per-app budgets (list item shows own consumed time)
- Time-window schedules (block after 10pm)
- Daily reset notification; streak-aware "you survived 3 days"

## Phase 3 — optional hard close (risky, may never ship)

- `AccessibilityService` that performsGlobalAction(HOME/BACK) on
  blocked app; OEM quirks (ColorOS, MIUI) make this unreliable;
  separate opt-in toggle, clearly labeled experimental

## Acceptance (Phase 1)

- Enable 1-min budget → open blocked app → gate appears ≤5s
- EyeCare AI itself opens normally (never gated)
- +5 min works once/hour; Settings always reachable; disable clears
- Overlay permission grant flow works on CPH2461 (manual Settings
  redirect acceptable)
- `flutter analyze` 0 errors; native unit: `./gradlew testDebugUnitTest`
  if any are added; manual smoke on device

## Open questions

- Budget = total phone usage vs per-app usage? Default total (matches
  "screen time" numbers already shown)
- Blocked list default: apps user picks, or preset distraction set
  (YouTube/TikTok/games)?
- Snooze semantics: dismissOnce per launch vs 5-min grant — both, with
  separate cooldowns

## Risks

| Risk | Mitigation |
|---|---|
| Overlay never grants on ColorOS | Settings deep-link + in-app status check (canDrawOverlays) |
| Foreground poll misses fast app hops | 3–5s poll + grant extra only when foreground observed |
| UsageStats data lag | Same query path as Home; accept ≤1 tick staleness |
| User stuck under gate | EyeCare AI always reachable via Home; Settings button in gate |
| Boot regression | All native config reads bounded; default disabled, no gate |