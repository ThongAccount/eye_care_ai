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
