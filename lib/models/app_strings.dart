// AppStrings chứa tất cả các chuỗi văn bản hiển thị trong ứng dụng.
// File này giúp tách riêng phần nội dung hiển thị khỏi logic, nên bạn không cần sửa UI khi thay đổi text.
//
import '../providers/theme_provider.dart';
// Cách hoạt động:
// - LanguageProvider tạo AppStrings dựa trên giá trị isVietnamese.
// - Các màn hình lấy strings từ LanguageProvider.
// - Hàm getter trả về văn bản tiếng Việt hoặc tiếng Anh tương ứng.
class AppStrings {
  final bool vi;
  const AppStrings(this.vi);

  String get appTitle => 'EyeCare AI';

  String get home => vi ? 'Trang chủ' : 'Home';
  String get test => vi ? 'Kiểm tra' : 'Test';
  String get habits => vi ? 'Thói quen' : 'Habits';
  String get stats => vi ? 'Thống kê' : 'Stats';
  String get chat => vi ? 'Chat' : 'Chat';
  String get settings => vi ? 'Cài đặt' : 'Settings';

  String get goodMorning => vi ? 'Chào buổi sáng 👋' : 'Good morning 👋';
  String get welcomeTitle => 'EyeCare AI';
  String get eyeHealthScore => vi ? 'Điểm sức khỏe mắt' : 'Eye Health Score';
  String get goodProgress => vi ? 'Tiến triển tốt! Giữ vững.' : 'Good progress! Keep it up.';
  String get fromLastWeek => vi ? '+5 so với tuần trước' : '+5 from last week';

  String get screenTime => vi ? 'Thời gian màn hình' : 'Screen Time';
  String get outdoor => vi ? 'Ngoài trời' : 'Outdoor';
  String get breaks => vi ? 'Nghỉ ngơi' : 'Breaks';
  String get weeklyOverview => vi ? 'Tổng quan tuần' : 'Weekly Overview';
  String get weeklyOverviewUnit =>
      vi ? 'Điểm sức khỏe mắt mỗi ngày (thang 0-100)' : 'Daily eye health score (0-100 scale)';
  String get aiSuggestions => vi ? 'Gợi ý AI' : 'AI Suggestions';
  String get takeBreak => vi ? 'Nghỉ theo quy tắc 20-20-20' : 'Take a 20-20-20 break';
  String get takeBreakSubtitle => vi ? 'Nhìn 6 mét ra xa trong 20 giây mỗi 20 phút.' : 'Look 20 feet away for 20 seconds every 20 minutes.';
  String get moreOutdoor => vi ? 'Đi ra ngoài nhiều hơn' : 'Get more outdoor time';
  String get moreOutdoorSubtitle => vi ? 'Ánh sáng tự nhiên giúp ngăn ngừa cận thị.' : 'Natural light helps prevent myopia progression.';
  String get improveSleep => vi ? 'Cải thiện giấc ngủ' : 'Improve sleep schedule';
  String get improveSleepSubtitle => vi ? 'Ngủ 7-8 tiếng để giảm mỏi mắt.' : 'Aim for 7-8 hours to reduce eye strain.';

  String get notifications => vi ? 'Thông báo' : 'Notifications';
  String get breakReminders => vi ? 'Nhắc nhở nghỉ ngơi' : 'Break Reminders';
  String get breakRemindersSubtitle => vi ? 'Nhận thông báo cho nghỉ ngơi 20-20-20' : 'Get notified for 20-20-20 breaks';
  String get eyeTestReminders => vi ? 'Nhắc nhở kiểm tra mắt' : 'Eye Test Reminders';
  String get eyeTestRemindersSubtitle => vi ? 'Nhắc kiểm tra thị lực hàng tuần' : 'Weekly vision screening alerts';
  String get habitTracking => vi ? 'Theo dõi thói quen' : 'Habit Tracking';
  String get habitTrackingSubtitle => vi ? 'Nhắc nhở hoàn thành thói quen hàng ngày' : 'Daily habit completion nudges';
  String get aiTips => vi ? 'Mẹo AI' : 'AI Tips';
  String get aiTipsSubtitle => vi ? 'Gợi ý chăm sóc mắt cá nhân' : 'Personalized eye health suggestions';

  // Phần này bao gồm các nhãn cho màn hình cài đặt và lựa chọn người dùng.
  String get preferences => vi ? 'Tùy chọn' : 'Preferences';
  String get appearanceSection => vi ? 'Giao diện & màu sắc' : 'Appearance & color';
  String get accentColorLabel => vi ? 'Màu nhấn' : 'Accent color';
  String get accentColorSubtitle => vi ? 'Chọn màu chủ đạo cho toàn app' : 'Pick the app-wide accent color';
  String get fontLabel => vi ? 'Phông chữ' : 'Font';
  String get fontSubtitleOther => vi ? 'Chọn phông chữ bạn thích' : 'Pick the font you like';
  String get fontLockedToVietnameseNote => vi
      ? 'Chỉ hiện các phông đã kiểm chứng hỗ trợ đầy đủ dấu tiếng Việt, để tránh lỗi hiển thị.'
      : 'Only fonts verified to fully support Vietnamese diacritics are shown, to avoid rendering issues.';
  String get themeLabel => vi ? 'Giao diện' : 'Theme';
  String get themeSubtitle => vi ? 'Sáng, tối hoặc theo máy' : 'Light, dark, or match device';
  String get screenSection => vi ? 'Màn hình' : 'Screen';

  String get brightnessTips => vi ? 'Gợi ý độ sáng' : 'Brightness Tips';
  String get brightnessTipsSubtitle =>
      vi ? 'Tự động chỉnh độ sáng theo môi trường' : 'Auto-adjust brightness to match your surroundings';
  String get brightnessReadingAmbient => vi ? 'Ánh sáng môi trường' : 'Ambient light';
  String get brightnessReadingCurrent => vi ? 'Độ sáng màn hình hiện tại' : 'Current screen brightness';
  String get brightnessReadingSuggested => vi ? 'Độ sáng đề xuất' : 'Suggested brightness';
  String get brightnessSensorUnavailable => vi
      ? 'Máy không có cảm biến ánh sáng hoặc chưa cấp quyền.'
      : 'No ambient light sensor found, or permission not granted.';
  String get brightnessApplyButton => vi ? 'Tự động điều chỉnh' : 'Auto-adjust';
  String get brightnessApplied => vi ? 'Đã chỉnh độ sáng theo môi trường.' : 'Brightness adjusted to match your surroundings.';
  String get brightnessPermissionNeeded => vi
      ? 'Cần cấp quyền "Sửa đổi cài đặt hệ thống" để app tự chỉnh được độ sáng.'
      : 'Needs "Modify system settings" permission to auto-adjust brightness.';
  String get brightnessGrantPermission => vi ? 'Cấp quyền' : 'Grant permission';
  String brightnessLuxDescription(int lux) {
    if (!vi) {
      if (lux < 10) return '$lux lux · Dark room';
      if (lux < 50) return '$lux lux · Dim indoor';
      if (lux < 300) return '$lux lux · Normal indoor';
      if (lux < 1000) return '$lux lux · Bright indoor';
      return '$lux lux · Outdoor / very bright';
    }
    if (lux < 10) return '$lux lux · Phòng tối';
    if (lux < 50) return '$lux lux · Trong nhà, hơi tối';
    if (lux < 300) return '$lux lux · Trong nhà, bình thường';
    if (lux < 1000) return '$lux lux · Trong nhà, sáng';
    return '$lux lux · Ngoài trời / rất sáng';
  }
  String themePreferenceLabel(AppThemePreference pref) {
    switch (pref) {
      case AppThemePreference.light:
        return vi ? 'Sáng' : 'Light';
      case AppThemePreference.dark:
        return vi ? 'Tối' : 'Dark';
      case AppThemePreference.system:
        return vi ? 'Theo hệ thống' : 'System';
    }
  }
  // Tự động điều chỉnh độ sáng (liên tục theo cảm biến, khác "Gợi ý độ
  // sáng" ở trên vốn chỉ áp 1 lần khi người dùng tự bấm).
  String get autoBrightnessTitle => vi ? 'Tự động điều chỉnh độ sáng' : 'Auto-adjust brightness';
  String get autoBrightnessSubtitle => vi
      ? 'Tăng/giảm độ sáng màn hình liên tục theo ánh sáng môi trường xung quanh'
      : 'Continuously raises/lowers screen brightness to match the light around you';
  String get metricUnits => vi ? 'Đơn vị mét' : 'Metric Units';
  String get imperialUnits => vi ? 'Đơn vị Anh' : 'Imperial Units';
  String get metricUnitsSubtitle => vi ? 'Xem centimet và giờ' : 'Centimeters, hours';
  String get imperialUnitsSubtitle => vi ? 'Xem inch và giờ' : 'Inches, hours';
  String get measurementUnits => vi ? 'Đơn vị đo lường' : 'Measurement Units';
  String get dateTime => vi ? 'Ngày & Giờ' : 'Date & Time';
  String get metricMeters => vi ? 'Mét' : 'Meters';
  String get imperialFeet => vi ? 'Feet' : 'Imperial (Feet)';
  String get hour12 => vi ? 'Định dạng 12 giờ' : '12-hour Clock';
  String get hour24 => vi ? 'Định dạng 24 giờ' : '24-hour Clock';
  String get language => vi ? 'Ngôn ngữ' : 'Language';
  String get selectOption => vi ? 'Chọn lựa' : 'Select option';
  String get chooseValue => vi ? 'Chọn giá trị' : 'Choose value';
  String get cancel => vi ? 'Hủy' : 'Cancel';
  String get languageSubtitle => vi ? 'Chuyển giữa tiếng Anh và tiếng Việt' : 'Switch between English and Vietnamese';
  String get vietnamese => vi ? 'Tiếng Việt' : 'Vietnamese';
  String get english => vi ? 'Tiếng Anh' : 'English';

  String get more => vi ? 'Khác' : 'More';
  String get privacySecurity => vi ? 'Quyền riêng tư & Bảo mật' : 'Privacy & Security';
  String get termsOfService => vi ? 'Điều khoản dịch vụ' : 'Terms of Service';
  String get helpSupport => vi ? 'Trợ giúp & Hỗ trợ' : 'Help & Support';
  String get signOut => vi ? 'Đăng xuất' : 'Sign Out';
  String get version => vi ? 'EyeCare AI v1.0.0' : 'EyeCare AI v1.0.0';
  String get guardianEmailTitle => vi ? 'Email người bảo hộ' : 'Guardian email';
  String get guardianEmailHint => vi ? 'Nhận mail nhắc nhở nếu quá giờ dùng thiết bị' : 'Receive reminders if device usage exceeds limits';
  String get guardianEmailAdd => vi ? 'Thêm email' : 'Add email';
  String get guardianEmailSendTest => vi ? 'Gửi mail nhắc thử' : 'Send test reminder';
  String get guardianEmailSaved => vi ? 'Đã lưu email người bảo hộ.' : 'Guardian email saved.';
  String get roadmapTitle => vi ? 'Lộ trình tính năng sắp tới' : 'Upcoming feature roadmap';
  List<String> get roadmapFeatures => vi
      ? [
          'Weekly Eye Health Report',
          'Streak cho Habits',
          'Achievement/Badges',
          'Đồng bộ Firebase',
          'AI Eye Health Score',
          'Outdoor Detection (tự động)',
          'Widget ngoài màn hình chính',
          'Export PDF Report',
          'Biểu đồ cải thiện mắt',
          'Bài tập mắt có hướng dẫn',
          'Widget countdown lần nghỉ tiếp theo',
          'So sánh xu hướng sức khỏe mắt theo tuần/tháng',
          'Chế độ đọc ban đêm',
          'Nhắc nhắc uống nước kèm nghỉ mắt',
          'Báo thức cập nhật thời gian báo tiếp theo',
        ]
      : [
          'Weekly Eye Health Report',
          'Streak for Habits',
          'Achievement/Badges',
          'Firebase Sync',
          'AI Eye Health Score',
          'Outdoor Detection (auto)',
          'Home screen widget',
          'Export PDF Report',
          'Eye improvement chart',
          'Guided eye exercises',
          'Next-break countdown widget',
          'Weekly/monthly eye health trend comparison',
          'Night-reading mode',
          'Water reminder + eye break',
          'Next reminder update in notification bar',
        ];

  String get eyeCareSettingVisionProfile => vi ? 'Hồ sơ thị lực' : 'Vision Profile';
  String get eyeCareSettingReminderStyle => vi ? 'Kiểu nhắc nhở' : 'Reminder Style';
  String get eyeCareSettingViewingDistance => vi ? 'Khoảng cách xem' : 'Viewing Distance';
  String get eyeCareSettingDistanceUnit => vi ? 'Đơn vị khoảng cách' : 'Distance Unit';
  String get eyeCareSettingMetric => vi ? 'Mét' : 'Metric (Meters)';
  String get eyeCareSettingImperial => vi ? 'Feet' : 'Imperial (Feet)';
  String get eyeCareSettingVisionGlasses => vi ? 'Đeo kính' : 'Glasses';
  String get eyeCareSettingVisionContacts => vi ? 'Kính áp tròng' : 'Contact Lens';
  String get eyeCareSettingVisionNoCorrection => vi ? 'Không sử dụng kính' : 'No Vision Correction';
  String get eyeCareSettingStyleGentle => vi ? 'Nhẹ nhàng' : 'Gentle';
  String get eyeCareSettingStyleNormal => vi ? 'Thông thường' : 'Normal';
  String get eyeCareSettingStyleStrict => vi ? 'Nghiêm ngặt' : 'Strict';
  String get eyeCareSettingDistanceAuto => vi ? 'Tự động phát hiện' : 'Auto Detect';
  String get eyeCareSettingDistanceManual => vi ? 'Thủ công' : 'Manual';
  String get eyeCareSettingMeter => vi ? 'Mét' : 'Meter';
  String get eyeCareSettingCentimeter => vi ? 'Centimét' : 'Centimeter';
  String get eyeCareSettingFeet => vi ? 'Feet' : 'Feet';
  String get eyeCareSettingInch => vi ? 'Inch' : 'Inch';
  String get achievementBadges => vi ? 'Thành tựu' : 'Achievements';
  String get ranking => vi ? 'Xếp hạng' : 'Ranking';
  String get achievementTitle => vi ? 'Thành tựu của bạn' : 'Your achievements';
  String get achievementUnlocked => vi ? 'Đã mở khóa' : 'Unlocked';
  String get achievementLocked => vi ? 'Chưa mở khóa' : 'Locked';
  String get achievementMood => vi ? 'Cứ mỗi lần bạn hoàn thành mục tiêu, EyeCare AI sẽ lưu lại và thông báo ngay khi thành tựu được mở khóa.' : 'Every time you complete a goal, EyeCare AI saves it and notifies you immediately when an achievement is unlocked.';
  String get achievementEyeRest => vi ? 'Nghỉ ngơi cho mắt' : 'Rest for the eyes';
  String get achievementRookie => vi ? '20-20-20 Rookie' : '20-20-20 Rookie';
  String get achievementMaster => vi ? 'Eye Break Master' : 'Eye Break Master';
  String get achievementLegend => vi ? 'Blink Legend' : 'Blink Legend';
  String get achievementGuardian => vi ? 'Guardian of Vision' : 'Guardian of Vision';
  String get achievementEyeRestDesc => vi ? 'Hoàn thành quy tắc 20-20-20 lần đầu.' : 'Complete the 20-20-20 rule for the first time.';
  String get achievementRookieDesc => vi ? 'Hoàn thành quy tắc 20-20-20 lần đầu.' : 'Complete the 20-20-20 rule for the first time.';
  String get achievementMasterDesc => vi ? 'Hoàn thành 5 lần nghỉ mắt.' : 'Complete 5 eye breaks.';
  String get achievementLegendDesc => vi ? 'Hoàn thành 15 lần nghỉ mắt.' : 'Complete 15 eye breaks.';
  String get achievementGuardianDesc => vi ? 'Không bỏ lỡ bất kỳ nhắc nhở nghỉ mắt nào trong 30 ngày.' : 'Never miss any eye-break reminder for 30 days.';
  String get underDevelopment => vi ? 'Đang phát triển' : 'Under development';

  // Bottom sheet "Quyền sử dụng dữ liệu"
  String get dataUsagePermissions => vi ? 'Quyền sử dụng dữ liệu' : 'Data usage permissions';
  String get permUsageTitle => vi ? 'Thời gian sử dụng ứng dụng' : 'App usage time';
  String get permUsageDesc => vi ? 'Theo dõi thời gian bạn dùng từng ứng dụng' : 'Tracks how long you use each app';
  String get permLocationTitle => vi ? 'Vị trí GPS' : 'GPS location';
  String get permLocationDesc => vi ? 'Theo dõi thời gian ngoài trời' : 'Tracks your time spent outdoors';
  String get permActivityTitle => vi ? 'Phát hiện hoạt động' : 'Activity recognition';
  String get permActivityDesc => vi ? 'Theo dõi vận động' : 'Tracks your physical activity';
  String get permGranted => vi ? 'Đã cấp' : 'Granted';
  String get permNotGranted => vi ? 'Chưa cấp' : 'Not granted';
  String get permFullScreenAlertTitle => vi ? 'Pop-up hết giờ nghỉ mắt' : 'Break reminder pop-up';
  String get permFullScreenAlertDesc => vi
      ? 'Bật "Hiển thị toàn màn hình" để thông báo hết giờ nghỉ mắt bung pop-up như báo thức (Android 14+)'
      : 'Enable "Full screen intent" so the break reminder pops up like an alarm (Android 14+)';
  String get permManage => vi ? 'Quản lý' : 'Manage';
  // Hướng dẫn cấp quyền theo từng hãng máy
  String get permGuideButton => vi ? 'Không thấy công tắc? Xem hướng dẫn' : 'Can\'t find the switch? See guide';
  String get permGuideTitle => vi ? 'Hướng dẫn cấp quyền theo máy' : 'Grant permission by device';
  String get permGuideIntro => vi
      ? 'Chọn hãng máy bạn đang dùng để xem các bước bật quyền "Truy cập dữ liệu sử dụng".'
      : 'Choose your device brand to see the steps to enable "Usage Access".';
  String get permGuideXiaomiTitle => vi ? 'Xiaomi / Redmi (MIUI, HyperOS)' : 'Xiaomi / Redmi (MIUI, HyperOS)';
  String get permGuideXiaomiSteps => vi
      ? '1. Mở Cài đặt > Ứng dụng > Quản lý ứng dụng\n2. Tìm EyeCare AI, chọn "Quyền khác" (hoặc "Quyền bổ sung")\n3. Bật "Quyền truy cập dữ liệu sử dụng"\n4. Nếu không thấy, vào Cài đặt > Bảo mật > Quyền riêng tư > Quyền đặc biệt > Truy cập dữ liệu sử dụng, rồi bật cho EyeCare AI\n5. Nên tắt thêm tối ưu hoá pin (MIUI Optimization) cho app để không bị thu hồi quyền'
      : '1. Open Settings > Apps > Manage apps\n2. Find EyeCare AI, tap "Other permissions"\n3. Enable "Usage data access"\n4. If not found, go to Settings > Privacy > Special permissions > Usage access, then enable it for EyeCare AI\n5. Also disable battery optimization for the app so the permission isn\'t revoked';
  String get permGuideSamsungTitle => vi ? 'Samsung (One UI)' : 'Samsung (One UI)';
  String get permGuideSamsungSteps => vi
      ? '1. Mở Cài đặt > Ứng dụng\n2. Nhấn biểu tượng ⋮ (góc trên phải) > Truy cập đặc biệt\n3. Chọn "Truy cập dữ liệu sử dụng" (Usage access)\n4. Tìm EyeCare AI và bật công tắc\n5. Vào Cài đặt pin > Giới hạn sinh hoạt nền, đưa EyeCare AI vào danh sách "Không giới hạn" để tránh bị tắt quyền'
      : '1. Open Settings > Apps\n2. Tap ⋮ (top right) > Special access\n3. Select "Usage access"\n4. Find EyeCare AI and turn on the switch\n5. In Battery settings, add EyeCare AI to "Unrestricted" background usage to avoid the permission being revoked';
  String get permGuideOppoTitle => vi ? 'Oppo / Vivo / Realme (ColorOS, FuntouchOS)' : 'Oppo / Vivo / Realme (ColorOS, FuntouchOS)';
  String get permGuideOppoSteps => vi
      ? '1. Mở Cài đặt > Quyền riêng tư (Privacy) > Quyền truy cập đặc biệt\n2. Chọn "Truy cập dữ liệu sử dụng" và bật cho EyeCare AI\n3. Vào Cài đặt pin > Quản lý pin ứng dụng, chọn EyeCare AI > "Cho phép chạy nền"\n4. Với Vivo: vào i Manager > Quyền ứng dụng > Quyền hệ thống > Truy cập dữ liệu sử dụng'
      : '1. Open Settings > Privacy > Special app access\n2. Select "Usage access" and enable it for EyeCare AI\n3. In Battery > App battery management, choose EyeCare AI > "Allow background activity"\n4. On Vivo: go to i Manager > App permissions > System permissions > Usage access';
  String get permGuideStockTitle => vi ? 'Android gốc / Pixel / Khác' : 'Stock Android / Pixel / Other';
  String get permGuideStockSteps => vi
      ? '1. Mở Cài đặt > Ứng dụng > Xem tất cả ứng dụng\n2. Nhấn biểu tượng ⋮ > Truy cập đặc biệt (Special access)\n3. Chọn "Truy cập dữ liệu sử dụng" (Usage access)\n4. Tìm EyeCare AI và bật công tắc'
      : '1. Open Settings > Apps > See all apps\n2. Tap ⋮ > Special access\n3. Select "Usage access"\n4. Find EyeCare AI and turn on the switch';
  String get permGuideIosTitle => vi ? 'iOS (iPhone)' : 'iOS (iPhone)';
  String get permGuideIosSteps => vi
      ? 'iOS không cho ứng dụng bên thứ ba truy cập trực tiếp dữ liệu "Thời gian sử dụng" (Screen Time) như Android.\n\nĐể theo dõi thời gian dùng máy, bạn có thể:\n1. Vào Cài đặt > Thời gian sử dụng (Screen Time) để xem số liệu do Apple cung cấp\n2. EyeCare AI sẽ dùng các quyền khác (thông báo, vị trí...) để nhắc bạn nghỉ mắt đúng giờ'
      : 'iOS does not allow third-party apps to directly access "Screen Time" usage data like Android does.\n\nTo track device usage, you can:\n1. Go to Settings > Screen Time to see the figures Apple provides\n2. EyeCare AI will use other permissions (notifications, location...) to remind you to rest your eyes on time';
  String get permBatteryTitle => vi ? 'Chạy nền không giới hạn' : 'Unrestricted background run';
  String get permBatteryDesc => vi
      ? 'Loại trừ khỏi tối ưu hoá pin để báo thức nghỉ mắt luôn kêu đúng giờ, kể cả khi app không mở'
      : 'Exclude from battery optimization so break reminders always fire on time, even when the app is closed';

  // Bộ lọc ánh sáng xanh — bật/tắt lớp phủ hổ phách toàn app (xem
  // MaterialApp.builder trong main.dart) để giảm mỏi mắt buổi tối.
  String get blueLightFilter => vi ? 'Bộ lọc ánh sáng xanh' : 'Blue Light Filter';
  String get blueLightFilterSubtitle => vi
      ? 'Phủ 1 lớp màu ấm lên toàn màn hình, giảm ánh sáng xanh gây mỏi mắt vào ban đêm'
      : 'Applies a warm tint over the whole screen, reducing blue light that strains eyes at night';
  String get blueLightIntensity => vi ? 'Độ đậm' : 'Intensity';
  String get darkMode => vi ? 'Chế độ tối' : 'Dark Mode';
  String get darkModeSubtitle => vi ? 'Bật/tắt nhanh giao diện tối' : 'Quickly switch to a dark interface';
  String get brightnessTipsBody => vi
      ? 'Chỉnh độ sáng màn hình khớp với ánh sáng xung quanh — đừng để màn hình sáng hơn hoặc tối hơn nhiều so với căn phòng, vì độ chênh lệch lớn khiến mắt phải điều tiết liên tục và nhanh mỏi.\n\n'
          '• Trong phòng tối: giảm độ sáng, bật Chế độ tối hoặc Bộ lọc ánh sáng xanh.\n'
          '• Ngoài trời/nơi nhiều ánh sáng: tăng độ sáng đủ để chữ rõ, tránh nheo mắt.\n'
          '• Bật độ sáng tự động (Auto-brightness) trong cài đặt máy để màn hình tự điều chỉnh theo môi trường.\n'
          '• Giữ khoảng cách 50-65cm giữa mắt và màn hình.'
      : 'Match your screen brightness to the light around you — a screen that\'s much brighter or dimmer than '
          'the room forces your eyes to keep adjusting and tires them faster.\n\n'
          '• In a dark room: lower brightness, use Dark Mode or the Blue Light Filter.\n'
          '• Outdoors or in bright light: raise brightness enough to read comfortably without squinting.\n'
          '• Turn on Auto-brightness in your device settings so it adapts automatically.\n'
          '• Keep your screen 50-65cm (20-25in) from your eyes.';

  // Nhập tay giờ ngủ (fallback khi Health Connect không có dữ liệu)
  String get manualSleepTitle => vi ? 'Nhập giờ ngủ đêm qua' : 'Log last night\'s sleep';
  String get manualSleepDesc => vi
      ? 'Chưa tìm thấy dữ liệu ngủ từ Health Connect. Bạn có thể tự nhập số giờ đã ngủ.'
      : 'No sleep data found from Health Connect. You can enter your sleep hours manually.';
  String get save => vi ? 'Lưu' : 'Save';

  List<String> get quickPrompts => vi
      ? [
          'Làm sao giảm mỏi mắt?',
          'Thức ăn tốt cho mắt',
          'Giải thích quy tắc 20-20-20',
          'Khi nào khám mắt?',
        ]
      : [
          'How to reduce eye strain?',
          'Best foods for eye health',
          '20-20-20 rule explained',
          'When to see an eye doctor?',
        ];

  String get eyeTest => vi ? 'Kiểm tra mắt' : 'Eye Test';
  String get quickEyeCheck => vi ? 'Kiểm tra nhanh mắt' : 'Quick eye check';
  String get stepLabel => vi ? 'Bước' : 'Step';
  String get canReadClearly => vi ? 'Đọc rõ' : 'Clear';
  String get notClear => vi ? 'Không rõ' : 'Not clear';
  String get eyeFeelsFine => vi ? 'Mắt vẫn ổn' : 'Eyes feel fine';
  String get eyeFeelsTired => vi ? 'Mắt mỏi' : 'Eyes tired';
  String get startCountdown => vi ? 'Bắt đầu đếm ngược' : 'Start countdown';
  String get countdownRunning => vi ? 'Đang đếm ngược…' : 'Counting down…';
  String get eyeTestStep1Title => vi ? 'Đọc chữ' : 'Read the letter';
  String get eyeTestStep1Subtitle => vi ? 'Nhìn vào ký tự ở giữa và hỏi bản thân: có đọc rõ không?' : 'Look at the letter in the center and ask: can you read it clearly?';
  String get eyeTestStep2Title => vi ? 'Nhìn xa' : 'Focus far away';
  String get eyeTestStep2Subtitle => vi ? 'Chuyển tầm nhìn ra xa trong 3 giây để kiểm tra độ rõ của mắt.' : 'Shift your focus far away for 3 seconds to test your visual clarity.';
  String get eyeTestStep3Title => vi ? 'Đếm thời gian nghỉ' : 'Count the rest time';
  String get eyeTestStep3Subtitle => vi ? 'Đừng đọc thêm, hãy nhìn xa trong khoảng 20 giây rồi trả lời mức độ mỏi.' : 'Avoid reading more; look away for 20 seconds, then rate your eye fatigue.';
  String get eyeTestResult => vi ? 'Kết quả kiểm tra' : 'Check result';
  String get eyeTestGood => vi ? 'Mắt của bạn đang ở mức ổn.' : 'Your eyes look in good condition.';
  String get eyeTestFair => vi ? 'Mắt có thể đang mỏi nhẹ, nên nghỉ ngơi thêm.' : 'Your eyes may be a bit tired; take a short rest.';
  String get eyeTestNeedsCare => vi ? 'Mắt đang cần nghỉ và theo dõi tốt hơn.' : 'Your eyes need more rest and attention.';
  String get eyeTestSummaryBody => vi ? 'Hãy dành vài phút nghỉ mắt, nhìn xa và giảm thời gian màn hình nếu cảm thấy mỏi.' : 'Take regular screen breaks, look away from the screen, and reduce exposure if you feel strain.';
  String get eyeTestReading => vi ? 'Đọc rõ' : 'Reading';
  String get eyeTestFocus => vi ? 'Tập trung' : 'Focus';
  String get eyeTestGoodShort => vi ? 'Ổn định' : 'Stable';
  String get eyeTestWeakShort => vi ? 'Cần chú ý' : 'Needs care';
  String get eyeTestStableShort => vi ? 'Tốt' : 'Good';
  String get eyeTestNeedBreakShort => vi ? 'Nghỉ mắt' : 'Take a break';
  String get eyeTestRetake => vi ? 'Làm lại' : 'Retake';

  // ---------------- Eye Break reminder screen ----------------
  String get eyeBreakTitle => vi ? 'Nhắc nghỉ mắt' : 'Eye Break Reminder';
  String get eyeBreakSubtitle => vi
      ? 'Quy tắc 20-20-20: cứ mỗi khoảng thời gian, hãy nhìn xa 6 mét trong 20 giây'
      : 'The 20-20-20 rule: every interval, look 20 feet away for 20 seconds';
  String get eyeBreakIntervalLabel => vi ? 'Nhắc mỗi' : 'Remind every';
  String get eyeBreakStart => vi ? 'Bắt đầu nhắc nghỉ mắt' : 'Start reminding';
  String get eyeBreakStop => vi ? 'Dừng nhắc' : 'Stop reminding';
  String get eyeBreakNextIn => vi ? 'Lần nhắc tiếp theo sau' : 'Next reminder in';
  String get breakNotificationTitle => vi ? 'Đang đếm giờ nghỉ mắt' : 'Eye break countdown';
  String get breakNotificationRemaining => vi ? 'Sẽ nhắc lúc' : 'Will remind at';
  String get breakNotificationUntil => vi ? 'Sẽ nhắc lúc' : 'Reminder at';
  String get autoDetectEyeBreakTitle =>
      vi ? 'Tự động ghi nhận khi khoá màn hình' : 'Auto-detect on screen lock';
  String get autoDetectEyeBreakDescription => vi
      ? 'Khoá màn hình / rời app từ 20 giây trở lên sẽ tự tính là 1 lần nghỉ mắt, không cần bấm "Xong" thủ công.'
      : 'Locking the screen or leaving the app for 20+ seconds automatically counts as an eye break — no need to tap "Done".';
  String get focusModeTitle => vi ? 'Chế độ Focus' : 'Focus mode';
  String get focusModeDescription => vi
      ? 'Chặn thông báo từ app khác trong lúc đang đếm ngược, giảm giật mình/mất tập trung — tự tắt lại khi đến giờ nghỉ mắt.'
      : 'Blocks notifications from other apps while the countdown runs, reducing startle/distraction — turns off automatically when it\'s break time.';
  String get focusModePermissionTitle =>
      vi ? 'Cần cấp quyền "Không làm phiền"' : 'Needs "Do Not Disturb" access';
  String get focusModePermissionDescription => vi
      ? 'Android yêu cầu cấp quyền này thủ công trong Cài đặt hệ thống, app không tự xin được. Bấm để mở đúng màn hình cần bật.'
      : 'Android requires granting this manually in system Settings — the app can\'t request it directly. Tap to open the right screen.';
  String get focusModeGrantAccess => vi ? 'Cấp quyền' : 'Grant access';
  String get eyeBreakTimeUp => vi ? 'Đến giờ nghỉ mắt rồi!' : 'Time for an eye break!';
  String get eyeBreakLookAway =>
      vi ? 'Nhìn vào một vật cách xa khoảng 6 mét' : 'Look at something about 20 feet away';
  String get eyeBreakTapToOpen =>
      vi ? 'Nhấn vào đây để mở Break Reminder' : 'Tap here to open Break Reminder';
  String get eyeBreakDone => vi ? 'Xong, đã nghỉ mắt' : 'Done, I rested my eyes';
  String get eyeBreakTodayCount => vi ? 'Số lần đã nghỉ hôm nay' : 'Breaks taken today';
  String get eyeBreakSkip => vi ? 'Bỏ qua lần này' : 'Skip this one';

  // ---------------- Habits survey / roadmap ----------------
  String get surveyEntryTitle => vi ? 'Đánh giá nhanh sức khỏe mắt' : 'Quick eye health check-in';
  String get surveyEntrySubtitle => vi
      ? 'Trả lời vài câu hỏi để nhận mục tiêu phù hợp với bạn'
      : 'Answer a few questions to get targets tailored to you';
  String get surveyEntryButton => vi ? 'Bắt đầu' : 'Start';
  String get surveyTitle => vi ? 'Khảo sát sức khỏe mắt' : 'Eye Health Survey';
  String get surveyAgeQuestion => vi ? 'Bạn thuộc nhóm tuổi nào?' : 'Which age group are you in?';
  String get surveyScreenQuestion =>
      vi ? 'Trung bình bạn dùng điện thoại/máy tính bao nhiêu giờ mỗi ngày?' : 'On average, how many hours a day do you use screens?';
  String get surveyOutdoorQuestion =>
      vi ? 'Bạn hoạt động ngoài trời bao nhiêu phút mỗi ngày?' : 'How many minutes a day do you spend outdoors?';
  String get surveyDistanceQuestion =>
      vi ? 'Khoảng cách mắt tới màn hình/sách khi đọc (cm)?' : 'Your typical eye-to-screen/book distance (cm)?';
  String get surveySleepQuestion =>
      vi ? 'Bạn ngủ trung bình mấy giờ mỗi đêm?' : 'How many hours do you usually sleep per night?';
  String get surveyBreaksQuestion =>
      vi ? 'Bạn nghỉ mắt (nhìn xa) bao nhiêu lần mỗi ngày?' : 'How many times a day do you rest your eyes (look away)?';
  String get surveySubmit => vi ? 'Xem kết quả' : 'See results';
  String get surveyResultsTitle => vi ? 'Lộ trình của bạn' : 'Your roadmap';
  String get surveyResultsSubtitle => vi
      ? 'So sánh với thông số khuyến nghị cho sức khỏe mắt'
      : 'Compared against recommended eye-health benchmarks';
  String get surveyCurrentLabel => vi ? 'Hiện tại' : 'Current';
  String get surveyTargetLabel => vi ? 'Khuyến nghị' : 'Recommended';
  String get surveyGoodStatus => vi ? 'Đạt chuẩn' : 'On track';
  String get surveyNeedsWorkStatus => vi ? 'Cần cải thiện' : 'Needs work';
  String get surveyApplyButton => vi ? 'Áp dụng làm mục tiêu của tôi' : 'Apply as my targets';
  String get targetSelectionTitle => vi ? 'Chọn mục tiêu của bạn' : 'Choose your target';
  String get targetSelectOption => vi ? 'Chọn một mức mục tiêu' : 'Pick a target level';
  String get targetOptionRecommended => vi ? 'Khuyến nghị' : 'Recommended';
  String get targetOptionEasy => vi ? 'Dễ dàng' : 'Easy';
  String get targetOptionChallenge => vi ? 'Thử thách' : 'Challenge';
  String get targetOptionCustom => vi ? 'Tùy chỉnh' : 'Custom';
  String get targetOptionKeepCurrent => vi ? 'Giữ nguyên' : 'Keep as is';
  String get targetAlreadyMetBanner => vi
      ? '🎉 Bạn đã đạt chỉ tiêu này rồi! Có thể giữ nguyên mức hiện tại hoặc đặt mục tiêu cao hơn nếu muốn.'
      : "🎉 You're already meeting this target! Keep it as is, or aim higher if you'd like.";
  String get surveySummaryContinue => vi ? 'Tiếp tục đặt mục tiêu' : 'Continue to set targets';
  String get targetCurrentLabel => vi ? 'Hiện tại' : 'Current';
  String get targetRecommendedLabel => vi ? 'Khuyến nghị chuẩn' : 'Recommended';
  String get targetYourPlan => vi ? 'Kế hoạch cá nhân của bạn' : 'Your Personalized Plan';
  String get targetSummarySubtitle => vi ? 'Xem lại và xác nhận trước khi áp dụng mục tiêu.' : 'Review and confirm before applying targets.';
  String get targetApplyButton => vi ? 'Áp dụng mục tiêu' : 'Apply Targets';
  String get targetCustomHint => vi ? 'Nhập giá trị tùy chỉnh' : 'Enter a custom value';
  String get targetCustomError => vi ? 'Giá trị phải nằm trong phạm vi hợp lệ.' : 'Value must be within the allowed range.';
  String get targetNext => vi ? 'Tiếp theo' : 'Next';
  String get targetBack => vi ? 'Quay lại' : 'Back';
  String get inchUnit => vi ? 'inch' : 'in';
  String get surveyAppliedMessage =>
      vi ? 'Đã cập nhật mục tiêu trên trang Habits!' : 'Your Habits targets have been updated!';
  String get surveyRetake => vi ? 'Làm lại khảo sát' : 'Retake survey';
  String get surveyDisclaimer => vi
      ? 'Đây là khuyến nghị chung, không thay thế tư vấn của bác sĩ nhãn khoa.'
      : 'These are general guidelines, not a substitute for advice from an eye doctor.';
  String get snellenScreening => vi ? 'Cài nhắc nghỉ mắt sau khoảng thời gian' : 'Set a break reminder after a time interval';
  String get reminderSet => vi ? 'Đã bật nhắc nghỉ mắt' : 'Reminder set';
  String get reminderInterval => vi ? 'Nhắc nhở sau' : 'Reminder after';
  String get minutes => vi ? 'phút' : 'mins';
  String get confirm => vi ? 'Xác nhận' : 'Confirm';
  String get visionScreening => vi ? 'Kiểm tra thị lực' : 'Vision Screening';
  String get visionScreeningTitle => vi ? 'Kiểm tra thị lực nhanh giúp ước lượng thị lực của bạn. Hãy đứng cách màn hình khoảng 2 mét và đảm bảo đủ sáng.' : 'This quick Snellen chart test helps estimate your visual acuity. Find a well-lit area and stand about 6 feet from your screen.';
  String get ensureLighting => vi ? 'Đảm bảo ánh sáng tốt' : 'Ensure good lighting';
  String get maintainDistance => vi ? 'Giữ khoảng cách ~2 m' : 'Maintain ~6 ft distance';
  String get wearGlasses => vi ? 'Đeo kính nếu bạn thường dùng' : 'Wear glasses if you normally do';
  String get startTest => vi ? 'Bắt đầu kiểm tra' : 'Start Test';
  String get coverYour => vi ? 'Che mắt của bạn' : 'Cover Your';
  String get useHandCover => vi ? 'Dùng tay che mắt. Giữ mắt còn lại nhìn vào màn hình.' : 'Use your hand to cover your eye. Keep the uncovered eye focused on the screen.';
  String get continueText => vi ? 'Tiếp tục' : 'Continue';
  String get readSmallestLine => vi ? 'Đọc dòng nhỏ nhất bạn nhìn rõ' : 'Read the smallest line you can see clearly';
  String get eyeLabelLeft => vi ? 'Mắt trái' : 'Left Eye';
  String get eyeLabelRight => vi ? 'Mắt phải' : 'Right Eye';
  String get selectYourResult => vi ? 'Chọn kết quả của bạn:' : 'Select your result:';
  String get testComplete => vi ? 'Hoàn thành kiểm tra!' : 'Test Complete!';
  String get aiInsight => vi ? 'Thông tin AI' : 'AI Insight';
  String get retakeTest => vi ? 'Kiểm tra lại' : 'Retake Test';

  String get dailyHabits => vi ? 'Thói quen hàng ngày' : 'Daily Habits';
  String get featureInDevelopment => vi ? 'Tính năng này đang được phát triển' : 'This feature is under development';
  String get trackRoutines => vi ? 'Theo dõi thói quen thân thiện với mắt' : 'Track your eye-friendly routines';
  String get todaysProgress => vi ? 'Tiến trình hôm nay' : 'Today\'s Progress';
  String get target => vi ? 'Mục tiêu' : 'Target';
  String get habitsCompleted => vi ? 'thói quen đã hoàn thành' : 'habits completed';

  String completedHabits(int completed, int total) =>
      vi ? '$completed/$total thói quen đã hoàn thành' : '$completed of $total habits completed';

  // habitTitle chuyển id của thói quen thành tiêu đề phù hợp cho màn hình.
  // Thêm case mới nếu bạn mở rộng danh sách thói quen.
  // habitTitle chuyển id nội bộ của thói quen thành tiêu đề hiển thị.
  // Nếu thêm thói quen mới, hãy mở rộng switch-case ở đây.
  String habitTitle(String id) {
    switch (id) {
      case 'reading':
        return vi ? 'Số lần test mắt' : 'Eye Test Count';
      case 'phone':
        return vi ? 'Sử dụng điện thoại' : 'Phone Usage';
      case 'sleep':
        return vi ? 'Giấc ngủ' : 'Sleep';
      case 'outdoor':
        return vi ? 'Thời gian ngoài trời' : 'Outdoor Time';
      case 'breaks':
        return vi ? 'Nghỉ ngơi mắt' : 'Eye Breaks';
      default:
        return id;
    }
  }

  // habitSubtitle mô tả nguồn dữ liệu thật đứng sau mỗi thói quen
  // (cảm biến / API hệ điều hành nào đang được dùng để đo).
  String habitSubtitle(String id) {
    switch (id) {
      case 'reading':
        return featureInDevelopment;
      case 'phone':
        return vi ? 'Thời gian màn hình (hệ điều hành)' : 'Screen-on time (OS)';
      case 'sleep':
        return vi ? 'Health Connect hoặc nhập tay' : 'Health Connect or manual entry';
      case 'outdoor':
        return vi ? 'GPS + cảm biến ánh sáng' : 'GPS + light sensor';
      case 'breaks':
        return vi ? 'Nhận diện ánh nhìn qua camera trước' : 'Front camera gaze detection';
      default:
        return '';
    }
  }

  // habitUnit chuyển đơn vị thói quen sang văn bản phù hợp.
  // Bạn có thể mở rộng đơn vị mới ở đây.
  // habitUnit chuyển đơn vị đo của thói quen sang text phù hợp.
  // Hiện tại, một số đơn vị giữ nguyên ở cả hai ngôn ngữ.
  String habitUnit(String unit) {
    switch (unit) {
      case 'cm':
        return vi ? 'cm' : 'cm';
      case 'hrs':
        return vi ? 'giờ' : 'hrs';
      case 'min':
        return vi ? 'phút' : 'min';
      case 'times':
        return vi ? 'lần' : 'times';
      case 'breaks':
        return vi ? 'lần nghỉ' : 'breaks';
      case 'glasses':
        return vi ? 'ly' : 'glasses';
      default:
        return unit;
    }
  }

  String stepCount(int step, int total) =>
      vi ? 'Bước $step trong $total' : 'Step $step of $total';

  // ---------------- Chat AI ----------------
  String get aiAssistant => vi ? 'Trợ lý AI' : 'AI Assistant';
  String get online => vi ? 'Đang hoạt động' : 'Online';
  String get askAboutEyeHealth => vi ? 'Hỏi về sức khỏe mắt...' : 'Ask about eye health...';

  String get chatApiKeySetupTitle => vi ? 'Kết nối trợ lý AI' : 'Connect AI assistant';
  String get chatApiKeySetupBody => vi
      ? 'Nhập khoá Gemini API (miễn phí tại aistudio.google.com/apikey) để bắt đầu trò chuyện thật với AI. '
          'Khoá chỉ được lưu trên máy bạn, không gửi đi đâu khác ngoài Google.'
      : 'Enter your Gemini API key (free at aistudio.google.com/apikey) to start chatting with a real AI. '
          'The key is stored only on your device and sent only to Google.';
  String get chatApiKeyHint => vi ? 'Dán khoá API vào đây (AIzaSy...)' : 'Paste your API key (AIzaSy...)';
  String get chatApiKeySave => vi ? 'Lưu & bắt đầu' : 'Save & start';
  String get chatApiKeyCancel => vi ? 'Để sau' : 'Later';
  String get chatApiKeyChange => vi ? 'Đổi khoá API' : 'Change API key';
  String get chatDisabledTitle => vi ? 'AI Chat đang bảo trì' : 'AI Chat Under Maintenance';
  String get chatDisabledSubtitle => vi
      ? 'Tính năng chat AI sẽ quay lại trong thời gian tới.'
      : 'AI chat will return soon.';
  String get chatErrorMissingKey =>
      vi ? 'Chưa thiết lập khoá API. Nhấn vào biểu tượng ⚙️ ở trên để thêm khoá.' : 'No API key set. Tap the ⚙️ icon above to add one.';
  String get chatErrorInvalidKey =>
      vi ? 'Khoá API không hợp lệ hoặc đã hết hạn. Vui lòng kiểm tra lại.' : 'Invalid or expired API key. Please check it again.';
  String get chatErrorRateLimited =>
      vi ? 'Đã vượt hạn mức sử dụng. Vui lòng thử lại sau ít phút.' : 'Rate limit reached. Please try again in a few minutes.';
  String get chatErrorNetwork =>
      vi ? 'Không kết nối được mạng. Kiểm tra lại internet rồi thử lại.' : 'Couldn\'t reach the network. Check your connection and try again.';
  String get chatErrorGeneric =>
      vi ? 'Có lỗi xảy ra, vui lòng thử lại.' : 'Something went wrong, please try again.';

  String get chatGreeting => vi
      ? 'Chào bạn! Mình là trợ lý AI của EyeCare AI. Hỏi mình bất cứ điều gì về sức khỏe mắt, thời gian dùng màn hình, hoặc mẹo chăm sóc thị lực nhé.'
      : 'Hi! I\'m your EyeCare AI assistant. Ask me anything about eye health, '
          'screen time, or vision care tips.';

  List<String> get chatQuickPrompts => vi
      ? const [
          'Cách giảm mỏi mắt?',
          'Thực phẩm tốt cho mắt',
          'Quy tắc 20-20-20 là gì?',
          'Khi nào nên khám mắt?',
        ]
      : const [
          'How to reduce eye strain?',
          'Best foods for eye health',
          '20-20-20 rule explained',
          'When to see an eye doctor?',
        ];

  Map<String, String> get chatResponses => vi
      ? const {
          'Cách giảm mỏi mắt?':
              'Để giảm mỏi mắt: áp dụng quy tắc 20-20-20 (cứ 20 phút nhìn xa 20 feet trong 20 giây), '
                  'chỉnh độ sáng màn hình, dùng ánh sáng phù hợp, chớp mắt thường xuyên và nghỉ ngơi đều đặn. '
                  'Giữ màn hình cách mắt khoảng 50-65cm.',
          'Thực phẩm tốt cho mắt':
              'Thực phẩm giàu lutein, zeaxanthin, omega-3 và vitamin A, C, E rất tốt cho mắt. '
                  'Hãy ăn rau lá xanh (rau bina, cải xoăn), cá béo (cá hồi), trứng, cà rốt, trái cây họ cam quýt '
                  'và các loại hạt. Đừng quên uống đủ nước!',
          'Quy tắc 20-20-20 là gì?':
              'Quy tắc 20-20-20: cứ mỗi 20 phút dùng màn hình, hãy nhìn vào một vật cách xa khoảng 6 mét '
                  'trong ít nhất 20 giây. Điều này giúp thư giãn cơ mắt và giảm mỏi mắt do thiết bị điện tử. '
                  'Hãy đặt hẹn giờ hoặc dùng tính năng nhắc nghỉ mắt của app!',
          'Khi nào nên khám mắt?':
              'Hãy đi khám mắt nếu bạn gặp: mờ mắt kéo dài, đau mắt, đau đầu thường xuyên, '
                  'nhìn đôi, thấy chớp sáng, hoặc thay đổi thị lực đột ngột. Người lớn nên khám mắt toàn diện '
                  'mỗi 1-2 năm, hoặc hằng năm nếu đang đeo kính/kính áp tròng.',
        }
      : const {
          'How to reduce eye strain?':
              'To reduce eye strain: follow the 20-20-20 rule (every 20 min, look 20 feet away for 20 sec), '
                  'adjust screen brightness, use proper lighting, blink often, and take regular breaks. '
                  'Keep your screen 20-26 inches from your eyes.',
          'Best foods for eye health':
              'Foods rich in lutein, zeaxanthin, omega-3, and vitamins A, C, E support eye health. '
                  'Try leafy greens (spinach, kale), fatty fish (salmon), eggs, carrots, citrus fruits, '
                  'and nuts. Stay hydrated too!',
          '20-20-20 rule explained':
              'The 20-20-20 rule: every 20 minutes of screen time, look at something 20 feet (6 meters) '
                  'away for at least 20 seconds. This relaxes your eye muscles and reduces digital eye strain. '
                  'Set a timer or use our break reminders!',
          'When to see an eye doctor?':
              'See an eye doctor if you experience: persistent blurred vision, eye pain, frequent headaches, '
                  'double vision, flashes of light, or sudden vision changes. Adults should get a comprehensive '
                  'eye exam every 1-2 years, or annually if you wear glasses/contacts.',
        };

  String get chatFallbackResponse => vi
      ? 'Câu hỏi hay đấy! Theo các hướng dẫn chung, việc nghỉ ngơi đều đặn, ánh sáng tốt và khám mắt định kỳ '
          'là những yếu tố quan trọng. Bạn có muốn mình gợi ý thêm về thời gian màn hình, dinh dưỡng, hay bài tập cho mắt không?'
      : 'That\'s a great question about eye health! Based on general guidelines, '
          'maintaining regular breaks, good lighting, and annual eye check-ups are key. '
          'Would you like specific tips on screen time, nutrition, or vision exercises?';

  List<String> get weeklyLabels => vi
      ? ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<String> get monthlyLabels =>
      ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];

  String get score => vi ? 'Điểm' : 'Score';
  String get sleep => vi ? 'Giấc ngủ' : 'Sleep';
  String get hourUnit => vi ? 'giờ' : 'hrs';
  String get pointUnit => vi ? 'điểm' : 'pts';
  String get visionAiFeedback => vi ? 'Thị lực của bạn nằm trong phạm vi bình thường. Mắt phải của bạn cho thấy khả năng nhìn kém hơn một chút — hãy cân nhắc khám mắt chuyên nghiệp nếu tình trạng này kéo dài.' : 'Your vision is within normal range. Your right eye shows slightly lower acuity — consider scheduling a professional eye exam if this persists.';

  String get statistics => vi ? 'Thống kê' : 'Statistics';
  String get trackTrends => vi ? 'Theo dõi xu hướng sức khỏe mắt' : 'Track your eye health trends';
  String get weekly => vi ? 'Hàng tuần' : 'Weekly';
  String get monthly => vi ? 'Hàng tháng' : 'Monthly';
  String get habitCompletion => vi ? 'Hoàn thành thói quen' : 'Habit Completion';
  String get streak => vi ? 'Chuỗi' : 'Streak';
  String get dayStreak => vi ? 'ngày liên tiếp' : 'day streak';

  // ---------------- App usage breakdown (Statistics pie chart) ----------------
  String get appUsageBreakdownTitle => vi ? 'Sử dụng theo ứng dụng' : 'App Usage Breakdown';
  String get appUsageTotalToday => vi ? 'Tổng hôm nay' : 'Total today';
  String get appUsageDurationLabel => vi ? 'Thời gian đã dùng' : 'Time used';
  String get appOpenCountLabel => vi ? 'Số lần mở' : 'Times opened';
  String get appDataUnavailable => vi
      ? 'Chưa có nguồn dữ liệu — cần cấp quyền xem thời gian sử dụng'
      : 'No data source yet — grant usage access to enable this';
  String get grantUsageAccess => vi ? 'Cấp quyền xem thời gian sử dụng' : 'Grant usage access';

  // ---------------- First-Time Setup Wizard ----------------
  String get setupWizardTitle => vi ? 'Thiết lập ban đầu' : 'Initial Setup';
  String get setupWelcomeTitle => vi ? 'Chào mừng đến với EyeCare AI 👋' : 'Welcome to EyeCare AI 👋';
  String get setupWelcomeBody => vi
      ? 'Cấp vài quyền dưới đây để app theo dõi thói quen dùng điện thoại, nhắc bạn nghỉ mắt đúng lúc và đọc được giấc ngủ — chỉ mất khoảng 1 phút. Bước nào cũng có thể bỏ qua và cấp lại sau trong Cài đặt.'
      : 'Grant a few permissions below so the app can track your phone habits, remind you to rest your eyes on time, and read your sleep data — takes about a minute. Every step can be skipped and granted later in Settings.';
  String get setupGetStarted => vi ? 'Bắt đầu' : 'Get started';
  String get setupSkipStep => vi ? 'Bỏ qua' : 'Skip';
  String get setupNextStep => vi ? 'Tiếp theo' : 'Next';
  String get setupGrantButton => vi ? 'Cấp quyền' : 'Grant permission';
  String get setupGranted => vi ? 'Đã cấp quyền' : 'Granted';
  String get setupFinish => vi ? 'Bắt đầu sử dụng' : 'Start using the app';
  String get setupDoneTitle => vi ? 'Xong rồi! 🎉' : "All set! 🎉";
  String setupDoneBody(int granted, int total) => vi
      ? 'Bạn đã cấp $granted/$total quyền. Bạn có thể vào Cài đặt để cấp nốt các quyền còn thiếu bất cứ lúc nào.'
      : "You've granted $granted/$total permissions. You can finish the rest anytime from Settings.";

  String get setupStepUsageTitle => vi ? 'Thời gian sử dụng điện thoại' : 'Phone usage access';
  String get setupStepUsageBody => vi
      ? 'Cho phép app đọc thời gian dùng điện thoại để tính habit "Thời gian màn hình", điểm sức khỏe mắt và biểu đồ Thống kê. Bạn sẽ được đưa tới màn hình Cài đặt hệ thống, tìm "EyeCare AI" và bật lên.'
      : 'Lets the app read your screen time to power the "Phone Usage" habit, your eye-health score, and the Statistics charts. You\'ll be taken to a system settings screen — find "EyeCare AI" and turn it on.';

  String get setupStepNotificationsTitle => vi ? 'Thông báo' : 'Notifications';
  String get setupStepNotificationsBody => vi
      ? 'Để app nhắc bạn nghỉ mắt theo quy tắc 20-20-20 đúng giờ, kể cả khi không mở app.'
      : 'So the app can remind you to take 20-20-20 eye breaks on time, even when the app is closed.';

  String get setupStepLocationTitle => vi ? 'Vị trí (GPS)' : 'Location (GPS)';
  String get setupStepLocationBody => vi
      ? 'Dùng vị trí để ước lượng thời gian bạn ở ngoài trời — 1 trong 5 thói quen tốt cho mắt app theo dõi. Chỉ dùng lúc app đang mở, không theo dõi liên tục nền.'
      : 'Uses your location to estimate time spent outdoors — one of the 5 eye-health habits the app tracks. Only used while the app is open, not tracked continuously in the background.';

  String get setupStepActivityTitle => vi ? 'Nhận diện hoạt động' : 'Activity recognition';
  String get setupStepActivityBody => vi
      ? 'Giúp app phân biệt lúc bạn đang di chuyển/vận động với lúc ngồi yên nhìn màn hình, để tính habit chính xác hơn.'
      : 'Helps the app tell moving/active moments apart from sitting still looking at the screen, for more accurate habit tracking.';

  String get setupStepFullScreenTitle => vi ? 'Popup hết giờ nghỉ mắt' : 'Eye-break pop-up alert';
  String get setupStepFullScreenBody => vi
      ? 'Trên Android 14+, cần bật riêng "Hiển thị toàn màn hình" thì thông báo hết giờ nghỉ mắt mới bung ra như báo thức, thay vì chỉ nằm im trong thanh thông báo.'
      : 'On Android 14+, "Display over other apps" must be turned on separately for the eye-break alert to pop up like an alarm, instead of just sitting quietly in the notification shade.';

  String get setupStepBatteryTitle => vi ? 'Chạy nền không giới hạn' : 'Unrestricted background run';
  String get setupStepBatteryBody => vi
      ? 'Nhiều hãng máy (Xiaomi/OPPO/Vivo/Samsung...) tự tắt app đứng yên trong nền để tiết kiệm pin, khiến báo thức nghỉ mắt bị trễ hoặc im lặng. Loại trừ app khỏi tối ưu hoá pin để tránh việc này.'
      : 'Many phone makers (Xiaomi/OPPO/Vivo/Samsung...) freeze idle background apps to save battery, causing eye-break alerts to be delayed or silent. Exclude the app from battery optimization to prevent this.';

  String get setupStepFocusModeTitle => vi ? 'Chế độ Tập trung' : 'Focus Mode';
  String get setupStepFocusModeBody => vi
      ? 'Cho phép app tạm chặn thông báo từ app khác trong lúc đang đếm ngược giữa 2 lần nghỉ mắt, giúp bạn không bị làm phiền/giật mình.'
      : 'Lets the app briefly block other notifications while counting down between eye breaks, so you\'re not interrupted.';

  String get setupBannerTitle => vi ? 'Hoàn tất thiết lập' : 'Finish setup';
  String setupBannerSubtitle(int granted, int total) =>
      vi ? 'Đã cấp $granted/$total quyền' : '$granted/$total permissions granted';
  String get setupBannerAction => vi ? 'Tiếp tục' : 'Continue';

  // ---------------- Change target sheet ----------------
  String get changeTargetButton => vi ? 'Đổi mục tiêu' : 'Change Target';
  String get changeTargetSubtitle => vi
      ? 'Tự chỉnh mục tiêu hằng ngày cho từng thói quen'
      : 'Manually adjust your daily target for each habit';
  String get changeTargetSave => vi ? 'Lưu mục tiêu' : 'Save targets';

  // ---------------- Auth ----------------
  String get login => vi ? 'Đăng nhập' : 'Log in';
  String get register => vi ? 'Đăng ký' : 'Sign up';
  String get email => 'Email';
  String get password => vi ? 'Mật khẩu' : 'Password';
  String get confirmPassword => vi ? 'Xác nhận mật khẩu' : 'Confirm password';
  String get fullName => vi ? 'Họ tên' : 'Full name';
  String get forgotPassword => vi ? 'Quên mật khẩu?' : 'Forgot password?';
  String get orDivider => vi ? 'hoặc' : 'or';
  String get continueWithGoogle => vi ? 'Tiếp tục với Google' : 'Continue with Google';
  String get noAccountYet => vi ? 'Chưa có tài khoản? Đăng ký' : "Don't have an account? Sign up";
  String get haveAccount => vi ? 'Đã có tài khoản? Đăng nhập' : 'Already have an account? Log in';
  String get resetEmailSent => vi ? 'Đã gửi email đặt lại mật khẩu.' : 'Password reset email sent.';
  String get enterEmailFirst => vi ? 'Nhập email trước khi lấy lại mật khẩu.' : 'Enter your email first.';
  String get passwordsDontMatch => vi ? 'Mật khẩu xác nhận không khớp.' : "Passwords don't match.";
  String get requiredField => vi ? 'Bắt buộc nhập' : 'Required';
  String get welcomeBack => vi ? 'Chào mừng quay lại' : 'Welcome back';
  String get createAccount => vi ? 'Tạo tài khoản mới' : 'Create your account';

  // ---------------- Settings > More ----------------
  String get settingsMoreTitle => vi ? 'Cài đặt thêm' : 'More';

  // Privacy & Security section
  String get sectionPrivacy => vi ? 'Quyền riêng tư' : 'Privacy';
  String get sectionSecurity => vi ? 'Bảo mật' : 'Security';
  String get sectionDataManagement => vi ? 'Quản lý dữ liệu' : 'Data Management';
  String get dataCollectionTitle => vi ? 'Thu thập dữ liệu' : 'Data Collection';
  String get dataCollectionDesc => vi
      ? 'Cho phép ứng dụng thu thập dữ liệu sử dụng ẩn danh để cải thiện gợi ý AI.'
      : 'Allow the app to collect anonymous usage data to improve AI recommendations.';
  String get cloudBackupTitle => vi ? 'Sao lưu đám mây' : 'Cloud Backup';
  String get cloudBackupDesc => vi
      ? 'Tự động sao lưu tiến trình và hồ sơ sức khỏe mắt lên Firebase.'
      : 'Automatically back up your progress and eye health records to Firebase.';
  String get personalizedAiTitle => vi ? 'Phân tích AI cá nhân hóa' : 'Personalized AI Analysis';
  String get personalizedAiDesc => vi
      ? 'Cho phép AI phân tích thói quen sử dụng để đưa ra gợi ý cá nhân hóa.'
      : 'Allow AI to analyze your usage habits for personalized suggestions.';
  String get changePasswordTitle => vi ? 'Đổi mật khẩu' : 'Change Password';
  String get biometricLoginTitle => vi ? 'Bật đăng nhập sinh trắc học' : 'Enable Biometric Login';
  String get biometricSupportedDesc =>
      vi ? 'Có thể dùng vân tay / Face ID trên thiết bị này' : 'Fingerprint / Face ID available on this device';
  String get biometricUnsupportedDesc =>
      vi ? 'Thiết bị này không hỗ trợ' : 'Not supported on this device';
  String get twoFactorAuthTitle => vi ? 'Xác thực 2 lớp' : 'Two-Factor Authentication';
  String get twoFactorAuthOnDesc =>
      vi ? 'Yêu cầu xác minh qua email khi đăng nhập' : 'Email verification required at login';
  String get twoFactorAuthOffDesc =>
      vi ? 'Thêm bước xác minh email khi đăng nhập' : 'Adds an email verification step at login';
  String get loginRequired => vi ? 'Cần đăng nhập' : 'Login required';

  // ---- Consent screen ----
  String get consentTitle => vi ? 'Quyền riêng tư & Đồng ý' : 'Privacy & Consent';
  String get consentSubtitle => vi
      ? 'Trước khi bắt đầu, vui lòng xem cách chúng tôi xử lý dữ liệu của bạn.'
      : 'Before you begin, please review how we handle your data.';
  String get consentCollectTitle => vi ? 'Dữ liệu thu thập' : 'What We Collect';
  String get consentCollectBody => vi
      ? 'Thời gian sử dụng, thời gian ngoài trời, giấc ngủ, nghỉ mắt (cảm biến thiết bị).\nCâu trả lời khảo sát của bạn (nhóm tuổi, thói quen).\nTin nhắn chat AI (khi tính năng được bật lại).'
      : 'Screen time, outdoor minutes, sleep, eye breaks (device sensors).\nYour survey answers (age group, habits).\nAI chat messages (when re-enabled).';
  String get consentUseTitle => vi ? 'Mục đích sử dụng' : 'How We Use It';
  String get consentUseBody => vi
      ? 'Tính điểm sức khỏe mắt.\nĐưa ra gợi ý cá nhân hóa.\nCải thiện AI (ẩn danh, khi bật).'
      : 'Calculate your Eye Health Score.\nProvide personalized recommendations.\nImprove AI suggestions (anonymous, when enabled).';
  String get consentRightsTitle => vi ? 'Quyền của bạn' : 'Your Rights';
  String get consentRightsBody => vi
      ? 'Dữ liệu lưu cục bộ trên thiết bị.\nKhông bao giờ bán cho bên thứ ba.\nCó thể xóa mọi dữ liệu bất kỳ lúc nào trong Cài đặt.'
      : 'Data stored locally on your device.\nNever sold to third parties.\nYou can delete all data anytime in Settings.';
  String get consentAccept => vi ? 'Chấp nhận & Tiếp tục' : 'Accept & Continue';
  String get consentDecline => vi ? 'Từ chối' : 'Decline';
  String get consentWithdraw => vi ? 'Rút đồng ý' : 'Withdraw Consent';
  String get consentWithdrawDesc => vi
      ? 'Rút đồng ý sẽ xóa tất cả dữ liệu và đặt lại ứng dụng.'
      : 'Withdrawing consent will delete all data and reset the app.';

  // ---- Export ----
  String get exportMyData => vi ? 'Xuất dữ liệu của tôi' : 'Export My Data';
  String get exportMyDataDone =>
      vi ? 'Dữ liệu của bạn đã sẵn sàng để tải xuống.' : 'Your data export is ready.';
  String get downloadEyeHealthReport =>
      vi ? 'Tải báo cáo sức khỏe mắt (PDF)' : 'Download Eye Health Report (PDF)';
  String get deleteAllLocalData => vi ? 'Xóa toàn bộ dữ liệu cục bộ' : 'Delete All Local Data';
  String get deleteAllLocalDataTitle =>
      vi ? 'Xóa toàn bộ dữ liệu cục bộ?' : 'Delete all local data?';
  String get deleteAllLocalDataDesc => vi
      ? 'Thao tác này chỉ xóa dữ liệu đã lưu trên thiết bị này. Dữ liệu sao lưu trên đám mây không bị ảnh hưởng.'
      : 'This clears cached progress on this device only. Cloud backups are unaffected.';
  String get deleteAccountAction => vi ? 'Xóa tài khoản' : 'Delete Account';
  String get deleteAccountTitle => vi ? 'Xóa tài khoản?' : 'Delete Account?';
  String get deleteAccountDesc => vi
      ? 'Thao tác này sẽ xóa vĩnh viễn tài khoản, hồ sơ sức khỏe mắt và toàn bộ dữ liệu liên quan. Không thể hoàn tác.'
      : 'This will permanently delete your account, eye health records, and all associated data. This action cannot be undone.';
  String get delete => vi ? 'Xóa' : 'Delete';

  // Terms of Service section
  String get docAppUsagePolicy => vi ? 'Chính sách sử dụng ứng dụng' : 'App Usage Policy';
  String get docUserResponsibilities => vi ? 'Trách nhiệm người dùng' : 'User Responsibilities';
  String get docAiDisclaimer => vi ? 'Tuyên bố miễn trừ AI' : 'AI Disclaimer';
  String get docMedicalDisclaimer => vi ? 'Tuyên bố miễn trừ y tế' : 'Medical Disclaimer';
  String get docDataProtectionPolicy => vi ? 'Chính sách bảo vệ dữ liệu' : 'Data Protection Policy';
  String get docOpenSourceLicenses => vi ? 'Giấy phép mã nguồn mở' : 'Open Source Licenses';
  String get termsVersion => vi ? 'Phiên bản điều khoản 1.0' : 'Terms Version 1.0';
  String get termsLastUpdated => vi ? 'Cập nhật lần cuối: Tháng 7, 2026' : 'Last Updated: July 2026';

  // Help & Support section
  String get faqTitle => vi ? 'Câu hỏi thường gặp' : 'Frequently Asked Questions';
  String get contactSupport => vi ? 'Liên hệ hỗ trợ' : 'Contact Support';
  String get emailSupport => vi ? 'Hỗ trợ qua Email' : 'Email Support';
  String get reportBug => vi ? 'Báo lỗi' : 'Report a Bug';
  String get requestFeature => vi ? 'Đề xuất tính năng' : 'Request a Feature';
  String get feedbackTitle => vi ? 'Phản hồi' : 'Feedback';
  String get feedbackHint =>
      vi ? 'Cho chúng tôi biết cần cải thiện gì ở Eye Care AI...' : 'Tell us how we can improve Eye Care AI...';
  String get submitFeedback => vi ? 'Gửi qua Email' : 'Send via Email';
  String get feedbackThanks => vi ? 'Cảm ơn bạn đã phản hồi!' : 'Thanks for your feedback!';
  String get feedbackNoEmailApp => vi
      ? 'Không tìm thấy ứng dụng email trên máy. Vui lòng gửi góp ý tới eyecareai.app@gmail.com'
      : 'No email app found on this device. Please send feedback to eyecareai.app@gmail.com';
  String get aboutTitle => vi ? 'Giới thiệu' : 'About';
  String get commitCopied => vi ? 'Đã sao chép commit SHA' : 'Commit SHA copied';

  // Sign out / change password flows
  String get signOutConfirmTitle => vi ? 'Đăng xuất?' : 'Sign Out?';
  String get signOutConfirmDesc =>
      vi ? 'Bạn có chắc muốn đăng xuất khỏi tài khoản không?' : 'Are you sure you want to sign out of your account?';
  String get currentPassword => vi ? 'Mật khẩu hiện tại' : 'Current Password';
  String get newPassword => vi ? 'Mật khẩu mới' : 'New Password';
  String get confirmNewPassword => vi ? 'Xác nhận mật khẩu mới' : 'Confirm New Password';
  String get updatePassword => vi ? 'Cập nhật mật khẩu' : 'Update Password';
  String get passwordUpdated => vi ? 'Đã cập nhật mật khẩu.' : 'Password updated.';

  // Cập nhật app từ GitHub Releases (xem lib/services/update_service.dart +
  // lib/widgets/update_dialog.dart) — app không lên Google Play nên tự kiểm
  // tra bản mới thay vì trông chờ Play Store.
  String get updateAvailableTitle => vi ? 'Có bản cập nhật mới' : 'Update available';
  String updateAvailableSubtitle(String versionName) =>
      vi ? 'Phiên bản $versionName đã sẵn sàng.' : 'Version $versionName is ready.';
  String get updateNotesTitle => vi ? 'Có gì mới' : "What's new";
  String get updateLater => vi ? 'Để sau' : 'Later';
  String get updateNow => vi ? 'Cập nhật ngay' : 'Update now';
  String get updateDownloading => vi ? 'Đang tải bản cập nhật...' : 'Downloading update...';
  String get updateDownloadFailed =>
      vi ? 'Tải bản cập nhật thất bại. Vui lòng thử lại sau.' : 'Download failed. Please try again later.';
  String get updateOpenInstaller => vi ? 'Mở trình cài đặt' : 'Open installer';
  String get checkForUpdate => vi ? 'Kiểm tra bản cập nhật' : 'Check for update';
  String get noUpdateAvailable => vi ? 'Bạn đang dùng bản mới nhất.' : 'You are on the latest version.';
  String get updateCheckFailed => vi ? 'Không kiểm tra được bản cập nhật. Vui lòng thử lại sau.' : 'Unable to check for updates. Please try again later.';
}