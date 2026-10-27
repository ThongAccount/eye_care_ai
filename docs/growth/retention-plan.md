# Retention plan — EyeCare AI

**Author:** GrowthLead. **Date:** 2026-10-24. **Codebase state:** `main` @ `6b90ce7`.

Three parts: (1) the 15 wishlist idea groups from PLAN.md mapped against what actually
ships, (2) the three highest-leverage retention moves with mechanic, metric and first
experiment, (3) the numbers I still need from the user, because a funnel without data is
a guess.

---

## 1. Wishlist → shipped reality

Source of the wishlist: PLAN.md § "💡 15 idea groups". Status re-verified against the code
on 2026-10-24 (not against the old stale feature table).

| # | Idea group | Status | Evidence / what is actually there |
|---|---|---|---|
| 1 | Eye Health Score 2.0, per factor | ✅ **Shipped** | `home_screen.dart` score ring + 4 factor rows (Screen Time, Environment, Eye Breaks, Sleep). The 5th "distance" factor was **removed** — see `device_data_service.dart:792`. Do not market 5 factors. |
| 2 | "Why did my score change?" attribution | 🟡 **Partial** | Day-over-day factor deltas exist (`habit_provider.dart:324`, `AppStrings.suggestionImproved(factorLabel, percentGain)`) and the score card explains each factor. There is **no points ledger** ("−4 phone time, −2 dark room"). |
| 3 | Daily Eye Report (+ 7/30-day) | 🟡 **Partial** | Home has "Today's suggestions" + a Weekly Overview strip; Statistics has Weekly and Monthly tabs. There is no *daily* report card and no 30-day daily view. |
| 4 | AI Weekly Eye Coach on aggregated data | ❌ **Not shipped** | The AI does chat (`chat_screen.dart`) and a one-shot Home auto-analysis of *current* state (`home_screen.dart:_runAnalysis`). No weekly aggregation, no coach persona, no "must not invent data" guardrail layer. |
| 5 | Adaptive Goals (tighten on success / relax on failure) | 🟡 **Partial** | The app *suggests* lowering the break target when yesterday fell short (`showAdjustBreakGoalDialog`, once per session, user-driven). Nothing adapts automatically. |
| 6 | Streak Protection ("Recovery Day", 1×/week) | ❌ **Not shipped** | A missed day resets the streak to 0 (`AppStrings.streakExplainBody`). No token, no grace. |
| 7 | Eye Health Timeline | ✅ **Shipped** | Merged 2026-10-23: `eye_timeline_service.dart` (7-day retention, ≤200 events/day) + `eye_timeline_screen.dart`. Brand new and **not yet used for retention** — it is the best unused asset in the product. |
| 8 | Smart Notification Priority (merge/dedup) | 🟡 **Partial** | Focus mode blocks *other apps'* notifications (`focus_mode_service.dart`); the app's own alerts are not de-duplicated — the water reminder rides along on the break notification (`eye_break_screen.dart:216`). |
| 9 | Distance History distribution | ❌ **Not shipped** | Camera distance scoring was removed; distance survives only as a live hint during the eye test. |
| 10 | Sleep Pattern from night phone usage (labelled estimate) | ✅ **Shipped** | `UsageStatsHandler.getSleepEstimate()` + manual override in Habits; the UI labels it an estimate, and the score-factor explainer spells out the method. |
| 11 | Eye Test History (no self-diagnosis) | ✅ **Shipped** | `eye_test_screen.dart` keeps a history list and shows the medical disclaimer. No per-eye trend chart yet. |
| 12 | Achievements 2.0 (consistency / distance / breaks / environment) | 🟡 **Partial** | 9 badges exist, but they are mostly break-count based (5 / 15 / 100 breaks, 30 days without a miss, first streak, "Digital Balance"). No environment- or distance-based tiers. |
| 13 | Daily Quests (3/day, tied to Rank) | ❌ **Not shipped** | — |
| 14 | Personal Eye Profile (1–2 weeks data → basis for recommendations) | ❌ **Not shipped** | There is a *manual* "Vision Profile" setting (user-declared); there is **no data-derived personal baseline**. |
| 15 | "What if?" simulator (sliders, labelled estimate) | ❌ **Not shipped** | — |

**Tally: 4 shipped · 5 partial · 6 not shipped.**

Read that honestly: the wishlist is not the bottleneck. The shipped set already covers
reminders, scoring, history, reports, streaks, ranks, AI and two languages. **The gap is
that the shipped features are not wired into a loop that brings the user back.** Six
unshipped wishlist items are mostly *features*, not *loops* — building Daily Quests or a
"What if?" simulator adds surface area without fixing why people leave.

---

## 2. The three structural problems (read this before the moves)

These are the constraints that decide which moves are worth doing.

**P1 — The streak does not measure the behaviour.** The rule, straight from the app's own
copy: a day counts if **either** the Eye Health Score reaches 50 **or** the user simply
opened the app. So the reward loop currently measures *app opens*, not eye care. Worse, it
is structurally misaligned: the break reminder works while the app is closed (native
alarm), so the user who benefits most from EyeCare AI has the least reason to open it —
and the streak punishes exactly them.

**P2 — Nothing ever asks the user to come back.** The weekly report exists
(`statistics_screen.dart`, Weekly/Monthly tabs) and the PDF export exists
(`settings_more_provider.dart`), but no surface ever *prompts* the user to open the weekly
report. The report is a feature nobody is told about. The one daily re-engagement surface
that does exist is the break reminder — which is a task, not a moment of reflection.

**P3 — The activation tax is paid before any value.** Order today: consent screen →
habits survey → permission wizard (notifications first, then location, activity recognition,
full-screen intent, battery optimisation, DND policy, overlay, and **Usage Access last**) →
then value. Usage Access is a system-settings detour with no runtime dialog — the single most
likely place for an install to die — so it is asked LAST, after the notification permission
that the 20-20-20 reminder needs has already been granted (order fixed 2026-10-27, see
`kSetupWizardStepOrder`). The 20-20-20 reminder, meanwhile, needs **only** the notification
permission, and it is the product's core value.

---

## 3. The three moves

Each move: **mechanic → metric → first experiment → why it beats the alternatives.**

### Move 1 — "Streak 2.0": make the streak mean something, and make failure survivable

**Mechanic (two halves, ship as one).**

1. *Integrity.* A day counts toward the streak when the user completes the behaviour —
   either the Eye Health Score clears the day target, **or** at least 3 break reminders are
   completed. Drop the "opened the app" check-in as a streak qualifier. Keep the check-in
   as a visible "opened today" dot so nothing feels silently taken away. Grandfather
   existing streaks (keep the current count, mark them "legacy") so nobody loses a badge
   they earned.
2. *Recovery.* One **Recovery Day** per calendar week, earned automatically, consumed
   automatically the first time a qualifying day is missed. The streak then pauses instead
   of resetting; a badge "7 recoveries used" turns the mercy into a badge instead of a
   loophole. (This is wishlist #6, implemented as a two-line state machine.)

**Metric.** Primary: **streak-alive rate at day 14** = share of new users whose streak is
≥ 3 days on day 14. Secondary: D7 and D30 retention, reminder completion rate.
Guardrail: no increase in "streak broken" complaint feedback; no drop in daily app opens
(the fix must not trade engagement for streak integrity).

**First experiment.** Ship both halves to a **randomised 50/50 cohort** (bucket stored in
`SharedPreferences` on first launch, so assignment is stable and does not need a server),
with the readout coming from the self-hosted analytics endpoint defined in
`analytics-events.md`. Decision rule: keep the change if the treatment arm's day-14
streak-alive rate is **≥ 8 pp higher** and the 95% CI excludes 0; otherwise revert.

**Power, honestly:** detecting 40% → 48% needs ≈ **605 users per arm** (two-sided α=0.05,
80% power). At ~500 installs/month that is ~10 weeks of traffic. So: run the experiment
**only after** the analytics endpoint exists, and in the meantime use the cheaper
**natural experiment** — users who update to the new build vs users who stay on the old
build — while labelling it as selection-biased (updaters self-select).

**Why this beats the alternatives:** quests, badges and simulators all sit *on top of* a
streak that currently measures app opens. Fixing the measurement first makes every later
gamification feature cheaper and less likely to be faked. It is also the only move that
turns an existing shipped feature into a loop.

---

### Move 2 — The weekly report becomes a scheduled moment, not a forgotten tab

**Mechanic.**

1. A **local notification** on Sunday evening (reuse `NotificationService` / the existing
   alarm infrastructure — no new dependency, no server) whose body is three lines from
   data already on the device: this week's score band, the factor that improved most, the
   factor to work on. Tapping it deep-links straight into the Weekly tab of
   `statistics_screen.dart`.
2. A **"share your week"** action on that screen: a one-screen PNG card (score band,
   streak, rank tier, app name) shared through `share_plus`, which is already a
   dependency. This is also the app's first real **growth loop** — the only sharing the
   app has today is exporting your own data/PDF, which nobody does for fun.
3. Weekly report notifications respect the existing notification switches and a
   "weekly summary" toggle; default on for users who already have break reminders on.

**Metric.** Primary: **weekly report open rate** = share of W1 users who open the report
within 48 h of the notification. Secondary: D7 retention in weeks containing a report
notification; attributed installs from shared cards (needs a referral code — see §5).
Guardrail: notification opt-out rate (Play/notification settings) must stay under 5%;
unsubscribe-before-open rate under 2%.

**First experiment.** Ship **only** the local weekly notification + deep link (no share
card, no referral code — a week of work, no new dependencies). Decision rule: if the
weekly report open rate is ≥ 25%, build the share card; if < 10%, the report itself is not
interesting enough and Move 2 is dead — go back to the data and fix the content instead.

**Power:** 20% → 30% needs ≈ **295 users per arm** (~5 weeks at 500 installs/month) — the
cheapest of the three experiments, which is exactly why it goes first.

**Why this beats the alternatives:** the app already computes everything the report needs.
This is a trigger and a deep link, not a feature. And it reuses the one asset that is
currently pure upside — the Eye Timeline (wishlist #7) can be the raw material for
"your day as a timeline" cards later.

---

### Move 3 — Deliver the reminder first; ask for sensors later

**Mechanic (reorder the onboarding).**

1. After consent + the survey, schedule the **20-20-20 reminder immediately** — it needs
   only the notification permission. The score card ships in its existing "No data yet"
   state, which the UI already handles gracefully.
2. Remove **Usage Access** from the initial permission wizard. Ask for it on **day 2**,
   with the reason attached to the specific value it unlocks: *"Your Screen Time factor is
   empty — grant Usage Access and your score starts working."* Same for camera (eye test
   hints), location (outdoor minutes) and battery optimisation (reminders that fire on
   time).
   *Partly done 2026-10-27:* Usage Access now comes **last** in the wizard and the
   notification permission is asked first, so the detour can no longer cost the user the
   reminder. The day-2 ask with the value reason is still open.
3. Gate the "full value" moment on those grants, and show a one-time banner on Home when
   a factor is still empty.

**Metric.** Primary: **24-hour activation rate** = share of installs that complete at
least one break within 24 h of install. Secondary: day-3 permission grant rate; share of
installs that reach a score ≥ target within 7 days.
Guardrail: no increase in uninstalls within 24 h (users may leave because the score is
empty — watch this closely; if it rises, keep the Usage Access ask but move it to day 2
*after* the first reminder fires).

**First experiment.** Reorder the onboarding and measure activation with a **before/after**
comparison over 4 weeks (no control group — the change is too entangled to A/B without
an experiment framework; state it as observational, not causal). Decision rule: ship if
24-hour activation improves by ≥ 8 pp and 24-hour uninstalls do not rise by more than
1 pp.

**Power:** 30% → 38% would need ≈ **551 users per arm** — too slow today, hence the
observational design. If install volume grows past ~1,500/month, convert this into a real
A/B.

**Why this beats the alternatives:** every "add a feature" idea is downstream of the
install→value path. Today the path runs through a system-settings detour before the user
has seen anything useful. Fixing the order is free (no new screens, no new copy beyond
three lines) and lifts every other metric.

---

## 4. Sequencing (90 days)

| Weeks | Do | Why now |
|---|---|---|
| 1–2 | Analytics endpoint + the schema test from `analytics-events.md` (the three experiments above are unmeasurable without it) | Every decision below is currently a guess |
| 2–3 | Move 3 — reorder onboarding (cheap, no dependencies, no review risk) | Cheapest activation win; independent of the other two |
| 3–4 | Move 2 — weekly notification + deep link, measure the open rate | Cheapest experiment with an adequate sample size (~5 weeks) |
| 5–8 | Move 1 — Streak 2.0 behind a 50/50 cohort | Needs the analytics readout; needs 10 weeks of traffic, so start early |
| 8–12 | If Move 2's report opens: build the share-card + referral loop (wishlist #13/#14 groundwork) | Only worth it if the report is read |

**Explicitly not doing:** Daily Quests (#13), the "What if?" simulator (#15), the AI
Weekly Coach (#4) and Personal Eye Profile (#14). All four are plausible features, all
four cost weeks, and none of them fixes P1, P2 or P3. Revisit #4/#14 only if Move 1 shows
that users respond to guidance rather than to scores.

---

## 5. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Health-claim drift in retention copy ("your eyes are healthier") | High — Play review + trust | Copy must stay "habit estimate"; reuse the disclaimers already in the app |
| Weekly notification becomes spam | Medium | One per week, off switch, respects existing notification settings, opt-out rate guardrail |
| Streak 2.0 angers existing users who lose a streak | Medium | Grandfather legacy streaks; announce the change in the changelog screen |
| AI cost / key exposure if a coach is built later | Medium | Move the NIM call behind a backend before adding any AI frequency |
| Experiment readouts are wrong because the install base is small and self-selected | High | Say "inconclusive" when underpowered; do not ship on vibes |

---

## 6. Numbers I need from the user (or to instrument)

Today there is **no funnel data at all** — analytics is a stub, so everything above is a
hypothesis with a metric attached, not a finding. To turn this plan into decisions I need:

1. **Installs per week** (GitHub Release APK download counts are a proxy but include
   sideloaded re-installs). This sets every sample size above.
2. **Where installs come from** today (GitHub README, Reddit, YouTube, friends?) — with no
   store listing, the acquisition channel constrains which retention move matters.
3. **Any usage numbers you already have**: how many people opened the app after the
   Usage Access prompt, how many completed the survey, how many set a guardian e-mail.
4. **The target market** (Vietnam, USA, both) — notification cadence and copy differ.
5. **Whether the app is meant to be free** — retention moves 1 and 2 work either way, but a
   paid tier changes which ones to prioritise.

If the answers are "I don't know", that is fine and expected — that is exactly what the
analytics endpoint in `analytics-events.md` is for. The one thing I will not do is guess a
baseline and report a % improvement against it.
