# EyeCare AI — Store Listing Pack (Google Play primary, App Store secondary)

> Grounded in the code at `main` @ `521cb2e` (2026-10-24), re-verified at the `1.4.0+alpha`
> version bump. Every claim below maps to a
> file in the repo. Anything that is **not** shipped is marked as a TODO, not written as a
> feature. Health-adjacent rules applied throughout: no "treats / prevents / cures /
> diagnoses", no Snellen-style 20/20 score, no medical-device framing.
>
> Facts used below and their source:
> `android/app/build.gradle.kts` (package id, minSdk), `pubspec.yaml` (version 1.4.0+alpha),
> `android/app/src/main/AndroidManifest.xml` (permissions), `lib/models/app_strings.dart`
> (user-facing copy, EN + VI), `lib/models/rank_tier.dart` (7 rank tiers),
> `lib/services/*` (data flow), `lib/screens/*` (features), `lib/providers/*`.

---

## 0. Identity block (fill this in before submitting)

| Field | Value | Source / status |
|---|---|---|
| App name (Play) | `EyeCare AI` | `AndroidManifest.xml:67` (`android:label`) |
| App name (iOS) | `Eye Care Ai` | `ios/Runner/Info.plist:11` → **TODO**: rename to `EyeCare AI` before submission |
| Package id | `com.eyecare.eye_care_ai` | `android/app/build.gradle.kts:63` (`applicationId`) |
| Namespace | `com.eyecare.eye_care_ai` | `build.gradle.kts:51` |
| Version | `1.4.0+alpha` | `pubspec.yaml` (shown in-app as `EyeCare AI v1.4.0 (build N)`; `versionCode` = CI run number) |
| Min Android | API 26 (Android 8.0) | `build.gradle.kts:68` |
| Default language | English (Vietnamese supported) | `LanguageProvider`, `AppStrings` |
| Support e-mail | `eyecareai.app@gmail.com` | `lib/widgets/help_support_section.dart:13` |
| Developer name / entity | — | **TODO — user must provide** (Play requires a legal developer name; a personal developer account shows a legal name, not a brand) |
| Contact URL / website | `https://thongaccount.github.io/eye_care_ai/` | GitHub Pages (`gh-pages` branch) — live, HTTP 200 |
| Privacy policy URL | `https://thongaccount.github.io/eye_care_ai/legal/privacy.html` | live, HTTP 200. Play **rejects** a listing without a public URL |
| Terms of service URL | `https://thongaccount.github.io/eye_care_ai/legal/terms.html` | live, HTTP 200 |
| Current distribution | Signed APK on GitHub Releases | `https://github.com/ThongAccount/eye_care_ai/releases` |
| Licence | MIT | `README.md:101` |
| IAP / ads | None | no ad SDK, no billing dependency in `pubspec.yaml` |

---

## 1. Google Play — metadata

### 1.1 Title (≤ 30 chars)

| # | Title | Chars | Rationale |
|---|---|---|---|
| **A — recommended** | `EyeCare AI: Screen Break Timer` | 30 | Brand + the single most searched phrase in the category. "Screen break" is what people type; "eye health" is what they read about. |
| B | `EyeCare AI: 20-20-20 Breaks` | 27 | Owns the rule itself. Best if the 20-20-20 angle is the creative. |
| C | `EyeCare AI: Eye Health Score` | 28 | Outcome-led. Best for a "score/tracker" audience. |

Play has **no keyword field** — the title, short description and full description are the
entire keyword surface. Keep the brand in the title (it is also the app name) and put the
category terms in the short description.

### 1.2 Short description (≤ 80 chars)

```
20-20-20 eye breaks, screen-time insights and a daily Eye Health Score.
```
*71 characters. Contains "eye breaks", "screen time", "eye health score" — the three
head terms.*

### 1.3 Full description (≤ 4000 chars)

```
Screen time is hard on your eyes. EyeCare AI helps you build better eye habits — one 20-20-20 break at a time.

BREAKS THAT ACTUALLY FIRE
• A 20-20-20 reminder every 20 minutes, or on the interval you choose
• A live countdown in the notification shade, so you always know when the next break lands
• Alarm-style alert with vibration, plus a full-screen pop-up if you enable it
• Automatic break detection: lock your screen or leave the app for 20+ seconds and it counts
• Focus mode temporarily silences other notifications while the countdown runs

A DAILY EYE HEALTH SCORE (0-100)
Your score is built from four things your phone can honestly measure:
• Screen time — read from Android Usage Access and compared with your own target
• Eye breaks — how many reminders you actually completed
• Environment — ambient light around you, including dark-room time
• Sleep — estimated from the gap between your last phone use and your first use in the morning, or entered by hand
Tap any factor to see exactly how it is calculated. The score is a habit estimate, not a medical measurement.

CHECK IN WITH YOUR OWN EYES
• A quick home eye test: shrinking letter charts for each eye, plus a contrast-sensitivity check
• Viewing-distance and eye-open hints from the front camera — opt-in, processed on your phone, images never stored or uploaded
• A clear result with next steps, and a reminder to see an eye professional if something looks off
• The test gives no medical score and never diagnoses anything

YOUR DAY AS A READABLE TIMELINE
Eye Timeline turns sensor events into a plain feed: screen sessions, completed breaks, low-light moments, brightness changes.

HABITS, STREAKS AND RANKS
• A 5-question habits survey sets personalised 30-day targets you can edit any time
• Streaks, achievements and 7 Duolingo-style rank tiers, from Bronze to Supreme Master
• A leaderboard showing where you stand among other users
• A home-screen widget with today's score, your streak and the next break countdown

REPORTS AND AI, WITHOUT THE HYPE
• Weekly and monthly statistics, plus a real PDF eye-health report you can share or hand to a doctor
• An AI assistant (NVIDIA NIM) that reads your own numbers and suggests one concrete change — and always asks before acting
• English and Tiếng Việt, dark mode, metric or imperial units, JSON data export, cloud backup and in-app updates

PRIVACY FIRST
• Sensor readings stay on your device unless you turn on cloud backup or use the AI assistant
• Camera frames are processed on-device and are never stored or uploaded
• No ads, no ad SDKs, no selling of personal data
• Export or delete everything from Settings, or delete your account outright

DOWNLOAD
EyeCare AI is open source (MIT) and is currently distributed as a signed APK on GitHub Releases:
https://github.com/ThongAccount/eye_care_ai/releases
Download the latest APK, allow installs from your browser or file manager, and open it. The app checks GitHub Releases for updates in-app.

NOT A MEDICAL DEVICE
EyeCare AI is a wellness and habit tracker. It does not diagnose, treat, prevent or cure eye disease and does not replace an eye exam. If you have persistent blurred vision, eye pain or frequent headaches, see an eye professional.
```

*3,230 characters — comfortable headroom under the 4,000 limit.*

**Claims deliberately NOT made** (each would be false today):

| Do not claim | Why |
|---|---|
| "20/20 vision test" / Snellen score | `eye_test_screen.dart:33-38` explicitly refuses to output a fake Snellen index |
| "detects eye strain / diagnoses eye disease" | No such capability; the score is a habit estimate |
| "blue light filter" | `AppStrings` has the copy, there is no implementation (PLAN code-verified table) |
| "blink detection" | Removed; only exercise/achievement copy mentions blinks |
| "treats / prevents / relieves eye strain" | Health-adjacent product, no clinical evidence behind it |
| "works on iPhone" | iOS build is blocked (no Mac / Apple Developer account) |

### 1.4 ASO keyword plan (Play)

Play indexes title + short description + full description. Priority order by intent:

| Keyword | Where it goes | Intent |
|---|---|---|
| eye break / eye breaks | short description, bullet 1 | highest-volume, low competition |
| screen break / screen time | title A, bullet 1, factor 1 | the problem being searched |
| 20-20-20 / 202020 | title B alt, bullet 1 | rule-literate users, very low competition |
| eye strain relief / reduce eye strain | full description hook | high volume, high competition — used once, honestly |
| eye health score | short description, score section | tracker audience |
| eye test / vision test | eye test section | highest commercial intent, but copy must stay "home screening" |
| habit tracker / screen time app | habits section | adjacent app categories |
| dark mode / night reading | not included | low intent for this product |
| 20-20-20 reminder / timer | title A + bullet 1 | long-tail, conversion-heavy |

**Search-term discipline:** no competitor names, no "medical"/"myopia"/"cataract" terms
(those pull the listing into Play's Medical-policy review and misdescribe the product).

### 1.5 Category, tags, contact

| Field | Value | Note |
|---|---|---|
| App type | App | |
| Category | **Health & Fitness** | Secondary: Productivity (screen-time users). If Play reviewers push back, move to Lifestyle — do **not** claim Medical. |
| Tags | Health, Wellness, Productivity, Screen time, Habit tracker | Up to 5 |
| Contact e-mail | `eyecareai.app@gmail.com` | already in-app |
| External marketing site | GitHub repo / GitHub Pages landing page (in flight) | |
| Privacy policy URL | **TODO** — required before submission | see §0 |
| Government app | No | |
| Financial features | None | no lending, no trading, no crypto |
| Target audience | 13+ (no ads, no purchases, no user-generated content published) | consider 18+ to be conservative if the AI chat stays open |

### 1.6 Content rating (IARC questionnaire — draft answers)

| Question | Answer | Why |
|---|---|---|
| Violence, gore, fear | No | |
| Sexuality / nudity | No | |
| Controlled substances | No | |
| Crude humour / profanity | No | |
| Gambling | No | |
| User interaction | **Yes — limited** | The leaderboard shows other users' nickname + streak to signed-in users; AI chat is private to the user |
| User-generated content shared | **No** | No public posting; the leaderboard entry is auto-generated from your own streak |
| Location sharing with third parties | No | GPS is read on-device only |
| Digital purchases | No | No IAP, no paid SDKs |
| AI-generated content | **Yes** | The assistant writes advice; it is advisory only, with ask-before-act confirmations and a medical disclaimer |
| Ads | No | |

**Answer the IARC form in the Play Console yourself** — this table is a draft, not a submission.

### 1.7 Data safety form — what to declare (verified against the code)

The rule that decides most answers: Play counts data as **collected** only if it leaves the
device. "Processed on-device and discarded" is **not** collection.

| Data type | What is really collected | Where it goes | Declare |
|---|---|---|---|
| **Location — precise** | GPS fixes sampled ~1/min while the app is open, used to add up outdoor time | Stays on device; **included in cloud backup** (as outdoor minutes) and **in the AI context block** if the assistant runs | Collected · Optional (app works without it) · Not sold · Not used for ads |
| **App activity / app interactions** | Screen-on time and foreground-app usage via Android Usage Access; per-app breakdown is shown locally | Stays on device; **included in cloud backup** (daily snapshots) and in AI context aggregates | Collected · Optional · Not sold |
| **Health and fitness** | Sleep hours (estimated from phone-use gap or entered by hand), outdoor minutes, eye-break count, Eye Health Score | Stays on device; **included in cloud backup**; **score + per-habit current/target sent to NVIDIA NIM** when the AI assistant or the Home auto-analysis runs | Collected · Optional · **Shared with the AI provider (NVIDIA) as a processor** · Not sold · Not used for ads |
| **Photos and videos** | Camera frames for the opt-in ML Kit eye-open / distance check | **Never stored, never uploaded** — processed on-device, camera closed after each sample | **Not collected** (state this in the listing's privacy section so reviewers see the honesty) |
| **Messages** | Your AI chat messages and the aggregate context block | Sent to `integrate.api.nvidia.com` (NVIDIA NIM) | Collected · Optional · Shared with the AI provider · Not sold |
| **User IDs** | Firebase Auth UID | Firebase Auth + Firestore (`leaderboard`, `user_backups`) | Collected · Optional (guest mode exists) · Not sold |
| **Contact info (e-mail)** | E-mail address when you create an account; the part before "@" is shown as your leaderboard nickname | Firebase Auth; nickname published on the leaderboard | Collected · Optional · **The nickname is visible to other signed-in users** · Not sold |
| **Crash logs / diagnostics** | None — no crash reporting SDK is installed | — | **Not collected** |
| **Photos, audio, files, calendar, contacts, precise location history** | Not used | — | Not collected |

Three answers that need the developer's decision before submitting:

1. **Cloud backup default.** `SettingsMoreProvider.cloudBackup` defaults to *on*, so a signed-in
   user's daily snapshots (score, screen hours, sleep, outdoor minutes) go to Firestore by
   default. Either keep it on and declare it as above, or default it to **off** and make it
   opt-in — the latter is the cleaner privacy story and one line of code. **Recommend: default off.**
2. **The AI key is compiled into the APK** (`--dart-define=NIM_API_KEY`, `lib/config/env.dart`).
   Anyone who unpacks the APK can extract it and use the developer's quota. Not a data-safety
   answer, but it *is* a Play-review risk (server keys in clients) and a cost risk. **Recommend:
   proxy the AI calls through a tiny backend before the Play submission.**
3. **Firebase (Google) processors.** `google-services.json` is in the repo. Firebase may send
   device/app metadata to Google. Declare it as a processor and confirm what the project
   actually enables (Analytics must be **off** in the Firebase console — the in-app
   `AnalyticsService` is a no-op stub, so Firebase Analytics would be the only real analytics).

### 1.8 What the listing says about privacy (short, honest)

Paste into the listing's "Privacy" / "App safety" section:

> EyeCare AI is a wellness habit tracker with no ads and no ad SDKs. Screen time, ambient
> light, outdoor time, sleep estimates, eye-break counts and your Eye Health Score are measured
> on your device. Camera frames used for the optional eye-open/distance check are processed
> on-device and are never stored or uploaded. If you sign in and turn on cloud backup, your
> settings, targets and daily eye-health snapshots are stored in Firebase under your user ID so
> you can restore them on a new device. If you use the AI assistant, the text you type and a
> short summary of your own numbers are sent to NVIDIA's NIM API to generate the reply. You can
> export or delete all data in Settings, or delete your account, at any time.

---

## 2. App Store (iOS) — secondary

> **iOS is not shippable yet.** `ios/` exists, but the build needs a Mac and an Apple
> Developer account (PLAN: "iOS build blocked on Mac/Apple Developer account"), and several
> Android-specific features do not exist on iOS (Usage Access screen time, the dark-room
> foreground service, exact alarms, the home-screen widget via `home_widget`). Treat this
> section as **copy ready for the day iOS is unblocked**, and do not publish an App Store
> listing that promises Android-only features.

### 2.1 Name / subtitle / keywords

| Field | Copy | Limit | Chars |
|---|---|---|---|
| App name | `EyeCare AI` | 30 | 9 |
| Subtitle | `20-20-20 breaks & eye score` | 30 | 27 |
| Promotional text | `New: Eye Timeline turns your day into a readable feed of breaks, screen sessions and low-light moments. Free, no ads, English + Tiếng Việt.` | 170 | 139 |
| Keywords | `eye,eyes,strain,screen,break,reminder,timer,habit,score,sleep,outdoor,blink,20-20-20,vision,wellness` | 100 | 100 |

> The keyword string has **no spaces after commas** — Apple counts every character, spaces
> included. "strain" and "timer" are unused on the app name/subtitle, which is where the
> 100 characters are best spent.
>
> iOS keyword field is a *single* 100-character string, and Apple's search matches
> substrings across name, subtitle and keywords — hence "eye" and "eyes" both, and the
> hyphenated "20-20-20" plus its normal token.

### 2.2 iOS description

Use the Play full description with these edits:

- Delete the Android-only line about Usage Access and the GitHub Releases APK instructions.
- Replace with the App Store install sentence ("Download from the App Store; updates are automatic").
- Keep the camera sentence — it is true on iOS too (ML Kit runs on-device).
- Replace the Android-specific "focus mode" bullet only if the DND path is not wired on iOS
  (verify `focus_mode_service.dart` on iOS before publishing).
- Keep the "NOT A MEDICAL DEVICE" block verbatim.

### 2.3 iOS App Privacy (nutrition label) — draft answers

| Apple privacy category | Answer | Why |
|---|---|---|
| Data Used to Track You | **Nothing** | No tracking, no ads, no third-party SDKs that track. `AnalyticsService` is a stub; if it is ever wired to a self-hosted endpoint, it must stay tracking-free (no IDFA, no cross-app identifiers). |
| Contact Info — Email Address | Linked to you | Account e-mail |
| Identifiers — User ID | Linked to you | Firebase UID |
| Usage Data — Product Interaction | Linked to you | Screen-on time and per-app usage — **only when cloud backup is enabled**, because it is included in the backup document the developer stores in Firebase. The analytics service is a stub, so no interaction or screen-view events are collected. |
| Health & Fitness | Linked to you | Eye Health Score, sleep estimate, outdoor minutes — **only** if cloud backup / AI is used; note this in the privacy policy |
| Diagnostics | Not collected | No crash SDK |
| Purchases | Not collected | Free |

---

## 3. Launch checklist (in order)

1. ~~Publish the privacy policy + terms pages~~ — **done**, published from the `gh-pages`
   branch and returning HTTP 200. Put these URLs in Play Console:
   `https://thongaccount.github.io/eye_care_ai/legal/privacy.html` and
   `.../legal/terms.html`. Non-negotiable — Play rejects listings without it.
2. Decide the cloud-backup default (recommend: opt-in) and the AI-proxy question, then
   fill the Data safety form from §1.7 exactly.
3. Create the Play Developer account (**TODO — personal account or organisation?** A personal
   account is fine for a solo founder; it caps the tester count to 20 for open testing and
   shows the developer's legal name on the listing).
4. Upload an **Android App Bundle (`.aab`)** to Play — Play rejects APK uploads for new apps.
   ⚠️ **The current pipeline builds APKs only** (`flutter build apk` in both `run_build.py` and
   `.github/workflows/build-apk.yml`), so an AAB target has to be added to the build before
   submission. `versionCode` must be higher than any previously uploaded build; here it is the
   CI run number, so every new run is automatically higher. Sign with a **real** upload key (the
   committed `ci-fallback-keystore.jks` is a placeholder — keystore rotation is still on the
   tech-debt list).
5. Add a release-signing key in Play Console → App integrity → App signing (mandatory for
   Play App Signing).
6. Install the Play listing's screenshots (see `screenshots-outline.md`).
7. Set a start rating-request strategy (see `handoff-rate-app.md`).
8. Release as **Closed testing → open → Production**, with the health-adjacent copy as
   written. Do not add the word "medical" anywhere.

---

## 4. Open questions for the user

| # | Question | Blocks |
|---|---|---|
| 1 | Play developer account: personal or organisation? Legal name/address to show? | Listing creation |
| 2 | Primary market: Vietnam, USA, or global? (Vietnamese is already in-app; English is the default) | Screenshot localisation + keyword language | 
| 3 | Pricing: free forever, or a one-time unlock / subscription for the PDF report + AI? | Play Console "monetisation" + listing copy |
| 4 | Cloud backup default: on (as shipped) or opt-in (recommended)? | Data safety answers |
| 5 | Before Play submission, should the AI key move behind a backend proxy? | Review risk + cost |
| 6 | Confirm the support e-mail `eyecareai.app@gmail.com` is the public contact | Play contact fields |
| 7 | Is the app's target audience 13+ or 18+? | Content rating + target audience field |
