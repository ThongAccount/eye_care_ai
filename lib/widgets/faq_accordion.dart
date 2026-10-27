import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../theme/app_colors.dart';

List<MapEntry<String, String>> _faqs(bool vi) => [
      MapEntry(
        vi ? 'Eye Care AI hoạt động như thế nào?' : 'How does Eye Care AI work?',
        vi
            ? 'Ứng dụng đọc thời gian màn hình từ hệ điều hành, ghi lại các thói quen bạn nhập — nghỉ mắt, giấc ngủ, thời gian ngoài trời — và có thể chạy một bài kiểm tra mắt ngắn bằng camera trước. Từ đó app gợi ý nghỉ ngơi và bài tập phù hợp với thói quen của bạn.'
            : 'It reads your screen time from the phone, keeps track of the habits you log — breaks, sleep, outdoor time — and can run a short eye test with the front camera. From that it suggests breaks and exercises that fit your habits.',
      ),
      MapEntry(
        vi ? 'Thời gian màn hình được tính như thế nào?' : 'How is screen time calculated?',
        vi
            ? 'Chúng tôi đọc thời gian dùng app ở chế độ nền mà hệ điều hành đã ghi nhận, cộng với số nghỉ mắt, giấc ngủ và thời gian ngoài trời do chính app ghi. Thời gian màn hình không được ước tính từ camera hay cảm biến nào.'
            : 'We read the foreground app usage your operating system already records, plus the breaks, sleep and outdoor time the app itself logs. Screen time is not estimated from the camera or any other sensor.',
      ),
      MapEntry(
        vi ? 'Vì sao tính năng phát hiện ngoài trời không hoạt động?' : "Why doesn't outdoor detection work?",
        vi
            ? 'Thời gian ngoài trời được phát hiện bằng GPS: app lấy mẫu khoảng một lần mỗi phút khi đang mở, và khoảng mỗi 15 phút khi chạy nền. Việc lấy mẫu khi chạy nền cần quyền vị trí "Luôn cho phép".'
            : 'Outdoor time is detected with GPS: the app samples a good satellite fix about once a minute while it is open, and about every 15 minutes in the background. The background samples need the "Allow all the time" location permission.',
      ),
      MapEntry(
        vi ? 'AI tạo gợi ý như thế nào?' : 'How does AI generate recommendations?',
        vi
            ? 'Gợi ý được tạo dựa trên thói quen bạn đã ghi, tần suất nghỉ ngơi và (nếu bật) phân tích AI cá nhân hóa dựa trên thói quen sử dụng.'
            : 'Recommendations are generated from your logged habits, break frequency, and (if enabled) personalized AI analysis of your usage patterns.',
      ),
      MapEntry(
        vi ? 'Làm sao để đặt lại tiến trình?' : 'How do I reset my progress?',
        vi
            ? 'Vào Cài đặt > Cài đặt thêm > Quản lý dữ liệu > Xóa toàn bộ dữ liệu cục bộ. Thao tác này đặt lại tiến trình trên thiết bị mà không xóa tài khoản.'
            : 'Go to Settings > More > Data Management > Delete All Local Data. This resets progress on this device without deleting your account.',
      ),
    ];

/// Accordion chỉ mở một mục tại một thời điểm.
class FaqAccordion extends StatefulWidget {
  const FaqAccordion({super.key});

  @override
  State<FaqAccordion> createState() => _FaqAccordionState();
}

class _FaqAccordionState extends State<FaqAccordion> {
  int? _openIndex;

  @override
  Widget build(BuildContext context) {
    final vi = context.watch<LanguageProvider>().isVietnamese;
    final faqs = _faqs(vi);
    return Column(
      children: [
        for (int i = 0; i < faqs.length; i++) ...[
          _FaqItem(
            question: faqs[i].key,
            answer: faqs[i].value,
            expanded: _openIndex == i,
            onTap: () => setState(() => _openIndex = _openIndex == i ? null : i),
          ),
          if (i != faqs.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({
    required this.question,
    required this.answer,
    required this.expanded,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool expanded;
  final VoidCallback onTap;

  static const _duration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      question,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: _duration,
                    curve: Curves.easeOutCubic,
                    child: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                  ),
                ],
              ),
              AnimatedSize(
                duration: _duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedCrossFade(
                  duration: _duration,
                  crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      answer,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
