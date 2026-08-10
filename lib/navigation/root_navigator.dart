import 'package:flutter/material.dart';

/// Navigator toàn cục của app — dùng chung cho thông báo nghỉ mắt
/// (main.dart) và AppUsageMonitor (app-lock) để push overlay/route lên đúng
/// navigator gốc mà không cần BuildContext của màn hình bất kỳ.
///
/// Ký tự `_` không được dùng vì file này là nơi EXPORT cho các file khác
/// (main.dart trước đây giữ key riêng — giờ dùng chung key này).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();