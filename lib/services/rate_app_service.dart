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
  static Uri playWebUri() => Uri.parse(
      'https://play.google.com/store/apps/details?id=${StoreLinks.androidPackageId}');

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
        final webOpened =
            await launchUrl(playWebUri(), mode: LaunchMode.externalApplication);
        if (webOpened) return;
      }
    }

    // Màn hình có thể đã bị đóng trong lúc chờ trình duyệt/store mở link —
    // không mở hộp thoại trên một context đã unmount.
    if (!context.mounted) return;
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
