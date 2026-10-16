import 'package:flutter/material.dart';

// Toàn bộ icon CHỨC NĂNG (menu, nút, thẻ habit, cài đặt, logo màn đăng
// nhập...) trước đây dùng emoji dạng String render qua Text() — nhìn thiếu
// chuyên nghiệp, không đồng bộ style/độ dày nét, và không tự đổi màu theo
// accent color của app.
//
// LƯU Ý: bản đầu tiên dùng package `lucide_icons`, nhưng package đó
// `extends IconData` — cách làm này KHÔNG còn hợp lệ từ khi Flutter SDK đổi
// `IconData` thành `final class`, gây lỗi build release
// "The class 'IconData' can't be extended outside of its library". Đã đổi
// sang dùng thẳng `Icons.*` có sẵn trong Flutter framework — không phải
// package ngoài, không bao giờ bị vỡ vì lệch version SDK kiểu này nữa.
//
// Không đổi kiểu dữ liệu `icon` từ String sang IconData ở tầng model/provider
// (một số nơi như HabitData có thể đã được lưu vào SharedPreferences dạng
// chuỗi, đổi kiểu sẽ vỡ dữ liệu cũ) — chỉ đổi TẦNG HIỂN THỊ: bảng ánh xạ bên
// dưới dịch emoji quen thuộc trong app sang icon Material tương ứng (ưu
// tiên bản "_outlined" cho nét mảnh, hiện đại, hợp app sức khỏe/lifestyle).
// Emoji nào CHƯA có trong bảng thì tự động fallback về hiện chính emoji đó
// (không vỡ UI), nên có thể bổ sung ánh xạ dần dần, an toàn.
//
// CẬP NHẬT: theo yêu cầu UI/UX mới (không dùng emoji ở BẤT KỲ đâu, kể cả
// badge streak, icon gợi ý AI, icon bậc xếp hạng...), bảng ánh xạ được mở
// rộng để phủ hết các glyph còn dùng rải rác trong app (rank_tier, home
// suggestion bullets, achievement badges...) — mọi nơi hiển thị các glyph
// này giờ PHẢI đi qua AppIcon thay vì Text() thô để thực sự hết emoji.
const Map<String, IconData> _kIconMap = {
  // Habits & quick actions
  '👀': Icons.remove_red_eye_outlined,
  '👁️': Icons.remove_red_eye_outlined,
  '📱': Icons.smartphone_outlined,
  '😴': Icons.bedtime_outlined,
  '🧪': Icons.science_outlined,
  '🧠': Icons.psychology_outlined,
  '🌳': Icons.park_outlined,
  '🌿': Icons.eco_outlined,
  '☀️': Icons.wb_sunny_outlined,
  '☕': Icons.coffee_outlined,
  '⏰': Icons.alarm_outlined,
  '⏱': Icons.timer_outlined,
  '⚙️': Icons.settings_outlined,
  '✅': Icons.check_circle_outline,
  '💬': Icons.chat_bubble_outline,
  '📊': Icons.bar_chart_outlined,
  '🔒': Icons.lock_outline,
  '🔥': Icons.local_fire_department_outlined,
  // Settings
  '📍': Icons.location_on_outlined,
  '🛡️': Icons.shield_outlined,
  '🚪': Icons.logout_outlined,
  '🔄': Icons.refresh_outlined,
  '🔤': Icons.text_fields_outlined,
  '🔋': Icons.battery_charging_full_outlined,
  '📋': Icons.assignment_outlined,
  '💡': Icons.lightbulb_outline,
  '👓': Icons.remove_red_eye_outlined,
  '🏃': Icons.directions_walk_outlined,
  '🎯': Icons.track_changes_outlined,
  '🌐': Icons.language_outlined,
  '❓': Icons.help_outline,
  '🚀': Icons.rocket_launch_outlined,
  '👤': Icons.account_circle_outlined,
  '📧': Icons.email_outlined,
  '🎨': Icons.palette_outlined,
  '🌙': Icons.bedtime_outlined,
  '🟠': Icons.wb_sunny_outlined, // "Bộ lọc ánh sáng xanh"
  '🤖': Icons.smart_toy_outlined,
  '🏆': Icons.emoji_events_outlined,
  '🏅': Icons.military_tech,
  '⭐': Icons.star_outline,
  '🔔': Icons.notifications_outlined,
  '🔧': Icons.build_outlined,
  // Bổ sung: gợi ý AI, thông báo, và huy hiệu bậc xếp hạng (rank tiers) —
  // trước đây các nơi này vẫn hiện thẳng emoji qua Text(), giờ đi qua bảng
  // này để thống nhất dùng Material Icons trong toàn app.
  '✨': Icons.auto_awesome_outlined,
  '🌤️': Icons.wb_cloudy_outlined,
  '⚠️': Icons.warning_amber_outlined,
  '💧': Icons.water_drop_outlined,
  '🎉': Icons.celebration_outlined,
  '👋': Icons.waving_hand_outlined,
  '🥚': Icons.egg_outlined,
  '🥉': Icons.workspace_premium_outlined,
  '🥈': Icons.workspace_premium_outlined,
  '🥇': Icons.workspace_premium_outlined,
  '💠': Icons.diamond_outlined,
  '💎': Icons.diamond_outlined,
  '👑': Icons.workspace_premium_outlined,
};

// Dùng thay cho `Text(icon, style: TextStyle(fontSize: ...))` ở mọi nơi
// render icon chức năng. Truyền `color` để icon tự đổi theo accent color
// thay vì luôn có màu emoji mặc định của hệ điều hành.
class AppIcon extends StatelessWidget {
  const AppIcon(this.glyph, {super.key, this.size = 22, this.color});

  final String glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final mapped = _kIconMap[glyph];
    if (mapped != null) {
      return Icon(mapped, size: size, color: color);
    }
    // Chưa có ánh xạ cho emoji này -> fallback an toàn, không vỡ UI.
    return Text(glyph, style: TextStyle(fontSize: size));
  }
}