import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/rank_tier.dart';
import '../services/leaderboard_service.dart';

class RankProvider extends ChangeNotifier {
  int _streakDays = 0;
  RankTier _tier = RankTiers.forStreak(0);
  RankTier? _justPromotedTo;

  List<LeaderboardEntry> leaderboard = [];
  bool isLoadingLeaderboard = false;
  StreamSubscription<List<LeaderboardEntry>>? _leaderboardSub;

  int get streakDays => _streakDays;
  RankTier get tier => _tier;
  RankTier? get nextTier => RankTiers.nextTier(_streakDays);

  /// Bậc vừa lên (khác null trong 1 lần build duy nhất) — RankScreen đọc
  /// giá trị này để hiện banner "Chúc mừng bạn đạt danh hiệu..." rồi gọi
  /// [clearPromotionBanner] để không hiện lại mỗi lần rebuild.
  RankTier? get justPromotedTo => _justPromotedTo;

  /// Số ngày còn thiếu để lên bậc kế tiếp (0 nếu đã ở bậc cao nhất).
  int get daysToNextTier {
    final next = nextTier;
    if (next == null) return 0;
    return (next.minStreakDays - _streakDays).clamp(0, next.minStreakDays);
  }

  /// Tiến độ (0..1) trong chặng đường từ bậc hiện tại tới bậc kế tiếp.
  double get progressToNextTier {
    final next = nextTier;
    if (next == null) return 1;
    final span = next.minStreakDays - _tier.minStreakDays;
    if (span <= 0) return 1;
    return ((_streakDays - _tier.minStreakDays) / span).clamp(0.0, 1.0);
  }

  int? get myRank => LeaderboardService.rankOf(leaderboard, FirebaseAuth.instance.currentUser?.uid);

  /// Gọi mỗi khi streak thật của người dùng được tính lại (sau
  /// HabitProvider.refreshHabitsFromDevice) — kể cả khi giá trị KHÔNG đổi so
  /// với lần trước trong phiên này. Cập nhật bậc cục bộ NGAY LẬP TỨC để UI
  /// phản hồi tức thời, đồng thời LUÔN đẩy lên Firestore ở nền cho bảng xếp
  /// hạng chung.
  ///
  /// BUG ĐÃ SỬA: bản cũ `if (streakDays == _streakDays) return;` thoát SỚM
  /// và bỏ qua luôn cả bước đồng bộ Firestore khi giá trị mới trùng với giá
  /// trị đang giữ trong bộ nhớ — nhưng `_streakDays` LUÔN khởi động lại về 0
  /// mỗi lần mở app (đây là 1 provider sống trong RAM, không phải giá trị đã
  /// đồng bộ). Hậu quả: nếu streak thật hôm nay tính ra ĐÚNG BẰNG 0 (ví dụ
  /// điểm sức khỏe mắt hôm nay chưa đạt 80%, streak bị đứt), và Firestore
  /// đang lỡ lưu 1 số cũ lớn hơn (ví dụ "1" từ hôm trước) — điều kiện
  /// `0 == 0` (so với _streakDays mặc định) đúng ngay từ đầu, hàm return
  /// trước khi kịp gọi syncMyStreak(), nên giá trị SAI trên Firestore không
  /// bao giờ được sửa lại, khiến Bảng xếp hạng đứng yên mãi mãi ở số cũ dù
  /// người dùng đã rớt chuỗi thật. Giờ luôn đẩy lên Firestore mỗi lần được
  /// gọi, chỉ bỏ qua phần cập nhật UI cục bộ (tier/banner lên hạng) nếu giá
  /// trị không đổi để đỡ rebuild thừa.
  Future<void> updateStreak(int streakDays) async {
    // Luôn đồng bộ lên Firestore, kể cả khi không đổi so với bộ nhớ cục bộ —
    // đây là cách DUY NHẤT để tự sửa lại giá trị SAI/CŨ đang lỡ lưu trên đó.
    unawaited(LeaderboardService.instance.syncMyStreak(streakDays: streakDays));

    if (streakDays == _streakDays) return;

    final previousTier = _tier;
    _streakDays = streakDays;
    _tier = RankTiers.forStreak(streakDays);

    if (_tier.minStreakDays > previousTier.minStreakDays) {
      _justPromotedTo = _tier;
    }
    notifyListeners();
  }

  void clearPromotionBanner() {
    if (_justPromotedTo == null) return;
    _justPromotedTo = null;
    notifyListeners();
  }

  /// Bắt đầu lắng nghe bảng xếp hạng realtime — gọi khi mở RankScreen.
  void startWatchingLeaderboard() {
    isLoadingLeaderboard = true;
    notifyListeners();
    _leaderboardSub?.cancel();
    _leaderboardSub = LeaderboardService.instance.watchTopStreaks().listen((entries) {
      leaderboard = entries;
      isLoadingLeaderboard = false;
      notifyListeners();
    }, onError: (_) {
      isLoadingLeaderboard = false;
      notifyListeners();
    });
  }

  /// Dừng lắng nghe — gọi khi đóng RankScreen để tránh rò rỉ listener khi
  /// người dùng không còn xem bảng xếp hạng nữa.
  void stopWatchingLeaderboard() {
    _leaderboardSub?.cancel();
    _leaderboardSub = null;
  }

  @override
  void dispose() {
    _leaderboardSub?.cancel();
    super.dispose();
  }
}