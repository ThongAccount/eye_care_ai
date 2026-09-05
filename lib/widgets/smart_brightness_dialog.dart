import 'package:flutter/material.dart';

import '../models/app_strings.dart';
import '../services/brightness_service.dart';
import '../theme/app_colors.dart';

/// Dialog "Gợi ý độ sáng" — đọc cảm biến ánh sáng môi trường (lux) + độ sáng
/// màn hình hiện tại, tính ra 1 mức độ sáng đề xuất khớp môi trường, và có
/// nút để TỰ ĐỘNG áp dụng luôn thay vì chỉ hiện tip suông như trước.
class SmartBrightnessDialog extends StatefulWidget {
  const SmartBrightnessDialog({super.key, required this.strings});

  final AppStrings strings;

  static Future<void> show(BuildContext context, AppStrings strings) {
    return showDialog<void>(
      context: context,
      builder: (_) => SmartBrightnessDialog(strings: strings),
    );
  }

  @override
  State<SmartBrightnessDialog> createState() => _SmartBrightnessDialogState();
}

class _SmartBrightnessDialogState extends State<SmartBrightnessDialog> {
  bool _loading = true;
  int? _lux;
  double? _currentBrightness;
  double? _suggestedBrightness;
  bool _applying = false;
  bool? _appliedSuccess;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = BrightnessService.instance;
    final results = await Future.wait([
      service.readAmbientLux(),
      service.getCurrentSystemBrightness(),
    ]);
    if (!mounted) return;
    final lux = results[0] as int?;
    setState(() {
      _lux = lux;
      _currentBrightness = results[1] as double?;
      _suggestedBrightness = lux == null ? null : service.suggestBrightnessForLux(lux);
      _loading = false;
    });
  }

  Future<void> _applySuggestion() async {
    final target = _suggestedBrightness;
    if (target == null) return;
    setState(() => _applying = true);

    final service = BrightnessService.instance;
    final canChange = await service.canChangeSystemBrightness();
    if (!canChange) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _appliedSuccess = false;
      });
      return;
    }

    final ok = await service.applySystemBrightness(target);
    if (!mounted) return;
    setState(() {
      _applying = false;
      _appliedSuccess = ok;
      if (ok) _currentBrightness = target;
    });
  }

  Future<void> _grantPermission() async {
    await BrightnessService.instance.openSystemSettings();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;

    return AlertDialog(
      title: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Text(strings.brightnessTips)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lux == null)
                    Text(
                      strings.brightnessSensorUnavailable,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                    )
                  else ...[
                    _ReadingRow(
                      label: strings.brightnessReadingAmbient,
                      value: strings.brightnessLuxDescription(_lux!),
                    ),
                    const SizedBox(height: 8),
                    _ReadingRow(
                      label: strings.brightnessReadingCurrent,
                      value: _currentBrightness == null
                          ? '—'
                          : '${(_currentBrightness! * 100).round()}%',
                    ),
                    const SizedBox(height: 8),
                    _ReadingRow(
                      label: strings.brightnessReadingSuggested,
                      value: '${(_suggestedBrightness! * 100).round()}%',
                      highlight: true,
                    ),
                  ],
                  if (_appliedSuccess == true) ...[
                    const SizedBox(height: 14),
                    Text(
                      strings.brightnessApplied,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.success),
                    ),
                  ],
                  if (_appliedSuccess == false) ...[
                    const SizedBox(height: 14),
                    Text(
                      strings.brightnessPermissionNeeded,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _grantPermission,
                      child: Text(strings.brightnessGrantPermission),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.vi ? 'Đóng' : 'Close'),
        ),
        if (_lux != null)
          FilledButton(
            onPressed: _applying ? null : _applySuggestion,
            child: _applying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(strings.brightnessApplyButton),
          ),
      ],
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // BUG ĐÃ SỬA: bản cũ dùng Row + Expanded(label) + Text(value) không giới
    // hạn chiều rộng. Khi value dài (ví dụ "135 lux · Trong nhà, bình
    // thường"), nó chiếm gần hết bề ngang dialog vì không hề bị ép co lại,
    // đẩy Expanded(label) xuống còn vài pixel -> Flutter buộc phải wrap
    // TỪNG KÝ TỰ MỘT xuống dòng (mỗi ký tự 1 dòng) vì không đủ chỗ cho cả 1
    // từ. Đổi sang xếp dọc (nhãn nhỏ ở trên, giá trị to hơn ở dưới) — không
    // còn 2 bên phải giành chỗ ngang của nhau nữa, hoạt động đúng với MỌI độ
    // dài label/value mà không cần đoán trước độ dài tối đa.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: highlight ? primary : null,
              ),
        ),
      ],
    );
  }
}