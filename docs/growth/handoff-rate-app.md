# Handoff — "Rate App" (ready to apply)

**Owner:** Chief (owns `lib/`). **Author:** GrowthLead. **Status:** not implemented.

Verified 2026-10-24: `grep` over `lib/` finds **no** `market://`, `play.google.com`,
`apps.apple.com`, `rateApp` or "Rate the app" reference — the feature does not exist yet.
PLAN.md's code-verified table lists it as ❌ *Rate App — no store link yet (handoff in flight
on `docs/growth-store-launch`)*, so this document closes that row.

Everything below is designed to be applied as-is. It touches three new files and two small
edits; nothing here is required for the app to build.

---

## 1. The identifiers (already in the repo — no guessing)

| Identifier | Value | Where it comes from |
|---|---|---|
| Android package id | `com.eyecare.eye_care_ai` | `android/app/build.gradle.kts:63` (`applicationId`) |
| iOS bundle id | `com.eyecare.eyeCareAi` | `ios/Runner.xcodeproj/project.pbxproj:385` (`PRODUCT_BUNDLE_IDENTIFIER`) |
| App Store numeric id | **does not exist yet** | the app has never been submitted to Apple — needs the user |
| Play listing | **does not exist yet** | distribution today is GitHub Releases |
| Download fallback | `https://github.com/ThongAccount/eye_care_ai/releases` | repo |
| Support e-mail | `eyecareai.app@gmail.com` | `lib/widgets/help_support_section.dart:13` |

---

## 2. New file — `lib/config/store_links.dart`

```dart
/// Store identifiers and links for the "Rate EyeCare AI" flow.
///
/// Everything here is a constant so that flipping a listing from "not published"
/// to "published" is a one-line change, and so the URLs can be unit-tested
/// without launching anything.
class StoreLinks {
  const StoreLinks._();

  /// Android applicationId — android/app/build.gradle.kts
  static const String androidPackageId = 'com.eyecare.eye_care_ai';

  /// iOS bundle identifier — ios/Runner.xcodeproj/project.pbxproj
  static const String iosBundleId = 'com.eyecare.eyeCareAi';

  /// TODO(user): flip to true the moment the Play listing is public.
  /// While false, the app uses the GitHub Releases fallback instead of
  /// sending the user to a store page that does not exist yet.
  static const bool playListingPublished = false;

  /// TODO(user): flip to true when the App Store build is approved.
  static const bool appStoreListingPublished = false;

  /// TODO(user): numeric App Store ID (the digits in the store URL), e.g.
  /// '1234567890'. Empty until the app is approved.
  static const String appStoreId = '';

  /// Where the app can be downloaded while it is not in a store.
  static const String downloadUrl =
      'https://github.com/ThongAccount/eye_care_ai/releases';

  /// Public support e-mail (already used by the in-app feedback form).
  static const String supportEmail = 'eyecareai.app@gmail.com';
}
```

---

## 3. New file — `lib/services/rate_app_service.dart`

The URL building is a **pure static function** so it can be unit-tested without a device
(`test/rate_app_service_test.dart`, following the style of the existing
`settings_provider_test.dart` / `update_service_test.dart`).

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/store_links.dart';
import '../models/app_strings.dart';

/// Opens the store listing (and the in-app review sheet where the platform
/// supports it), with a graceful path for users whose build was installed
/// outside the store or whose platform has no listing yet.
class RateAppService {
  RateAppService._();
  static final RateAppService instance = RateAppService._();

  /// Pure URL builder — unit-testable.
  ///
  /// Returns null when there is no live listing for [platform], which is the
  /// signal to use the fallback instead of opening a dead store page.
  @visibleForTesting
  static Uri? buildStoreUri({
    required String platform,
    required bool playPublished,
    required bool appStorePublished,
    required String appStoreId,
  }) {
    if (platform == 'android' && playPublished) {
      // Opens the listing; on a Play-installed build the "Rate" button is
      // present, otherwise the user lands on the listing page.
      return Uri.parse('market://details?id=${StoreLinks.androidPackageId}');
    }
    if (platform == 'iOS' && appStorePublished && appStoreId.isNotEmpty) {
      // https://apps.apple.com/app/id<APPID>?action=write-review opens the
      // review sheet directly on iOS 16+.
      return Uri.parse(
          'https://apps.apple.com/app/id$appStoreId?action=write-review');
    }
    return null;
  }

  /// HTTPS listing URLs, used when the deep link cannot be handled.
  static Uri playWebUri() =>
      Uri.parse('https://play.google.com/store/apps/details?id=${StoreLinks.androidPackageId}');

  Future<void> openRateFlow(BuildContext context, AppStrings strings) async {
    final platform = defaultTargetPlatform.name; // 'android' | 'iOS' | ...
    final uri = buildStoreUri(
      platform: platform,
      playPublished: StoreLinks.playListingPublished,
      appStorePublished: StoreLinks.appStoreListingPublished,
      appStoreId: StoreLinks.appStoreId,
    );

    if (uri != null) {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
      // The device had no handler for market:// — fall through to the web URL.
      if (platform == 'android') {
        final webOpened = await launchUrl(playWebUri(), mode: LaunchMode.externalApplication);
        if (webOpened) return;
      }
    }

    await _showFallback(context, strings);
  }

  /// No live store listing (or the deep link failed): thank the user, point at
  /// the real download, and offer a feedback e-mail instead of a dead link.
  Future<void> _showFallback(BuildContext context, AppStrings strings) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.rateAppThanksTitle),
        content: Text(strings.rateAppFallbackBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              launchUrl(
                Uri.parse('mailto:${StoreLinks.supportEmail}'
                    '?subject=${Uri.encodeComponent('EyeCare AI feedback')}'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: Text(strings.rateAppFeedback),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              launchUrl(Uri.parse(StoreLinks.downloadUrl),
                  mode: LaunchMode.externalApplication);
            },
            child: Text(strings.rateAppDownload),
          ),
        ],
      ),
    );
  }
}
```

### 3.1 Strings to add to `lib/models/app_strings.dart`

```dart
String get rateAppTitle => vi ? 'Đánh giá EyeCare AI' : 'Rate EyeCare AI';
String get rateAppSubtitle =>
    vi ? 'Góp ý giúp ứng dụng tốt hơn' : 'Your review helps other people find it';
String get rateAppThanksTitle =>
    vi ? 'Cảm ơn bạn!' : 'Thanks for using EyeCare AI!';
String get rateAppFallbackBody => vi
    ? 'EyeCare AI chưa có trên kho ứng dụng. Bạn có thể tải bản mới nhất trên GitHub Releases, hoặc gửi góp ý cho chúng tôi.'
    : 'EyeCare AI is not in an app store yet. You can get the latest build from GitHub Releases, or send us your feedback directly.';
String get rateAppFeedback => vi ? 'Gửi góp ý' : 'Send feedback';
String get rateAppDownload => vi ? 'Tải bản mới nhất' : 'Get the latest build';
String get rateAppLater => vi ? 'Để sau' : 'Maybe later';
```

---

## 4. UI wiring — two small edits

### 4.1 Settings entry (always visible)

`lib/screens/settings_screen.dart` — the settings list contains `_MenuItem`s for Terms,
Help & Support, Changelog, Data & Usage permissions (`settings_screen.dart:424-456`).
Add one more, directly after the Changelog item:

```dart
const Divider(height: 1, indent: 56),
_MenuItem(
  icon: '⭐',
  title: strings.rateAppTitle,
  onTap: () => RateAppService.instance.openRateFlow(context, strings),
),
```

`url_launcher` is already a dependency (`pubspec.yaml`), so **no new dependency, no
`android.permission` change and no manifest change** is needed.

### 4.2 Contextual prompt (optional, recommended after the listing is live)

Ask for a rating only after the user has actually got value from the app, and never more
than once in a while:

| Rule | Value | Why |
|---|---|---|
| Trigger | `HabitProvider.streakDays >= 7` **or** a weekly report was opened | Reviews from users who got value are the only reviews worth having |
| Never | first launch, during onboarding, or right after a failed/low eye-test result | Asking at a bad moment converts goodwill into a 1-star |
| Frequency cap | once per 90 days per install | Store algorithms treat repeated prompts as spam |
| Dismissal | store `rate_prompt_last_shown` (epoch ms) in `SharedPreferences` | survives restarts without analytics |
| Two-step | if the store rating is below a threshold, route to the feedback e-mail instead of the store | classic "unhappy → feedback, happy → public review" split |

The prompt is a `showDialog` with three buttons: **Rate** → `openRateFlow`, **Send
feedback** → `mailto:eyecareai.app@gmail.com`, **Maybe later** → persist the dismissal.

---

## 5. Behaviour matrix (what happens where)

| Platform | Listing live | Result |
|---|---|---|
| Android | Yes | `market://details?id=com.eyecare.eye_care_ai` → Play listing (the "Rate" button appears for Play-installed builds) |
| Android | No | Fallback dialog → GitHub Releases + feedback e-mail |
| Android, no `market://` handler | Yes | `https://play.google.com/store/apps/details?id=com.eyecare.eye_care_ai` |
| iOS | Yes | `https://apps.apple.com/app/id<APPID>?action=write-review` → review sheet |
| iOS | No | Fallback dialog → GitHub Releases + feedback e-mail (iOS builds are not published yet, so this is the current reality) |
| Any, user installed via sideloaded APK | Yes | The listing page opens; Play may hide the "Rate" button for non-Play installs — the feedback e-mail remains available |

---

## 6. Test plan (pure Dart, no device needed)

`test/rate_app_service_test.dart`:

| Test | Expectation |
|---|---|
| `buildStoreUri(platform: 'android', playPublished: true, …)` | `market://details?id=com.eyecare.eye_care_ai` |
| `buildStoreUri(platform: 'android', playPublished: false, …)` | `null` (fallback path) |
| `buildStoreUri(platform: 'iOS', appStorePublished: true, appStoreId: '123')` | `https://apps.apple.com/app/id123?action=write-review` |
| `buildStoreUri(platform: 'iOS', appStorePublished: true, appStoreId: '')` | `null` — an empty App Store ID must never produce a broken URL |
| `buildStoreUri(platform: 'macOS', …)` | `null` |

---

## 7. How we will know it worked

| Metric | Source | Target | Decision rule |
|---|---|---|---|
| Store rating | Play Console → Ratings & reviews | ≥ 4.3 after 25 reviews | if median rating < 4.0, stop prompting and route to feedback |
| Review volume | Play Console | ≥ 25 reviews in the first 60 days after launch | if < 5 after 60 days, the prompt is not reaching enough users — raise the trigger from 7 to 14 streak days |
| Prompt acceptance | `rate_prompt_shown` / `rate_prompt_accepted` events (defined in `analytics-events.md`) | ≥ 15% of prompts accepted | analytics is a stub today — wire the event when it is implemented, or read it from Play Console only |
| Feedback e-mails | e-mail inbox | qualitative | every 1–2 star review should produce a feedback e-mail; that is where the next feature comes from |

---

## 8. Still needed from the user

1. **Is the Play listing going out, and when?** Until `playListingPublished = true`, the
   feature falls back to the GitHub Releases dialog. If Play is not planned, ship the
   fallback-only version — it still gives the e-mail feedback loop.
2. **The numeric App Store ID** (after the first approval).
3. **Confirm the support e-mail** `eyecareai.app@gmail.com` is the address that should be
   published in the store listing too.
4. **Which trigger to use** for the contextual prompt: 7-day streak (recommended) or
   "weekly report opened".

## 9. Merge note

This document only adds files under `docs/growth/`. The `lib/` changes above are **not**
applied by this branch — they are a handoff for Chief to implement in `lib/` (or hand to
MobileLead), because MobileLead currently owns `lib/` for the P0 track.
