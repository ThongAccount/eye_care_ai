import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mở tài liệu pháp lý đã publish (bản đầy đủ, có hiệu lực) bằng trình
/// duyệt hệ thống.
///
/// Nội dung trong app chỉ là tóm tắt — luôn mở URL bản publish để người dùng
/// đọc đủ và đúng bản mới nhất. URL nằm trong `lib/config/legal_urls.dart`.
class LegalLinkService {
  const LegalLinkService._();

  /// Mở [url]; nếu hệ thống không mở được thì báo nhẹ cho người dùng thay
  /// vì im lặng (người dùng tưởng nút bị hỏng).
  static Future<void> open(
    BuildContext context,
    String url, {
    required bool vi,
  }) async {
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vi ? 'Không mở được liên kết' : 'Could not open the link',
          ),
        ),
      );
    }
  }
}
