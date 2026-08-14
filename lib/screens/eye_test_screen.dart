import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_strings.dart';
import '../providers/language_provider.dart';
import '../services/distance_service.dart';
import '../theme/app_colors.dart';

/// NÂNG CẤP TÍNH NĂNG KIỂM TRA MẮT.
///
/// Bản CŨ: cho xem 1 chữ cỡ CỐ ĐỊNH (không đổi), người dùng tự bấm "Đọc rõ"
/// hay "Không rõ" — hoàn toàn chủ quan, không đo đạc gì thật, ai bấm "Đọc
/// rõ" hết cũng ra điểm tối đa dù cỡ chữ chưa hề thử nhỏ dần.
///
/// Bản MỚI dùng bài "Tumbling E" — cách đo thị lực khách quan phổ biến
/// trong sàng lọc mắt (chữ E xoay 4 hướng, người xem chỉ HƯỚNG mở của chữ E
/// thay vì tự nhận xét "rõ hay không") + 2 điểm cải tiến quan trọng:
///   1. ĐO RIÊNG TỪNG MẮT (che 1 mắt bằng tay) — phát hiện được lệch thị
///      lực giữa 2 mắt, điều mà đo gộp 2 mắt cùng lúc sẽ không bao giờ thấy.
///   2. CỠ CHỮ GIẢM DẦN theo kiểu staircase — tìm ra chính xác NGƯỠNG cỡ
///      chữ nhỏ nhất còn nhận diện đúng hướng, thay vì hỏi cảm tính ở 1 cỡ
///      chữ không đổi.
/// Thêm bài phụ đo ĐỘ NHẠY TƯƠNG PHẢN (contrast sensitivity) — độ mờ mắt/
/// mỏi mắt thường ảnh hưởng tới khả năng phân biệt tương phản THẤP trước cả
/// khi ảnh hưởng tới thị lực chữ rõ nét, nên đây là tín hiệu sớm hữu ích.
///
/// LƯU Ý QUAN TRỌNG: đây vẫn là công cụ SÀNG LỌC NHANH tại nhà, không thay
/// thế khám mắt chuyên khoa — độ chính xác còn phụ thuộc người dùng có giữ
/// đúng khoảng cách hướng dẫn (~40cm, tầm sải tay) hay không, độ sáng màn
/// hình, ánh sáng phòng... Kết quả hiển thị luôn kèm khuyến cáo gặp bác sĩ
/// nếu nghi ngờ có vấn đề, không đưa ra chỉ số Snellen (20/20...) giả danh
/// y khoa vì không đo được khoảng cách thật (không dùng camera).
class EyeTestScreen extends StatefulWidget {
  const EyeTestScreen({super.key});

  @override
  State<EyeTestScreen> createState() => _EyeTestScreenState();
}

enum _Direction { up, right, down, left }

enum _Phase { intro, rightEye, leftEye, contrast, result }

// Cỡ chữ E giảm dần theo tỉ lệ ~1.2x mỗi bậc — khoảng cách bậc tương tự
// cách các bảng đo thị lực chuẩn chia độ (theo cấp số nhân, không phải cấp
// số cộng) để mỗi bậc khó hơn bậc trước một lượng NHƯ NHAU về mặt cảm nhận.
const List<double> _kAcuitySizes = [130, 108, 90, 75, 62, 52, 43, 36];

// Độ tương phản (opacity của chữ E trên nền) giảm dần — dùng để đo độ nhạy
// tương phản, cỡ chữ giữ CỐ ĐỊNH ở mức trung bình dễ đọc để chỉ riêng biến
// số tương phản thay đổi.
const List<double> _kContrastLevels = [0.9, 0.7, 0.5, 0.34, 0.2, 0.1];

class _EyeTestScreenState extends State<EyeTestScreen> {
  _Phase _phase = _Phase.intro;

  // ---- Trạng thái staircase đo thị lực (dùng lại cho cả 2 mắt) ----
  int _sizeIndex = 0;
  int _wrongAtThisSize = 0;
  _Direction? _currentDirection;
  int? _rightEyeLevel; // số bậc vượt qua được (0-8), null = chưa đo
  int? _leftEyeLevel;

  // ---- Trạng thái test tương phản ----
  int _contrastIndex = 0;
  int? _contrastLevel; // số bậc vượt qua được (0-6), null = chưa đo

  final _random = math.Random();
  List<Map<String, dynamic>> _history = [];

  // Khoảng cách đo được lần gần nhất từ camera (cm) — null = chưa đo được/
  // camera không khả dụng/chưa cấp quyền. Chỉ dùng để CẢNH BÁO + khuyến
  // khích đứng đúng khoảng cách, KHÔNG chặn cứng nút "Bắt đầu" (nhiều máy
  // không có camera trước hoạt động tốt/người dùng từ chối quyền — vẫn phải
  // cho làm bài test bình thường, xuống cấp nhẹ nhàng về trải nghiệm cũ).
  double? _liveDistanceCm;
  static const double _kIdealMinCm = 30;
  static const double _kIdealMaxCm = 55;

  // Camera có đang thực sự chạy hay không (đã cấp quyền + khởi động thành
  // công) — dùng để phân biệt "chưa đo được vì camera chưa sẵn sàng/không
  // khả dụng" (KHÔNG chặn bài test) với "camera đang chạy nhưng sai khoảng
  // cách" (CÓ chặn, theo đúng yêu cầu).
  bool _cameraActive = false;
  // Tạm dừng bài test khi sai khoảng cách quá 700ms liên tục (debounce —
  // tránh chớp tắt overlay liên tục chỉ vì 1 khung hình đo trượt thoáng qua,
  // ví dụ lúc chớp mắt/quay đầu đổi hướng giữa 2 câu hỏi).
  bool _showDistancePause = false;
  Timer? _distanceDebounceTimer;

  // Thông báo lớn giữa màn hình khi vừa chuyển sang vòng test mới (mắt
  // phải/mắt trái/tương phản) — hiện vài giây rồi tự ẩn, để người dùng chỉ
  // cần LIẾC 1 lần biết đang test gì, không phải đọc chữ hướng dẫn suốt
  // trong lúc làm bài (khác bản trước: title/subtitle nằm cố định phía trên
  // D-pad, chiếm chỗ và bắt đọc liên tục).
  bool _showAnnouncement = false;
  Timer? _announcementTimer;

  void _announce() {
    _announcementTimer?.cancel();
    setState(() => _showAnnouncement = true);
    _announcementTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showAnnouncement = false);
    });
  }

  void _handleDistanceUpdate(double? cm) {
    setState(() => _liveDistanceCm = cm);
    if (!_cameraActive) return; // camera chưa chạy -> không có gì để chặn

    final ok = cm != null && cm >= _kIdealMinCm && cm <= _kIdealMaxCm;
    if (ok) {
      _distanceDebounceTimer?.cancel();
      if (_showDistancePause) setState(() => _showDistancePause = false);
    } else {
      _distanceDebounceTimer?.cancel();
      _distanceDebounceTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showDistancePause = true);
      });
    }
  }

  @override
  void dispose() {
    _distanceDebounceTimer?.cancel();
    _announcementTimer?.cancel();
    // Dừng camera hẳn khi rời màn kiểm tra mắt — đây là nơi DUY NHẤT chịu
    // trách nhiệm dừng, vì camera được dùng XUYÊN SUỐT nhiều bước (giới
    // thiệu -> mắt phải -> mắt trái -> tương phản), không dừng theo widget
    // con nào cả.
    DistanceService.instance.stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('eye_test_history');
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _history = list);
    } catch (_) {
      // Dữ liệu cũ hỏng/không đọc được -> bỏ qua, không crash.
    }
  }

  Future<void> _saveResult(int overallPercent) async {
    final entry = {
      'date': DateTime.now().toIso8601String(),
      'rightEyeLevel': _rightEyeLevel,
      'leftEyeLevel': _leftEyeLevel,
      'contrastLevel': _contrastLevel,
      'overallPercent': overallPercent,
    };
    final updated = [..._history, entry];
    // Chỉ giữ 10 lần gần nhất, tránh phình dữ liệu vô hạn.
    final trimmed = updated.length > 10 ? updated.sublist(updated.length - 10) : updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eye_test_history', jsonEncode(trimmed));
    if (mounted) setState(() => _history = trimmed);
  }

  void _startAcuityPhase(_Phase phase) {
    setState(() {
      _phase = phase;
      _sizeIndex = 0;
      _wrongAtThisSize = 0;
      _currentDirection = _Direction.values[_random.nextInt(4)];
    });
    _announce();
  }

  void _answerAcuity(_Direction picked) {
    final correct = picked == _currentDirection;
    if (correct) {
      if (_sizeIndex >= _kAcuitySizes.length - 1) {
        // Vượt qua hết mọi bậc -> đạt điểm tối đa cho mắt này.
        _finishAcuityEye(_kAcuitySizes.length);
        return;
      }
      setState(() {
        _sizeIndex += 1;
        _wrongAtThisSize = 0;
        _currentDirection = _Direction.values[_random.nextInt(4)];
      });
    } else {
      if (_wrongAtThisSize >= 1) {
        // Sai 2 lần ở cùng 1 cỡ chữ -> dừng, ngưỡng = số bậc đã QUA được
        // trước đó (chính là _sizeIndex hiện tại, vì bậc này chưa qua).
        _finishAcuityEye(_sizeIndex);
        return;
      }
      // Sai lần đầu ở cỡ này -> cho thử lại 1 lần nữa với hướng MỚI (tránh
      // đoán mò lặp lại đúng hướng cũ).
      setState(() {
        _wrongAtThisSize += 1;
        _currentDirection = _Direction.values[_random.nextInt(4)];
      });
    }
  }

  void _finishAcuityEye(int levelReached) {
    setState(() {
      if (_phase == _Phase.rightEye) {
        _rightEyeLevel = levelReached;
      } else {
        _leftEyeLevel = levelReached;
      }
    });
    if (_phase == _Phase.rightEye) {
      _startAcuityPhase(_Phase.leftEye);
    } else {
      _startContrastPhase();
    }
  }

  void _startContrastPhase() {
    setState(() {
      _phase = _Phase.contrast;
      _contrastIndex = 0;
      _currentDirection = _Direction.values[_random.nextInt(4)];
    });
    _announce();
  }

  void _answerContrast(_Direction picked) {
    final correct = picked == _currentDirection;
    if (!correct) {
      _finishContrast(_contrastIndex);
      return;
    }
    if (_contrastIndex >= _kContrastLevels.length - 1) {
      _finishContrast(_kContrastLevels.length);
      return;
    }
    setState(() {
      _contrastIndex += 1;
      _currentDirection = _Direction.values[_random.nextInt(4)];
    });
  }

  void _finishContrast(int levelReached) {
    setState(() {
      _contrastLevel = levelReached;
      _phase = _Phase.result;
      _showDistancePause = false;
    });
    _distanceDebounceTimer?.cancel();
    // Đã xong bài test -> không cần đo khoảng cách nữa, dừng camera ngay,
    // không để chạy ngầm vô ích lúc người dùng đang xem kết quả.
    DistanceService.instance.stop();
    final percent = _overallPercent();
    _saveResult(percent);
  }

  int _overallPercent() {
    final r = (_rightEyeLevel ?? 0) / _kAcuitySizes.length;
    final l = (_leftEyeLevel ?? 0) / _kAcuitySizes.length;
    final c = (_contrastLevel ?? 0) / _kContrastLevels.length;
    return (((r + l + c) / 3) * 100).round();
  }

  void _resetTest() {
    _distanceDebounceTimer?.cancel();
    _announcementTimer?.cancel();
    setState(() {
      _phase = _Phase.intro;
      _sizeIndex = 0;
      _wrongAtThisSize = 0;
      _rightEyeLevel = null;
      _leftEyeLevel = null;
      _contrastIndex = 0;
      _contrastLevel = null;
      _currentDirection = null;
      _cameraActive = false;
      _showDistancePause = false;
      _showAnnouncement = false;
      _liveDistanceCm = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(strings.eyeTest),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.intro => _buildIntro(context, strings),
          _Phase.rightEye => _buildAcuityRound(context, strings, isRight: true),
          _Phase.leftEye => _buildAcuityRound(context, strings, isRight: false),
          _Phase.contrast => _buildContrastRound(context, strings),
          _Phase.result => _buildResult(context, strings),
        },
      ),
    );
  }

  // ---------------- Intro ----------------
  Widget _buildIntro(BuildContext context, AppStrings strings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.eyeTestIntroTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            strings.eyeTestIntroBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          _LiveDistanceMeter(
            idealMinCm: _kIdealMinCm,
            idealMaxCm: _kIdealMaxCm,
            onDistanceChanged: _handleDistanceUpdate,
            onActiveChanged: (active) => setState(() => _cameraActive = active),
          ),
          const SizedBox(height: 24),
          if (_history.isNotEmpty) _buildHistoryPreview(context, strings),
          const SizedBox(height: 12),
          if (_liveDistanceCm != null &&
              (_liveDistanceCm! < _kIdealMinCm || _liveDistanceCm! > _kIdealMaxCm))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _liveDistanceCm! < _kIdealMinCm ? strings.eyeTestTooClose : strings.eyeTestTooFar,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _startAcuityPhase(_Phase.rightEye),
              child: Text(strings.eyeTestStart),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.eyeTestDisclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPreview(BuildContext context, AppStrings strings) {
    final recent = _history.reversed.take(5).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.eyeTestHistoryTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          ...recent.map((e) {
            final date = DateTime.tryParse(e['date'] as String? ?? '');
            final percent = e['overallPercent'] as int? ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      date == null ? '—' : '${date.day}/${date.month}/${date.year}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text('$percent%', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------- Vòng đo thị lực (dùng chung cho 2 mắt) ----------------
  Widget _buildAcuityRound(BuildContext context, AppStrings strings, {required bool isRight}) {
    final size = _kAcuitySizes[_sizeIndex];
    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Text(
            '${strings.stepLabel} ${_sizeIndex + 1}/${_kAcuitySizes.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          _buildTumblingE(context, size: size, opacity: 1.0),
          const SizedBox(height: 32),
          Text(
            strings.eyeTestPickDirection,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildDirectionPad(onPick: _answerAcuity),
        ],
      ),
    );
    return _wrapWithDistanceGate(
      context,
      strings,
      content,
      // useHandCover: chuỗi có sẵn trong app, dùng đúng ngữ cảnh che 1 mắt
      // bằng tay — giờ chỉ hiện THOÁNG QUA trong overlay thông báo, không
      // còn nằm cố định phía trên bắt đọc suốt lúc làm bài.
      announceTitle: isRight ? strings.eyeTestRightEyeTitle : strings.eyeTestLeftEyeTitle,
      announceSubtitle: strings.useHandCover,
      announceIcon: Icons.visibility_rounded,
    );
  }

  // ---------------- Vòng đo độ nhạy tương phản ----------------
  Widget _buildContrastRound(BuildContext context, AppStrings strings) {
    final opacity = _kContrastLevels[_contrastIndex];
    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Text(
            '${strings.stepLabel} ${_contrastIndex + 1}/${_kContrastLevels.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          _buildTumblingE(context, size: 90, opacity: opacity),
          const SizedBox(height: 32),
          Text(
            strings.eyeTestPickDirection,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildDirectionPad(onPick: _answerContrast),
        ],
      ),
    );
    return _wrapWithDistanceGate(
      context,
      strings,
      content,
      announceTitle: strings.eyeTestContrastTitle,
      announceSubtitle: strings.eyeTestContrastBody,
      announceIcon: Icons.contrast_rounded,
    );
  }

  // Bọc nội dung 1 vòng test bằng: (1) badge góc trên-phải hiện khoảng cách
  // hiện tại nếu camera đang chạy, (2) lớp phủ toàn màn hình CHẶN thao tác +
  // tạm dừng bài test khi sai khoảng cách quá 700ms liên tục, (3) thông báo
  // LỚN GIỮA MÀN HÌNH hiện ~1.8s lúc vừa vào vòng test mới rồi tự ẩn — thay
  // cho việc bắt đọc title/subtitle cố định suốt lúc làm bài. Nếu camera
  // không khả dụng (_cameraActive == false), không hiện gì thêm cả — đúng
  // hành vi cũ, không ép buộc phải có camera mới làm được bài test.
  Widget _wrapWithDistanceGate(
    BuildContext context,
    AppStrings strings,
    Widget content, {
    required String announceTitle,
    required String announceSubtitle,
    required IconData announceIcon,
  }) {
    return Stack(
      children: [
        // IgnorePointer khi đang tạm dừng HOẶC đang hiện thông báo mở đầu —
        // cả 2 trường hợp đều chưa nên cho bấm D-pad.
        IgnorePointer(
          ignoring: _showDistancePause || _showAnnouncement,
          child: content,
        ),
        if (_cameraActive)
          Positioned(
            top: 8,
            right: 8,
            child: _buildDistanceBadge(context),
          ),
        // Thông báo LỚN GIỮA MÀN HÌNH lúc vừa vào vòng test — chỉ hiện khi
        // KHÔNG bị chặn bởi cảnh báo khoảng cách (ưu tiên cảnh báo khoảng
        // cách hơn, vì đó là vấn đề CẦN XỬ LÝ NGAY, còn thông báo mở đầu chỉ
        // mang tính thông tin).
        if (_showAnnouncement && !_showDistancePause)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showAnnouncement ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.testAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(announceIcon, size: 40, color: AppColors.testAccent),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          announceTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          announceSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_showDistancePause)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause_circle_filled_rounded, color: AppColors.error, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        strings.eyeTestPausedTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _liveDistanceCm == null
                            ? strings.eyeTestFaceNotDetected
                            : (_liveDistanceCm! < _kIdealMinCm ? strings.eyeTestTooClose : strings.eyeTestTooFar),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDistanceBadge(BuildContext context) {
    final ok = _liveDistanceCm != null && _liveDistanceCm! >= _kIdealMinCm && _liveDistanceCm! <= _kIdealMaxCm;
    final color = _liveDistanceCm == null ? AppColors.textMuted : (ok ? AppColors.success : AppColors.error);
    final label = _liveDistanceCm == null ? '—' : '${_liveDistanceCm!.round()}cm';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }


  Widget _buildTumblingE(BuildContext context, {required double size, required double opacity}) {
    // Chữ "E" mặc định mở về bên PHẢI -> xoay theo góc tương ứng từng hướng.
    final angle = switch (_currentDirection!) {
      _Direction.right => 0.0,
      _Direction.down => math.pi / 2,
      _Direction.left => math.pi,
      _Direction.up => -math.pi / 2,
    };
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 10)),
          ],
        ),
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: angle,
          child: Text(
            'E',
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              color: Colors.black.withValues(alpha: opacity),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionPad({required void Function(_Direction) onPick}) {
    Widget dirButton(_Direction d, IconData icon) {
      return SizedBox(
        width: 64,
        height: 64,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.testAccent.withValues(alpha: 0.12),
            foregroundColor: AppColors.testAccent,
            shape: const CircleBorder(),
          ),
          onPressed: () => onPick(d),
          child: Icon(icon, size: 28),
        ),
      );
    }

    return Center(
      child: Column(
        children: [
          dirButton(_Direction.up, Icons.arrow_upward_rounded),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              dirButton(_Direction.left, Icons.arrow_back_rounded),
              const SizedBox(width: 44),
              dirButton(_Direction.right, Icons.arrow_forward_rounded),
            ],
          ),
          const SizedBox(height: 10),
          dirButton(_Direction.down, Icons.arrow_downward_rounded),
        ],
      ),
    );
  }

  // ---------------- Kết quả ----------------
  Widget _buildResult(BuildContext context, AppStrings strings) {
    final percent = _overallPercent();
    final summary = percent >= 70
        ? strings.eyeTestGood
        : percent >= 40
            ? strings.eyeTestFair
            : strings.eyeTestNeedsCare;

    // So với lần đo gần nhất trước đó (nếu có) để hiện xu hướng tăng/giảm.
    int? previousPercent;
    if (_history.length >= 2) {
      previousPercent = _history[_history.length - 2]['overallPercent'] as int?;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.eyeTestResult, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.testAccent.withValues(alpha: 0.18),
                  Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.testAccent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      percent >= 70 ? Icons.check_circle_rounded : Icons.info_rounded,
                      color: percent >= 70 ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Text('$percent%', style: Theme.of(context).textTheme.headlineMedium),
                    if (previousPercent != null) ...[
                      const SizedBox(width: 10),
                      Icon(
                        percent >= previousPercent ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: percent >= previousPercent ? AppColors.success : AppColors.warning,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(summary, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  strings.eyeTestSummaryBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MiniResultCard(
                  icon: Icons.visibility_outlined,
                  label: strings.eyeTestRightEyeShort,
                  value: '${_rightEyeLevel ?? 0}/${_kAcuitySizes.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniResultCard(
                  icon: Icons.visibility_outlined,
                  label: strings.eyeTestLeftEyeShort,
                  value: '${_leftEyeLevel ?? 0}/${_kAcuitySizes.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniResultCard(
                  icon: Icons.contrast_rounded,
                  label: strings.eyeTestContrastShort,
                  value: '${_contrastLevel ?? 0}/${_kContrastLevels.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            strings.eyeTestDisclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _resetTest, child: Text(strings.eyeTestRetake)),
          ),
        ],
      ),
    );
  }
}

class _MiniResultCard extends StatelessWidget {
  const _MiniResultCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.testAccent),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

// Panel đo khoảng cách mắt-màn hình TRỰC TIẾP bằng camera trước — hiện ở
// màn giới thiệu (dạng panel to, có xin quyền). Camera do CHA (_EyeTestScreenState)
// khởi động lúc widget này chạy xong và DỪNG lúc rời khỏi toàn bộ màn kiểm
// tra (không dừng theo riêng widget này) để dùng xuyên suốt cả bài test.
class _LiveDistanceMeter extends StatefulWidget {
  const _LiveDistanceMeter({
    required this.idealMinCm,
    required this.idealMaxCm,
    required this.onDistanceChanged,
    required this.onActiveChanged,
  });

  final double idealMinCm;
  final double idealMaxCm;
  final void Function(double? cm) onDistanceChanged;
  final void Function(bool active) onActiveChanged;

  @override
  State<_LiveDistanceMeter> createState() => _LiveDistanceMeterState();
}

enum _MeterState { checkingPermission, needsPermission, unavailable, starting, running }

class _LiveDistanceMeterState extends State<_LiveDistanceMeter> {
  _MeterState _state = _MeterState.checkingPermission;
  double? _distanceCm;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    if (status.isGranted) {
      await _startCamera();
    } else {
      setState(() => _state = _MeterState.needsPermission);
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      await _startCamera();
    } else {
      // Từ chối quyền -> không ép, để người dùng vẫn làm bài test bình
      // thường như bản cũ (chỉ mất phần đo khoảng cách trực tiếp).
      setState(() => _state = _MeterState.unavailable);
    }
  }

  Future<void> _startCamera() async {
    setState(() => _state = _MeterState.starting);
    final hasCamera = await DistanceService.instance.isCameraAvailable();
    if (!mounted) return;
    if (!hasCamera) {
      setState(() => _state = _MeterState.unavailable);
      return;
    }
    final ok = await DistanceService.instance.start();
    if (!mounted) return;
    if (!ok) {
      setState(() => _state = _MeterState.unavailable);
      return;
    }
    setState(() => _state = _MeterState.running);
    widget.onActiveChanged(true);
    DistanceService.instance.distanceStream.listen((cm) {
      if (!mounted) return;
      setState(() => _distanceCm = cm);
      widget.onDistanceChanged(cm);
    });
  }

  @override
  void dispose() {
    // KHÔNG dừng camera ở đây nữa — bài test còn tiếp tục dùng camera này ở
    // các bước sau (đo mắt phải/trái/tương phản), _LiveDistanceMeter chỉ là
    // panel HIỂN THỊ + XIN QUYỀN ở màn giới thiệu, không phải chủ sở hữu
    // vòng đời camera. _EyeTestScreenState (cha) chịu trách nhiệm dừng hẳn
    // camera khi rời màn kiểm tra hoặc khi đã có kết quả.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    if (_state == _MeterState.unavailable) {
      // Xuống cấp nhẹ nhàng về đúng lời nhắc tĩnh của bản cũ — không camera
      // vẫn dùng được bài test, chỉ là không có đồng hồ đo trực tiếp.
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.testAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.testAccent.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.rule_rounded, color: AppColors.testAccent, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(strings.eyeTestDistanceHint, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );
    }

    if (_state == _MeterState.needsPermission) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.testAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.testAccent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt_outlined, color: AppColors.testAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(strings.eyeTestCameraPermissionHint, style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _requestPermission,
                child: Text(strings.eyeTestEnableCamera),
              ),
            ),
          ],
        ),
      );
    }

    if (_state == _MeterState.checkingPermission || _state == _MeterState.starting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // _state == running
    final ok = _distanceCm != null && _distanceCm! >= widget.idealMinCm && _distanceCm! <= widget.idealMaxCm;
    final color = _distanceCm == null ? AppColors.textMuted : (ok ? AppColors.success : AppColors.warning);
    final label = _distanceCm == null
        ? strings.eyeTestFaceNotDetected
        : '${_distanceCm!.round()} cm';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.straighten_rounded, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
                Text(
                  strings.eyeTestDistanceHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}