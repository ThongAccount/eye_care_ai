import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/legal_urls.dart';
import '../providers/language_provider.dart';
import '../screens/document_viewer_screen.dart';
import '../services/legal_link_service.dart';
import '../theme/app_colors.dart';

/// Loại nội dung của một thẻ trong mục Điều khoản.
enum _DocKind {
  /// Hiển thị [body] trong màn hình đọc tài liệu trong app.
  viewer,

  /// Mở URL bên ngoài (bản đầy đủ đã publish).
  external,

  /// Mở danh sách giấy phép thư viện của Flutter.
  licenses,
}

class _TermsDoc {
  const _TermsDoc(
    this.title,
    this.icon,
    this.body, {
    this.kind = _DocKind.viewer,
    this.url,
  });

  final String title;
  final IconData icon;
  final String body;

  /// Cách hiển thị thẻ này.
  final _DocKind kind;

  /// URL bên ngoài — chỉ dùng khi [kind] là [_DocKind.external].
  final String? url;
}

/// Nội dung tóm tắt trong app. Bản đầy đủ (và bản có hiệu lực) nằm ở
/// `web/legal/terms.html` + `web/legal/privacy.html`, publish tại
/// `LegalUrls.termsOfServiceUrl` / `LegalUrls.privacyPolicyUrl`.
///
/// Nội dung ở đây được rút từ các mục 01-07 của bản Terms đã publish, và
/// phải được cập nhật kèm khi bản publish thay đổi.
List<_TermsDoc> _docs(bool vi) => [
      _TermsDoc(
        vi ? 'Chính sách sử dụng ứng dụng' : 'App Usage Policy',
        Icons.description_outlined,
        vi
            ? 'Khi dùng EyeCare AI, bạn đồng ý với các điều khoản này và chỉ dùng ứng dụng cho mục đích cá nhân, phi thương mại nhằm cải thiện sức khỏe mắt. Bạn không được dùng ứng dụng để vi phạm pháp luật, can thiệp vào hoạt động của ứng dụng, hoặc dịch ngược mã nguồn. Toàn bộ điều khoản được công bố trực tuyến tại liên kết bên dưới.'
            : 'By using EyeCare AI you agree to these terms and to using the app only for personal, non-commercial wellbeing purposes. You agree not to use the app to break the law, to interfere with its operation, or to reverse-engineer it. The full terms are published online at the link below.',
      ),
      _TermsDoc(
        vi ? 'Trách nhiệm người dùng' : 'User Responsibilities',
        Icons.assignment_ind_outlined,
        vi
            ? 'Bạn chịu trách nhiệm giữ an toàn thông tin đăng nhập và chịu trách nhiệm về hoạt động diễn ra dưới tài khoản của mình. Nếu dùng tính năng nhắc người bảo hộ, bạn chịu trách nhiệm nhập một địa chỉ mà bạn được phép liên hệ. Ứng dụng đọc dữ liệu ngay trên máy như thời gian dùng màn hình và ánh sáng môi trường để tính điểm; bạn chủ động cấp quyền và có thể xóa dữ liệu cục bộ bất cứ lúc nào.'
            : 'You are responsible for keeping your account credentials secure and for activity that happens under your account. If you use the guardian reminder feature, you are responsible for entering an address you are permitted to contact. The app reads on-device data such as screen-on time and ambient light to build your scores; you decide which permissions to grant, and you can delete local data at any time.',
      ),
      _TermsDoc(
        vi ? 'Tuyên bố miễn trừ AI' : 'AI Disclaimer',
        Icons.smart_toy_outlined,
        vi
            ? 'Trợ lý AI là công cụ hỗ trợ sức khỏe, không phải chuyên gia y tế. AI chỉ dựa trên dữ liệu đã lưu trên máy của bạn và không bao giờ được bịa số liệu. AI đề xuất các hành động — như nghỉ mắt hoặc điều chỉnh lịch nhắc — và luôn hỏi xác nhận trước khi thực hiện, vì các hành động đó có thể thay đổi lịch nhắc và cài đặt của bạn. Câu trả lời của AI có thể sai; không dùng AI để đưa ra quyết định y tế.'
            : 'The AI assistant is a wellbeing tool, not a clinician. It can only act on data already stored on your device and must never invent measurements. It proposes actions — such as taking a break or adjusting a reminder — and asks for your confirmation before performing them, because actions on your device can change your reminders and settings. AI responses can be wrong; do not rely on them for medical decisions.',
      ),
      _TermsDoc(
        vi ? 'Tuyên bố miễn trừ y tế' : 'Medical Disclaimer',
        Icons.local_hospital_outlined,
        vi
            ? 'EyeCare AI không phải là thiết bị y tế và chưa được thẩm định lâm sàng. Điểm sức khỏe mắt, ước tính thời gian ngủ và thời gian ngoài trời chỉ là ước tính sức khỏe dựa trên tín hiệu đo trên máy — không phải chẩn đoán, không phải số đo của thiết bị y tế, và không thay thế việc khám chuyên môn. Nếu bạn thấy thị lực thay đổi đột ngột, hiện tia sáng, vệt đen trong mắt, nhìn đôi hoặc đau đầu kéo dài, hãy ngừng dùng ứng dụng và sớm đi khám bác sĩ nhãn khoa.'
            : 'EyeCare AI is not a medical device and has not been clinically validated. The Eye Health Score, the sleep estimate and the outdoor-time estimate are wellness estimates produced from on-device signals — they are not diagnoses, measurements by a medical device, or a substitute for professional assessment. If you have sudden vision changes, flashes, floaters, double vision or a persistent headache, stop using the app and see an optometrist or ophthalmologist promptly.',
      ),
      _TermsDoc(
        vi ? 'Chính sách bảo vệ dữ liệu' : 'Data Protection Policy',
        Icons.shield_outlined,
        vi
            ? 'Điểm sức khỏe mắt, lịch sử kiểm tra mắt, sự kiện dòng thời gian, dữ liệu ánh sáng môi trường và tọa độ GPS của bạn được tính toán và lưu ngay trên máy. Dữ liệu chỉ rời khỏi máy khi tính năng cần đến: tài khoản Google để đăng nhập, mục bảng xếp hạng, sao lưu đám mây và tin nhắn trò chuyện AI gửi tới NVIDIA. Ứng dụng không cài SDK quảng cáo, và dịch vụ phân tích hiện là khung rỗng nên không thu thập gì. Toàn bộ chính sách được công bố trực tuyến tại liên kết bên dưới.'
            : 'Your eye scores, eye-test history, timeline events, ambient-light readings and GPS fixes are computed and stored on your device. Data leaves the device only where a feature requires it: your account with Google for sign-in, the leaderboard entry, cloud backup, and AI chat messages sent to NVIDIA. The app contains no advertising SDK, and its analytics service is a stub that currently collects nothing. The full policy is published online at the link below.',
      ),
      _TermsDoc(
        vi ? 'Giấy phép mã nguồn mở' : 'Open Source Licenses',
        Icons.code_rounded,
        vi
            ? 'EyeCare AI được xây dựng trên các gói Flutter mã nguồn mở. Chạm để xem danh sách giấy phép đầy đủ.'
            : 'EyeCare AI is built on open-source Flutter packages. Tap to see the full list of licences.',
        kind: _DocKind.licenses,
      ),
      _TermsDoc(
        vi ? 'Chính sách quyền riêng tư (trực tuyến)' : 'Privacy Policy (online)',
        Icons.privacy_tip_outlined,
        '',
        kind: _DocKind.external,
        url: LegalUrls.privacyPolicyUrl,
      ),
      _TermsDoc(
        vi ? 'Điều khoản sử dụng (trực tuyến)' : 'Terms of Service (online)',
        Icons.public_rounded,
        '',
        kind: _DocKind.external,
        url: LegalUrls.termsOfServiceUrl,
      ),
    ];

/// Mở URL bên ngoài; nếu không mở được thì báo nhẹ cho người dùng.
Future<void> _openExternal(
  BuildContext context,
  String url, {
  required bool vi,
}) =>
    LegalLinkService.open(context, url, vi: vi);

class TermsOfServiceSection extends StatelessWidget {
  const TermsOfServiceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final docs = _docs(strings.vi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final doc in docs) ...[
          _DocCard(doc: doc, vi: strings.vi),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              Text(strings.termsVersion, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(strings.termsLastUpdated, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, required this.vi});

  final _TermsDoc doc;
  final bool vi;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          switch (doc.kind) {
            case _DocKind.viewer:
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      DocumentViewerScreen(title: doc.title, body: doc.body),
                ),
              );
              break;
            case _DocKind.external:
              final url = doc.url;
              if (url != null) _openExternal(context, url, vi: vi);
              break;
            case _DocKind.licenses:
              showLicensePage(
                context: context,
                applicationName: 'EyeCare AI',
                applicationVersion:
                    context.read<LanguageProvider>().strings.termsVersion,
              );
              break;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(doc.icon, size: 19, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5)),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
