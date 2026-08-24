import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/usage_service.dart';


class PermissionHelper {
  // Kiểm tra quyền PACKAGE_USAGE_STATS
  static Future<bool> checkUsagePermission() async {
    return await UsageService.hasPermission();
  }

  // Kiểm tra quyền hiển thị overlay (SYSTEM_ALERT_WINDOW) — native
  // Settings.canDrawOverlays qua MethodChannel (permission_handler không
  // cover quyền này).
  static const MethodChannel _overlayChannel = MethodChannel('eye_care_ai/app_lock');

  static Future<bool> checkOverlayPermission() async {
    try {
      return await _overlayChannel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mở trang quyền overlay (Always on top) của hệ thống — người dùng tự bật,
  /// quay lại app → refreshStatus() cập nhật.
  ///
  /// KHÔNG dùng url_launcher 'package:' — trên ColorOS/Oppo resolver hay đưa
  /// về trang thông tin app thay vì trang quyền overlay, hoặc im lặng no-op.
  /// Gọi thẳng native Settings.ACTION_MANAGE_OVERLAY_PERMISSION qua kênh đã
  /// đăng ký trong MainActivity (giữ ý định chính xác, tránh browser fallback).
  static Future<void> openOverlaySettings() async {
    try {
      await _overlayChannel.invokeMethod<void>('openOverlaySettings');
    } catch (_) {
      // Bỏ qua nếu không mở được — người dùng vẫn có thể bỏ qua bước này.
    }
  }



  // Yêu cầu quyền PACKAGE_USAGE_STATS
  static Future<bool> requestUsagePermission() async {
    if (!Platform.isAndroid) return true;

    await UsageService.openPermissionSettings();

    // Đợi người dùng quay lại app
    await Future.delayed(const Duration(seconds: 1));

    return await UsageService.hasPermission();
  }

  // Mở Settings để cấp quyền thủ công
  static Future<void> openUsageAccessSettings() async {
  if (!Platform.isAndroid) return;

    await UsageService.openPermissionSettings();
  }

  // Kiểm tra quyền Location
  static Future<bool> checkLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  // Yêu cầu quyền Location
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  // Kiểm tra quyền Activity Recognition
  static Future<bool> checkActivityPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.status;
      return status.isGranted;
    }
    return true;
  }

  // Yêu cầu quyền Activity Recognition
  static Future<bool> requestActivityPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      return status.isGranted;
    }
    return true;
  }

  // Kiểm tra tất cả quyền cần thiết
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'usage': await checkUsagePermission(),
      'location': await checkLocationPermission(),
      'activity': await checkActivityPermission(),
    };
  }

  // Hiển thị dialog hướng dẫn cấp quyền
  static Future<void> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onGrant,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onGrant();
            },
            child: const Text('Cấp quyền'),
          ),
        ],
      ),
    );
  }
}