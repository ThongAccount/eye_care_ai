import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../models/eye_health_standards.dart';
import '../providers/auth_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/setup_provider.dart';
import '../providers/auto_break_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'setup_wizard_screen.dart';

// HabitsSurveyScreen: khảo sát từng câu một (giống dạng wizard/onboarding),
// so sánh câu trả lời với thông số tiêu chuẩn, và cho phép áp dụng ngay các
// target được gợi ý vào trang Habits.
//
// mandatory = true: dùng khi mở app lần đầu — không cho bỏ qua/back ra ngoài,
// sau khi áp dụng sẽ vào thẳng MainShell thay vì quay lại màn trước.
class HabitsSurveyScreen extends StatefulWidget {
  const HabitsSurveyScreen({super.key, this.mandatory = false});

  final bool mandatory;

  @override
  State<HabitsSurveyScreen> createState() => _HabitsSurveyScreenState();
}

class _HabitsSurveyScreenState extends State<HabitsSurveyScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;

  AgeGroup _ageGroup = AgeGroup.adult;
  double _screenHours = 4;
  double _outdoorMinutes = 30;
  double _readingDistance = 30;
  double _sleepHours = 7;
  double _breaksPerDay = 4;

  SurveyResult? _result;
  bool _showSummary = true;
  int _targetStepIndex = 0;
  bool _showCustomTargetError = false;
  final Map<String, TargetLevel> _selectedTargetLevels = {};
  final Map<String, double> _selectedTargetValues = {};
  final Map<String, double> _customTargetValues = {};
  final Map<String, TextEditingController> _customTargetControllers = {};

  static const _totalQuestions = 6;

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _customTargetControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _goNext() {
    if (_result == null) {
      if (_pageIndex < _totalQuestions - 1) {
        setState(() => _pageIndex++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _submit();
      }
      return;
    }

    if (_targetStepIndex < _surveyTargetHabitIds.length - 1) {
      setState(() => _targetStepIndex++);
    }
  }

  void _goBack() {
    if (_pageIndex == 0) return;
    setState(() => _pageIndex--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  static const _surveyTargetHabitIds = ['phone', 'outdoor', 'sleep', 'breaks'];

  void _submit() {
    final vi = context.read<LanguageProvider>().strings.vi;
    final answers = SurveyAnswers(
      ageGroup: _ageGroup,
      screenHoursPerDay: _screenHours,
      outdoorMinutesPerDay: _outdoorMinutes,
      readingDistanceCm: _readingDistance,
      sleepHoursPerNight: _sleepHours,
      breaksPerDay: _breaksPerDay,
    );
    final result = evaluateSurvey(answers, vi);
    setState(() {
      _result = result;
      _showSummary = true;
      _targetStepIndex = 0;
      _showCustomTargetError = false;
      _selectedTargetLevels.clear();
      _selectedTargetValues.clear();
      _customTargetValues.clear();
      _customTargetControllers.clear();
      for (final id in _surveyTargetHabitIds) {
        final row = result.rows.firstWhere((row) => row.id == id);
        // Nếu người dùng đã đạt chuẩn cho habit này -> mặc định chọn "Giữ
        // nguyên" (dùng chính giá trị hiện tại làm target mới) thay vì ép
        // họ lên mức "Khuyến nghị" như trước đây (gây cảm giác dù đã tốt
        // vẫn bị yêu cầu cố gắng thêm).
        if (row.isGood) {
          _selectedTargetLevels[id] = TargetLevel.keep;
          _selectedTargetValues[id] = row.currentValue;
        } else {
          _selectedTargetLevels[id] = TargetLevel.recommended;
          _selectedTargetValues[id] = row.recommendedValue;
        }
      }
    });
  }

  void _retake() {
    setState(() {
      _result = null;
      _showSummary = true;
      _pageIndex = 0;
      _targetStepIndex = 0;
      _showCustomTargetError = false;
      _selectedTargetLevels.clear();
      _selectedTargetValues.clear();
      _customTargetValues.clear();
      for (final controller in _customTargetControllers.values) {
        controller.dispose();
      }
      _customTargetControllers.clear();
    });
    _pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final strings = language.strings;

    return PopScope(
      canPop: !widget.mandatory || _result != null,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.mandatory,
          title: Text(
            _result == null
                ? strings.surveyTitle
                : (_showSummary ? strings.surveyResultsTitle : strings.targetSelectionTitle),
          ),
          actions: [
            // Cho phép đổi ngôn ngữ ngay trong khảo sát bắt buộc lần đầu —
            // lúc này người dùng chưa vào được trang Settings. (Nút đổi
            // sáng/tối đã BỎ cùng với việc bỏ tính năng Chế độ tối.)
            TextButton(
              onPressed: () => language.toggleVietnamese(!language.isVietnamese),
              child: Text(
                strings.vi ? 'EN' : 'VI',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: _result == null
              ? _buildWizard(context, strings)
              : (_showSummary ? _buildSummary(context, strings) : _buildResults(context, strings)),
        ),
      ),
    );
  }

  Widget _buildWizard(BuildContext context, AppStrings strings) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.stepCount(_pageIndex + 1, _totalQuestions),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_pageIndex + 1) / _totalQuestions,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.habitsAccent),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuestionPage(
                icon: Icons.cake_outlined,
                question: strings.surveyAgeQuestion,
                helper: strings.surveyAgeHelper,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AgeGroup.values.map((group) {
                    final selected = _ageGroup == group;
                    return ChoiceChip(
                      label: Text(EyeHealthStandards.ageGroupLabel(group, strings.vi)),
                      selected: selected,
                      onSelected: (_) => setState(() => _ageGroup = group),
                      selectedColor: AppColors.habitsAccent.withValues(alpha: 0.15),
                      // BUG ĐÃ SỬA: ChoiceChip mặc định hiện dấu ✓ khi được
                      // chọn (showCheckmark: true) — dấu tích này CHÈN THÊM
                      // vào layout đột ngột, cộng với fontWeight đổi từ 500
                      // lên 700 (chữ đậm rộng hơn chữ thường) khiến CẢ CHIP
                      // đổi kích thước 2 LẦN CÙNG LÚC trong 1 khung hình ->
                      // cảm giác "giật cục". Tắt checkmark + giữ NGUYÊN 1
                      // độ đậm chữ cho cả 2 trạng thái (chỉ đổi màu) để chip
                      // không bao giờ đổi kích thước khi chọn/bỏ chọn nữa.
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.habitsAccent : null,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ),
              _QuestionPage(
                icon: Icons.smartphone_outlined,
                question: strings.surveyScreenQuestion,
                helper: strings.surveyScreenHelper,
                child: _StepperInput(
                  value: _screenHours,
                  min: 0,
                  max: 16,
                  step: 0.5,
                  unit: strings.vi ? 'giờ' : 'hrs',
                  onChanged: (v) => setState(() => _screenHours = v),
                  presets: const [2, 4, 6, 8, 10],
                ),
              ),
              _QuestionPage(
                icon: Icons.park_outlined,
                question: strings.surveyOutdoorQuestion,
                helper: strings.surveyOutdoorHelper,
                child: _StepperInput(
                  value: _outdoorMinutes,
                  min: 0,
                  max: 240,
                  step: 10,
                  unit: strings.vi ? 'phút' : 'min',
                  onChanged: (v) => setState(() => _outdoorMinutes = v),
                  presets: const [15, 30, 60, 90, 120],
                ),
              ),
              _QuestionPage(
                icon: Icons.straighten_rounded,
                question: strings.surveyDistanceQuestion,
                helper: strings.surveyDistanceHelper,
                child: _StepperInput(
                  value: _readingDistance,
                  min: 10,
                  max: 80,
                  step: 1,
                  unit: 'cm',
                  onChanged: (v) => setState(() => _readingDistance = v),
                  presets: const [20, 30, 40, 50],
                ),
              ),
              _QuestionPage(
                icon: Icons.bedtime_outlined,
                question: strings.surveySleepQuestion,
                helper: strings.surveySleepHelper,
                child: _StepperInput(
                  value: _sleepHours,
                  min: 3,
                  max: 12,
                  step: 0.5,
                  unit: strings.vi ? 'giờ' : 'hrs',
                  onChanged: (v) => setState(() => _sleepHours = v),
                  presets: const [6, 7, 8, 9],
                ),
              ),
              _QuestionPage(
                icon: Icons.remove_red_eye_outlined,
                question: strings.surveyBreaksQuestion,
                helper: strings.surveyBreaksHelper,
                child: _StepperInput(
                  value: _breaksPerDay,
                  min: 0,
                  max: 20,
                  step: 1,
                  unit: strings.vi ? 'lần' : 'times',
                  onChanged: (v) => setState(() => _breaksPerDay = v),
                  presets: const [2, 4, 6, 8],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              if (_pageIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _goBack,
                    child: Text(strings.vi ? 'Quay lại' : 'Back'),
                  ),
                ),
              if (_pageIndex > 0) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.habitsAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _goNext,
                  child: Text(
                    _pageIndex == _totalQuestions - 1
                        ? strings.surveySubmit
                        : (strings.vi ? 'Tiếp tục' : 'Next'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Màn hình tóm tắt kết quả khảo sát: liệt kê TẤT CẢ chỉ số (kể cả
  // reading_distance không có target trên trang Habits) với trạng thái
  // Đạt chuẩn / Cần cải thiện, để người dùng thấy ngay mình đang yếu ở đâu
  // trước khi bước vào wizard chọn mục tiêu.
  Widget _buildSummary(BuildContext context, AppStrings strings) {
    final result = _result!;
    final settings = context.watch<SettingsProvider>();
    final needsWorkCount = result.rows.where((r) => !r.isGood).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.surveyResultsTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(strings.surveyResultsSubtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            needsWorkCount == 0
                ? (strings.vi ? '🎉 Tất cả chỉ số đều đạt chuẩn!' : '🎉 Every metric is on track!')
                : (strings.vi
                    ? '⚠️ $needsWorkCount/${result.rows.length} chỉ số cần cải thiện'
                    : '⚠️ $needsWorkCount of ${result.rows.length} metrics need work'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: needsWorkCount == 0 ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          ...result.rows.map((row) {
            final title = row.id == 'reading_distance'
                ? strings.surveyDistanceQuestion
                : _habitTitle(row.id, strings);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (row.isGood ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        row.isGood ? Icons.check_rounded : Icons.priority_high_rounded,
                        color: row.isGood ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title, style: Theme.of(context).textTheme.titleSmall),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (row.isGood ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  row.isGood ? strings.surveyGoodStatus : strings.surveyNeedsWorkStatus,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: row.isGood ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${strings.surveyCurrentLabel}: ${_formatTargetValue(row.currentValue, row.unit, settings.useMetric)} ${_unitLabel(row.unit, settings.useMetric, strings)}'
                            '  •  ${strings.surveyTargetLabel}: ${row.recommendedLabel}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(row.tip, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            strings.surveyDisclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.habitsAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => setState(() => _showSummary = false),
              child: Text(strings.surveySummaryContinue),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _retake,
              child: Text(strings.surveyRetake),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, AppStrings strings) {
    final result = _result!;
    final settings = context.watch<SettingsProvider>();
    final currentHabitId = _surveyTargetHabitIds[_targetStepIndex];
    final currentRow = result.rows.firstWhere((row) => row.id == currentHabitId);
    final selectedLevel = _selectedTargetLevels[currentHabitId] ?? TargetLevel.recommended;
    final currentTargetValue = _selectedTargetValues[currentHabitId] ?? currentRow.recommendedValue;
    final customController = _customTargetControllers.putIfAbsent(
      currentHabitId,
      () => TextEditingController(text: _selectedTargetValues[currentHabitId]?.toStringAsFixed(1) ?? ''),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.targetSelectionTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(strings.targetSummarySubtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_habitTitle(currentHabitId, strings), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '${strings.targetCurrentLabel}: ${_formatTargetValue(currentRow.currentValue, currentRow.unit, settings.useMetric)} ${_unitLabel(currentRow.unit, settings.useMetric, strings)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${strings.targetRecommendedLabel}: ${_formatTargetValue(currentRow.recommendedValue, currentRow.unit, settings.useMetric)} ${_unitLabel(currentRow.unit, settings.useMetric, strings)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                if (currentRow.isGood) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.emoji_events_rounded, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            strings.targetAlreadyMetBanner,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TargetChoiceCard(
                    title: strings.targetOptionKeepCurrent,
                    description: strings.vi
                        ? 'Giữ mức bạn đang làm tốt, không thay đổi.'
                        : "Keep the level you're already doing well at.",
                    selected: selectedLevel == TargetLevel.keep,
                    onTap: () {
                      setState(() {
                        _selectedTargetLevels[currentHabitId] = TargetLevel.keep;
                        _selectedTargetValues[currentHabitId] = currentRow.currentValue;
                        _showCustomTargetError = false;
                      });
                    },
                    value: _formatTargetValue(currentRow.currentValue, currentRow.unit, settings.useMetric),
                    unit: _unitLabel(currentRow.unit, settings.useMetric, strings),
                  ),
                  const SizedBox(height: 12),
                ],
                _TargetChoiceCard(
                  title: strings.targetOptionEasy,
                  description: strings.vi
                      ? 'Nội dung dễ đạt hơn, gần với giá trị hiện tại.'
                      : 'Easier than recommended, closer to your current value.',
                  selected: selectedLevel == TargetLevel.easy,
                  onTap: () {
                    setState(() {
                      _selectedTargetLevels[currentHabitId] = TargetLevel.easy;
                      _selectedTargetValues[currentHabitId] = EyeHealthStandards.calculateTargetValue(
                        currentRow.currentValue,
                        currentRow.recommendedValue,
                        TargetLevel.easy,
                      );
                      _showCustomTargetError = false;
                    });
                  },
                  value: _formatTargetValue(
                    EyeHealthStandards.calculateTargetValue(
                      currentRow.currentValue,
                      currentRow.recommendedValue,
                      TargetLevel.easy,
                    ),
                    currentRow.unit,
                    settings.useMetric,
                  ),
                  unit: _unitLabel(currentRow.unit, settings.useMetric, strings),
                ),
                const SizedBox(height: 12),
                _TargetChoiceCard(
                  title: strings.targetOptionRecommended,
                  description: strings.vi
                      ? 'Mục tiêu chuyển tiếp vừa phải, dễ thực hiện hơn.'
                      : 'A transition target that is easier than ideal but still better.',
                  selected: selectedLevel == TargetLevel.recommended,
                  onTap: () {
                    setState(() {
                      _selectedTargetLevels[currentHabitId] = TargetLevel.recommended;
                      _selectedTargetValues[currentHabitId] = EyeHealthStandards.calculateTargetValue(
                        currentRow.currentValue,
                        currentRow.recommendedValue,
                        TargetLevel.recommended,
                      );
                      _showCustomTargetError = false;
                    });
                  },
                  value: _formatTargetValue(
                    EyeHealthStandards.calculateTargetValue(
                      currentRow.currentValue,
                      currentRow.recommendedValue,
                      TargetLevel.recommended,
                    ),
                    currentRow.unit,
                    settings.useMetric,
                  ),
                  unit: _unitLabel(currentRow.unit, settings.useMetric, strings),
                ),
                const SizedBox(height: 12),
                _TargetChoiceCard(
                  title: strings.targetOptionChallenge,
                  description: strings.vi
                      ? 'Thử thách hơn, gần với mức khuyến nghị chuẩn.'
                      : 'More ambitious, closer to the recommended goal.',
                  selected: selectedLevel == TargetLevel.challenge,
                  onTap: () {
                    setState(() {
                      _selectedTargetLevels[currentHabitId] = TargetLevel.challenge;
                      _selectedTargetValues[currentHabitId] = EyeHealthStandards.calculateTargetValue(
                        currentRow.currentValue,
                        currentRow.recommendedValue,
                        TargetLevel.challenge,
                      );
                      _showCustomTargetError = false;
                    });
                  },
                  value: _formatTargetValue(
                    EyeHealthStandards.calculateTargetValue(
                      currentRow.currentValue,
                      currentRow.recommendedValue,
                      TargetLevel.challenge,
                    ),
                    currentRow.unit,
                    settings.useMetric,
                  ),
                  unit: _unitLabel(currentRow.unit, settings.useMetric, strings),
                ),
                const SizedBox(height: 12),
                _TargetChoiceCard(
                  title: strings.targetOptionCustom,
                  description: strings.vi
                      ? 'Nhập giá trị theo ý bạn trong khoảng hợp lý.'
                      : 'Enter a custom target within a valid range.',
                  selected: selectedLevel == TargetLevel.custom,
                  onTap: () {
                    setState(() {
                      _selectedTargetLevels[currentHabitId] = TargetLevel.custom;
                      _showCustomTargetError = false;
                    });
                  },
                  value: _formatTargetValue(currentTargetValue, currentRow.unit, settings.useMetric),
                  unit: _unitLabel(currentRow.unit, settings.useMetric, strings),
                ),
                if (selectedLevel == TargetLevel.custom) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: strings.targetCustomHint,
                      errorText: _showCustomTargetError ? strings.targetCustomError : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      final value = double.tryParse(text);
                      if (value != null) {
                        _customTargetValues[currentHabitId] = value;
                        _selectedTargetValues[currentHabitId] = value;
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_targetStepIndex < _surveyTargetHabitIds.length - 1)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (_targetStepIndex > 0) {
                        setState(() => _targetStepIndex--);
                      } else {
                        setState(() => _showSummary = true);
                      }
                    },
                    child: Text(strings.targetBack),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.habitsAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (selectedLevel == TargetLevel.custom) {
                        final value = double.tryParse(customController.text);
                        if (value == null ||
                            !EyeHealthStandards.inCustomRange(
                              value,
                              currentRow.currentValue,
                              currentRow.recommendedValue,
                              currentRow.isDecrease,
                            )) {
                          setState(() => _showCustomTargetError = true);
                          return;
                        }
                      }
                      _goNext();
                    },
                    child: Text(strings.targetNext),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._surveyTargetHabitIds.map((id) {
                  final row = result.rows.firstWhere((row) => row.id == id);
                  final value = _selectedTargetValues[id] ?? row.recommendedValue;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_habitTitle(id, strings), style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Text(
                            '${strings.targetYourPlan}: ${_formatTargetValue(value, row.unit, settings.useMetric)} ${_unitLabel(row.unit, settings.useMetric, strings)}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${strings.targetOptionRecommended}: ${_formatTargetValue(row.recommendedValue, row.unit, settings.useMetric)} ${_unitLabel(row.unit, settings.useMetric, strings)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.habitsAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final habitProvider = context.read<HabitProvider>();
                    await habitProvider.applySurveyTargets(
                      {
                        for (final id in _surveyTargetHabitIds)
                          if (_selectedTargetValues[id] != null) id: _selectedTargetValues[id]!,
                      },
                      surveyAnswers: {
                        'ageGroup': _ageGroup.name,
                        'screenHoursPerDay': _screenHours,
                        'outdoorMinutesPerDay': _outdoorMinutes,
                        'readingDistanceCm': _readingDistance,
                        'sleepHoursPerNight': _sleepHours,
                        'breaksPerDay': _breaksPerDay,
                      },
                    );
                    await habitProvider.markSurveyCompleted();
                    // Đồng bộ ngay khoảng đếm ngược "Tự động nhắc nghỉ mắt" theo mục tiêu mới.
                    if (context.mounted) {
                      context.read<AutoBreakProvider>().recomputeInterval(
                            habitProvider.habits.firstWhere((h) => h.id == 'breaks').target,
                          );
                    }
                    if (!context.mounted) return;
                    if (widget.mandatory) {
                      // Sau khảo sát bắt buộc: nếu đã đăng nhập thì vào thẳng
                      // MainShell (hoặc Setup Wizard nếu chưa hoàn tất) — còn
                      // chưa đăng nhập thì phải qua màn Đăng nhập trước (đúng
                      // như luồng _AppGate mô tả), thay vì luôn nhảy thẳng vào
                      // MainShell bất kể trạng thái đăng nhập/thiết lập.
                      final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
                      final setup = context.read<SetupProvider>();
                      Widget next;
                      if (!isLoggedIn) {
                        next = const LoginScreen();
                      } else if (!setup.wizardCompleted) {
                        next = const SetupWizardScreen();
                      } else {
                        next = const MainShell();
                      }
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => next),
                      );
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(strings.targetApplyButton),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _retake,
                    child: Text(strings.surveyRetake),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.question,
    required this.child,
    this.icon,
    this.helper,
  });

  final String question;
  final Widget child;
  // Icon minh hoạ + câu giải thích ngắn "vì sao câu hỏi này quan trọng" —
  // thêm để khảo sát dễ hiểu hơn, trước đây chỉ có mỗi câu hỏi trần trụi,
  // người dùng không biết ước lượng thế nào/vì sao app hỏi điều này.
  final IconData? icon;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.habitsAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.habitsAccent, size: 26),
            ),
            const SizedBox(height: 16),
          ],
          Text(question, style: Theme.of(context).textTheme.headlineSmall),
          if (helper != null) ...[
            const SizedBox(height: 8),
            Text(
              helper!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ],
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

// _StepperInput: nút +/- để chỉnh chính xác từng nấc, kèm THANH TRƯỢT để
// nhảy nhanh tới vùng giá trị mong muốn (trước đây CHỈ có +/-, với khoảng
// giá trị rộng như 0-240 phút bước 10 phải bấm tới 24 lần mới tới đầu kia —
// rất chậm và dễ nản). Có thêm dãy CHIP GIÁ TRỊ THƯỜNG GẶP bên dưới để bấm
// 1 lần ra ngay giá trị phổ biến, không cần kéo/bấm gì thêm.
class _StepperInput extends StatelessWidget {
  const _StepperInput({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
    this.presets = const [],
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final ValueChanged<double> onChanged;
  // Vài giá trị phổ biến để bấm nhanh (VD: 2, 4, 6, 8 giờ) — rỗng thì không
  // hiện dãy chip này.
  final List<double> presets;

  String _formatValue(double v) => v % 1 == 0 ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final divisions = ((max - min) / step).round().clamp(1, 1000);
    return Column(
      children: [
        SectionCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundIconButton(
                    icon: Icons.remove_rounded,
                    onTap: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
                  ),
                  Column(
                    children: [
                      Text(
                        _formatValue(value),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: AppColors.habitsAccent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(unit, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  _RoundIconButton(
                    icon: Icons.add_rounded,
                    onTap: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.habitsAccent,
                  thumbColor: AppColors.habitsAccent,
                  overlayColor: AppColors.habitsAccent.withValues(alpha: 0.15),
                  inactiveTrackColor: AppColors.border,
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: '${_formatValue(value)} $unit',
                  onChanged: (v) => onChanged(v),
                ),
              ),
            ],
          ),
        ),
        if (presets.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: presets.map((p) {
              final selected = (value - p).abs() < 0.001;
              return ChoiceChip(
                label: Text('${_formatValue(p)} $unit'),
                selected: selected,
                onSelected: (_) => onChanged(p),
                selectedColor: AppColors.habitsAccent.withValues(alpha: 0.15),
                // Xem giải thích chi tiết ở chip nhóm tuổi phía trên (cùng
                // file) — tắt checkmark + giữ cố định độ đậm chữ để chip
                // KHÔNG đổi kích thước khi chọn, tránh cảm giác giật/lag.
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: selected ? AppColors.habitsAccent : null,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.habitsAccent.withValues(alpha: 0.12) : AppColors.border,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: enabled ? AppColors.habitsAccent : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _TargetChoiceCard extends StatelessWidget {
  const _TargetChoiceCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    required this.value,
    required this.unit,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? AppColors.habitsAccent.withValues(alpha: 0.12) : null,
          border: Border.all(
            color: selected ? AppColors.habitsAccent : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$value $unit',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.habitsAccent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _habitTitle(String id, AppStrings strings) {
  switch (id) {
    case 'phone':
      return strings.habitTitle('phone');
    case 'outdoor':
      return strings.habitTitle('outdoor');
    case 'sleep':
      return strings.habitTitle('sleep');
    case 'breaks':
      return strings.habitTitle('breaks');
    default:
      return strings.habitTitle(id);
  }
}

String _formatTargetValue(double value, String unit, bool useMetric) {
  final formatted = value % 1 == 0 ? value.round().toString() : value.toStringAsFixed(1);
  return formatted;
}

String _unitLabel(String unit, bool useMetric, AppStrings strings) {
  if (unit == 'cm' && !useMetric) {
    return strings.inchUnit;
  }
  return strings.habitUnit(unit);
}

double valueToInches(double cm) => cm / 2.54;