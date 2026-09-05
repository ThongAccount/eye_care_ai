import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/update_service.dart';

/// Theo dõi trạng thái "có bản cập nhật đang chờ hay không" để hiển thị 1
/// chấm đỏ nhỏ (badge) trên icon Settings ở Trang chủ — dùng khi người dùng
/// đã bấm "Để sau"/đóng UpdateDialog: KHÔNG hiện lại dialog ở lần mở app kế
/// tiếp cho cùng 1 bản build đó nữa (đỡ phiền), nhưng vẫn cần 1 dấu hiệu nhẹ
/// nhàng nhắc là vẫn còn bản mới chưa cài, chứ không im lặng biến mất hẳn.
class UpdateProvider extends ChangeNotifier {
  static const _kDismissedBuildKey = 'pref_update_dismissed_build';

  UpdateInfo? _availableUpdate;
  int? _dismissedBuild;

  /// true khi có bản mới hơn máy đang chạy — dùng để hiện badge, KHÔNG phân
  /// biệt đã dismiss hay chưa (dismiss chỉ tắt dialog, không tắt badge).
  bool get hasUpdateAvailable => _availableUpdate != null;

  /// true khi có bản mới VÀ người dùng CHƯA dismiss bản này -> nên hiện
  /// dialog. Nếu đã dismiss đúng build này rồi thì false (chỉ còn badge).
  bool get shouldShowDialog =>
      _availableUpdate != null && _availableUpdate!.buildNumber != _dismissedBuild;

  UpdateInfo? get availableUpdate => _availableUpdate;

  /// Gọi mỗi lần MainShell kiểm tra cập nhật xong (dù tìm thấy bản mới hay
  /// không) — cập nhật lại cả badge lẫn cờ "có nên hiện dialog không".
  Future<void> setAvailableUpdate(UpdateInfo? update) async {
    _availableUpdate = update;
    final prefs = await SharedPreferences.getInstance();
    _dismissedBuild = prefs.getInt(_kDismissedBuildKey);
    notifyListeners();
  }

  /// Gọi khi người dùng đóng UpdateDialog mà KHÔNG cài đặt (bấm "Để sau",
  /// chạm ra ngoài, hoặc back) — ghi nhớ build này đã bị bỏ qua, để lần mở
  /// app tiếp theo không hiện lại dialog nữa cho ĐÚNG build đó (nếu GitHub
  /// có bản mới hơn nữa thì vẫn hiện bình thường, vì buildNumber sẽ khác).
  Future<void> dismissCurrentUpdate() async {
    final build = _availableUpdate?.buildNumber;
    if (build == null) return;
    _dismissedBuild = build;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDismissedBuildKey, build);
    notifyListeners();
  }
}