# Screenshot outline — Google Play (8 slots) & App Store (10 slots)

> Rule for this document: **every frame below is a real screen in the app today**
> (`main` @ `6b90ce7`). No mock-ups, no fabricated data, no screens that only exist in a
> design file. Where a shot needs data (a streak, a leaderboard, a week of history), the
> capture instructions say exactly how to produce it honestly.

## Technical specs

| Store | Format | Sizes | Count |
|---|---|---|---|
| Google Play | 1080 × 1920 px (9:16), 16:9 or 1:1 accepted | phone ≥ 2 required, 8 max; 7" and 10" tablet optional | 8 phone + (optional) 8 tablet |
| App Store | 6.9" (1320 × 2868 or 1290 × 2796) and 5.5" (1242 × 2208) | 1–10 per device size | 10 for 6.9", 10 for 5.5" |

Rules that apply to every frame:

- Capture from a **release build** (the Modal APK), not a debug build — the debug build
  shows a red banner and a different launcher icon.
- Use a real device or an emulator **at the store's exact resolution**; Play rejects
  screenshots that are upscaled from a smaller capture.
- 16:9 phone frames must have **no rounded-corner crop** and no visible status-bar clutter
  that hides app content; the device frame is optional but must not cover UI.
- Burned-in caption text: keep it ≤ 7 words, high contrast, positioned in the top or
  bottom third — never on top of the UI it describes.
- Produce **two language sets**: English and Tiếng Việt. The app switches language from
  the Home app bar or Settings → Language; Vietnamese copy is first-class, not a
  machine translation.

---

## Google Play — 8 phone slots

### Slot 1 — Hero: the Eye Health Score
- **Real screen:** `lib/screens/home_screen.dart` — the score ring + the four-factor
  `_ScoreCard` (Screen Time, Environment, Eye Breaks, Sleep).
- **Show:** the ring with a healthy score, the four factor bars, and the "Weekly Overview"
  strip if it fits.
- **Caption burned in:** `One score for your whole day`
- **Capture:** complete the habits survey (targets set), grant Usage Access, and wait for
  one day of data — or use a build seeded with a day of snapshots so the factors are not
  "No data yet".
- **Why first:** the score is the product. Everything else in the listing is evidence for it.

### Slot 2 — Break reminders you can actually hear
- **Real screen:** `lib/screens/eye_break_screen.dart` — interval picker, Start/Stop, the
  "next break in" countdown, and the three switches (auto-detect breaks, water reminder,
  focus mode).
- **Caption:** `Reminders that show up on time`
- **Capture:** set the interval to 20 minutes and leave the app open so the countdown card
  is live. Show the auto-detect switch ON — that is a differentiator no timer app has.

### Slot 3 — The countdown lives in the notification shade
- **Real screen:** the ongoing break countdown notification and the time-up alert, produced
  by `lib/services/notification_service.dart` (`updateOngoingCountdown`,
  `scheduleRepeatingBreakAlarm`).
- **Caption:** `Countdown in your notifications`
- **Capture:** pull down the shade mid-countdown; optionally capture the alarm-style
  time-up notification with vibration/full-screen intent enabled. This is the single most
  persuasive frame for "my reminders actually fire" — put it early.
- **Care:** the notification must show the app icon and the app name, and the frame must
  include part of the launcher so it is not mistaken for an ad.

### Slot 4 — Real habits, read from the phone
- **Real screen:** `lib/screens/habits_screen.dart` — the five habit cards (Phone Usage,
  Breaks, Sleep, Outdoor, Reading) with live progress bars and "Change target".
- **Caption:** `Your habits, measured automatically`
- **Capture:** grant Usage Access + location so the cards show real values. If a card shows
  "No data source yet", the screenshot is weaker than useless — fix the permissions state
  first.
- **Note:** the Sleep card is an *estimate* (gap between last and first phone use). The UI
  says so; do not crop that disclaimer out of the frame.

### Slot 5 — Trends, not just a number
- **Real screen:** `lib/screens/statistics_screen.dart` — Weekly/Monthly tabs, the daily
  score line chart (`fl_chart`), screen-hours/sleep tiles, and the per-app usage pie chart.
- **Caption:** `See the week, not just today`
- **Capture:** needs ≥ 3 days of snapshots for a believable curve; a one-dot chart looks
  broken. Use the Weekly tab for Play and the Monthly tab for one iOS frame.

### Slot 6 — A two-minute eye check
- **Real screen:** `lib/screens/eye_test_screen.dart` — the shrinking "E" chart for each
  eye, the contrast phase, and the result summary with the disclaimer.
- **Caption:** `A quick check, per eye`
- **Capture:** capture **two** frames from the same session — the chart phase and the result
  card — and composite them side by side (both are real screens).
- **Honesty:** the result card itself says it is a home screening tool and not a substitute
  for an eye exam. **Keep that disclaimer visible.** Do not caption it "20/20 test" — the
  app deliberately does not produce a Snellen index (`eye_test_screen.dart:33-38`).

### Slot 7 — Eye Timeline (the differentiator)
- **Real screen:** `lib/screens/eye_timeline_screen.dart` — day summary tiles (breaks,
  screen sessions, low-light) and the event feed, served by
  `lib/services/eye_timeline_service.dart`.
- **Caption:** `Your day as a timeline`
- **Capture:** a day with a few events (a screen session, a completed break, a dim-light
  moment) makes the feed readable. The service keeps the last 7 days and up to 200
  events/day, so one real day is enough.

### Slot 8 — AI that asks before it acts
- **Real screen:** `lib/screens/chat_screen.dart` — streaming assistant reply, the quick
  prompt chips, and the ask-before-act confirmation card.
- **Caption:** `Advice you approve first`
- **Capture:** the confirmation card (`aiPendingActionsAccept` / `aiPendingActionsDecline`)
  is the point of the frame — show it, not just a chat bubble.
- **Honesty:** the reply must be a real reply from your own account with your own numbers.
  The AI is advisory and the medical disclaimer is part of the product, not decoration.

### Optional Play extras (only if the tablet slots are filled)
- **Rank/leaderboard** (`lib/screens/rank_screen.dart`) — see the iOS notes below for the
  anonymisation requirement.
- **Home-screen widget** (`lib/services/home_widget_service.dart` + `EyeWidgetProvider.kt`)
  — a real launcher frame showing today's score, streak and next-break countdown.
- **Achievements** (`home_screen.dart` → `_AchievementPage`) — the 9-badge grid.

---

## App Store — 10 slots (6.9" and 5.5")

Same story, two extra slots, and a different order for the first frame (iOS users see the
subtitle first, so lead with the rule, not the score):

| # | Frame | Source screen | Caption burned in |
|---|---|---|---|
| 1 | 20-20-20 rule in the app | `eye_break_screen.dart` | `Every 20 minutes, look 20 feet away` |
| 2 | Eye Health Score hero | `home_screen.dart` | `One score for your whole day` |
| 3 | Notification countdown | `notification_service.dart` | `Never miss a break` |
| 4 | Habits with real values | `habits_screen.dart` | `Measured, not guessed` |
| 5 | Weekly statistics | `statistics_screen.dart` | `See the week, not just today` |
| 6 | Eye test (chart + result) | `eye_test_screen.dart` | `A quick check, per eye` |
| 7 | Eye Timeline | `eye_timeline_screen.dart` | `Your day as a timeline` |
| 8 | AI assistant + confirm card | `chat_screen.dart` | `Advice you approve first` |
| 9 | Ranks & leaderboard | `rank_screen.dart` | `7 ranks, one leaderboard` |
| 10 | Achievements or home widget | `home_screen.dart` → `_AchievementPage` / `EyeWidgetProvider.kt` | `Keep the streak alive` |

**iOS-specific caveat:** slots 3 and 10 depend on Android-only surfaces (exact alarms and
the `home_widget` package). Before submitting to the App Store, verify each frame against
an iOS build; if a feature is missing on iOS, replace that frame with a Settings or
Statistics frame rather than shipping an Android screenshot.

---

## Capture notes and pitfalls

1. **No fake leaderboard.** The leaderboard lists real accounts with the e-mail prefix as
   nickname (`leaderboard_service.dart:83`). For a store frame, either use a build seeded
   with a test leaderboard, or **blur the names**. Never ship other users' e-mail prefixes
   in a Play screenshot.
2. **No fake health numbers.** Every number in a screenshot must come from a real day of
   use. A 92/100 score with four full factor bars is fine if it is real; inventing one is
   a misrepresentation and reviewers do check.
3. **Keep the disclaimers.** The eye-test result card, the "estimated" label on sleep and
   the AI medical disclaimer are part of the product. Cropping them out of a screenshot
   removes the context that makes the claim honest.
4. **Dark mode variants.** The app has a full dark theme plus a warm night-read tint
   (`ThemeProvider.refreshNightState`). Capture a dark-mode pair for slots 1 and 2 — it is
   cheap and it is a real feature.
5. **Vietnamese set.** Shoot a parallel EN/VI set. The captions stay in the app's language
   so the frame reads like the product rather than like a poster.
6. **Device frames:** keep the frame thin and neutral; the app has its own accent colour
   system (`lib/theme/app_colors.dart`) and a gradient border — the frame should not
   compete with it.

## What we deliberately do not screenshot

| Not shown | Why |
|---|---|
| A "20/20" result | The app refuses to output a Snellen-style index |
| A blue-light filter screen | Copy exists in `AppStrings`, implementation does not |
| A blink-detection screen | Removed from the app |
| An "Eye disease detected" result | Nothing in the app detects disease; showing it would be a false claim |
| A "doctor chat" | The AI is advisory only and says so |
