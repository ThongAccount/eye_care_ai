/// URL công khai của các tài liệu pháp lý của ứng dụng.
///
/// Tài liệu đầy đủ được publish bằng GitHub Pages từ nhánh `gh-pages`
/// (xem `docs/web/README.md`). Nội dung trong app chỉ là TÓM TẮT — luôn mở
/// URL bên dưới để đọc bản đầy đủ và bản có hiệu lực.
///
/// Đổi URL ở ĐÂY thôi, đừng rải string literal ở nhiều widget.
class LegalUrls {
  const LegalUrls._();

  /// Chính sách quyền riêng tư (bắt buộc cho Google Play).
  static const String privacyPolicyUrl =
      'https://thongaccount.github.io/eye_care_ai/legal/privacy.html';

  /// Điều khoản sử dụng.
  static const String termsOfServiceUrl =
      'https://thongaccount.github.io/eye_care_ai/legal/terms.html';

  /// Trang giới thiệu (landing page song ngữ EN / Tiếng Việt).
  static const String landingPageUrl =
      'https://thongaccount.github.io/eye_care_ai/';
}
