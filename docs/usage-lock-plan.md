# Usage-Limit App Lock — Plan

> Recreated 2026-08-10 on branch `feat/app-lock` — the original
> `docs/usage-lock-plan.md` and all 4 scaffold files were lost (scaffold
> deleted in `f44a978`, plan doc never made it into git). This file restores
> the plan with the lessons learned since.

## Goal

Let the user set a daily limit on EyeCare AI usage (or phone usage while the
app is foreground). When the limit is reached, the app blocks itself with a
lock screen (“time's up” style) that requires a deliberate action to dismiss.
This is the natural extension of the usage-limit idea shelved before the
upstream merge.

## Why it was shelved / what changed

- Scaffold (Phase 1 draft) existed at
  `lib/models/app_usage_limit.dart`, `lib/providers/usage_limit_provider.dart`,
  `lib/screens/app_lock_overlay.dart`, `lib/services/app_usage_monitor.dart`
- It relied on `freezed`/`build_runner` codegen for the model —
  **production builds do not run `build_runner`**, and the generated files
  were not committed → uncompilable reference. Deleted in `f44a978` as
  incomplete residue.
- Upstream merge brought a 7-step Setup Wizard (`SetupStepId`) and timeout-safe
  startup (`SetupProvider._init()`/`refreshStatus()` bounded in `749f37a` +
  `823af03`). Any app-lock work must not reintroduce unbounded awaits on the
  boot path.

## Design decisions

1. **No codegen.** Plain Dart model, hand-written JSON serialization to
   SharedPreferences. Delete the freezed dependency attempt.
2. **Lock identity ≠ set a seat**: lock is a full-screen overlay route pushed
   on the root navigator (`_rootNavigatorKey` in `lib/main.dart`) when
   remaining minutes hit 0 — not a widget inserted per screen.
3. **Data source**: reuse `DeviceDataService.instance` / `UsageService`
   totals (the same numbers Home & Statistics show) rather than a new native
   query; fall back to manual “session length” counting when usage permission
   is missing.
4. **Dismissal**: Phase 1 = unlock passes the lock only by navigating to the
   app-lock setting and disabling the limit (profile the friction honestly),
   or a 5-minute “extra time” button with a cooldown. Phase 2 = system-level.
5. **No startup regression**: the lock check runs inside MainShell after
   `_refreshHabitsAndSyncRank()`, bounded by the same 6s timeouts, and must
   resolve to “no lock” by default on any error.

## Phase 1 — In-app overlay lock

Files:
- `lib/models/app_usage_limit.dart` — plain class:
  `enabled, dailyLimitMinutes, extraTimeGrantedAt, lastResetDate`; JSON
  round-trip; `remainingMinutes(now)`; `resetIfNewDay()`.
- `lib/providers/usage_limit_provider.dart` — ChangeNotifier wrapping
  SharedPreferences persistence + clock; no freezed.
- `lib/screens/app_lock_overlay.dart` — full-screen lock UI: remaining time,
  “+5 min” button, link to Settings.
- `lib/services/app_usage_monitor.dart` — derives consumed minutes from
  `DeviceDataService` (or session counter), triggers overlay via
  `_rootNavigatorKey` when `remainingMinutes <= 0 && enabled`.

Settings entry:
- New tile in `lib/screens/settings_screen.dart` (use `AppIcon` mapping, e.g.
  `🔒` already maps to `Icons.lock_outline`) → limit picker (15/30/45/60/90/120 min).

Defaults & reset:
- Daily reset at 00:00 local (mirror streak snapshot logic in
  `DeviceDataService`).
- Off by default; no behavior change until enabled.

Acceptance:
- Home → Settings → enable 15 min → use app 15 min → lock appears.
- +5 min works once per lock hour; disabling limit in Settings clears lock.
- No Hang/crash; `flutter analyze` 0 errors; manual APK smoke test.

## Phase 2 — System-level lock (deferred)

- Once Phase 1 proves the UX, consider Android `UsageStatsManager`-driven
  enforcement + device admin/DND, mirroring `FocusModeHandler.kt` patterns.
  Needs native `MethodChannel` additions — out of scope for Phase 1.
- iOS: needs entitlement review; keep local-only.

## Risks

| Risk | Mitigation |
|---|---|
| User stuck on lock with no way out | Settings tile always reachable; “extra time” button; docs |
| Clock manipulation | Compare `now` against persisted `lastResetDate`, clamp negatives |
| Permission-less usage estimate wrong | Fall back to foreground-session counter, label the estimate |
| Boot hangs | Bound lock-check futures (6s timeout pattern from `749f37a`); default no-lock |
| Upstream merge pressure | Single-feature branch, rebase onto upstream/main before merging |