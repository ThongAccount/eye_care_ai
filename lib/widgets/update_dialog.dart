import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../models/app_strings.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_icon.dart';

/// Dialog "Có bản cập nhật mới" — hiện khi UpdateService.checkForUpdate()
/// tìm thấy 1 bản build mới hơn trên GitHub Releases. Bấm "Cập nhật ngay"
/// sẽ tải file .apk kèm progress bar ngay trong dialog, xong tự mở trình
/// cài đặt gói của hệ thống (OpenFilex) — người dùng chỉ cần bấm "Cài đặt"
/// ở màn hình hệ thống hiện ra sau đó, không cần vào Google Play.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.update, required this.strings, this.onDismissed});

  final UpdateInfo update;
  final AppStrings strings;
  // Gọi khi dialog đóng mà CHƯA hoàn tất cài đặt (bấm "Để sau", chạm ra
  // ngoài, hoặc back) — dùng để ghi nhớ "đã dismiss bản này", đỡ hiện lại
  // dialog ở lần mở app kế tiếp cho cùng 1 bản build (xem UpdateProvider).
  // Không gọi nếu người dùng đã mở trình cài đặt hệ thống thành công, vì
  // lúc đó coi như họ đang xử lý bản cập nhật rồi, không cần "nhắc nhẹ" nữa.
  final VoidCallback? onDismissed;

  /// Tiện ích gọi nhanh từ nơi khác: `UpdateDialog.show(context, update, strings)`.
  static Future<void> show(
    BuildContext context,
    UpdateInfo update,
    AppStrings strings, {
    VoidCallback? onDismissed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => UpdateDialog(update: update, strings: strings, onDismissed: onDismissed),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _DownloadState { idle, downloading, failed, done }

class _UpdateDialogState extends State<UpdateDialog> {
  _DownloadState _state = _DownloadState.idle;
  double _progress = 0;
  String? _downloadedPath;
  bool _dismissedCallbackFired = false;

  // Gọi onDismissed ĐÚNG 1 LẦN — dùng chung cho mọi đường đóng dialog mà
  // chưa cài xong (nút "Để sau", chạm ra ngoài, back cứng).
  void _fireDismissedOnce() {
    if (_dismissedCallbackFired) return;
    _dismissedCallbackFired = true;
    widget.onDismissed?.call();
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = _DownloadState.downloading;
      _progress = 0;
    });
    try {
      final file = await UpdateService.instance.downloadApk(
        widget.update,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = received / total);
        },
      );
      if (!mounted) return;
      setState(() {
        _state = _DownloadState.done;
        _downloadedPath = file.path;
      });
      // Mở ngay trình cài đặt hệ thống — không cần người dùng tự đi tìm file
      // .apk vừa tải trong File Manager.
      await OpenFilex.open(file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _DownloadState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final update = widget.update;

    return PopScope(
      canPop: true,
      // Bắt được TẤT CẢ đường đóng dialog: nút "Để sau" (Navigator.pop bên
      // dưới), chạm ra ngoài (barrierDismissible), và nút back cứng của
      // Android — cả 3 đều trigger pop route này, chỉ cần xử lý 1 chỗ.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _fireDismissedOnce();
      },
      child: AlertDialog(
      title: Row(
        children: [
          const AppIcon('🚀', size: 22, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(child: Text(strings.updateAvailableTitle)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.updateAvailableSubtitle(update.versionName),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (update.releaseNotes.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(strings.updateNotesTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Text(
                    update.releaseNotes.trim(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
            if (_state == _DownloadState.downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 8),
              Text(
                '${strings.updateDownloading} ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_state == _DownloadState.failed) ...[
              const SizedBox(height: 12),
              Text(
                strings.updateDownloadFailed,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_state != _DownloadState.downloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.updateLater),
          ),
        if (_state == _DownloadState.idle || _state == _DownloadState.failed)
          FilledButton(
            onPressed: _startDownload,
            child: Text(strings.updateNow),
          ),
        if (_state == _DownloadState.done)
          FilledButton(
            onPressed: _downloadedPath == null ? null : () => OpenFilex.open(_downloadedPath!),
            child: Text(strings.updateOpenInstaller),
          ),
      ],
      ),
    );
  }
}