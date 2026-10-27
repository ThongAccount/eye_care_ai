import 'package:flutter/foundation.dart';

/// Một chỗ duy nhất để hỏi "nền tảng này có đủ phần native Android của app
/// không" — tức là các kênh `eye_care/usage`, `eye_care_ai/focus_mode`,
/// `eye_care_ai/app_lock`, cảm biến ánh sáng và các intent hệ thống riêng của
/// Android. iOS KHÔNG có bất kỳ handler nào cho các kênh đó (ios/Runner chỉ có
/// AppDelegate.swift + SceneDelegate.swift, không đăng ký MethodChannel nào),
/// nên mọi lời gọi từ Dart sẽ ném lỗi hoặc trả null.
///
/// LƯU Ý: cố tình dùng `defaultTargetPlatform` (flutter/foundation) chứ KHÔNG
/// dùng `Platform.isAndroid` (dart:io) — test ép được nền tảng bằng
/// `debugDefaultTargetPlatformOverride`, nên hành vi "trên iOS" được kiểm
/// chứng trong CI mà không cần máy Mac hay bản build iOS. iOS chưa phát hành,
/// đây là cách duy nhất kiểm thử khả thi cho tới khi có thiết bị/Mac thật.
bool hasAndroidNativeFeatures([TargetPlatform? platform]) =>
    (platform ?? defaultTargetPlatform) == TargetPlatform.android;
