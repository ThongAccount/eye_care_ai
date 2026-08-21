package com.eyecare.eye_care_ai

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.PowerManager
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// MainActivity thêm một MethodChannel riêng cho các dữ liệu mà package
// `app_usage` không cung cấp đủ chính xác/đầy đủ:
// 1. hasUsageAccess: đã có quyền Usage access chưa
// 2. getLaunchCounts: số lần mở mỗi app hôm nay
// 3. getUsageBreakdown: thời gian dùng THẬT của từng app, tính bằng cách
//    ghép cặp sự kiện MOVE_TO_FOREGROUND/MOVE_TO_BACKGROUND — đây CHÍNH LÀ
//    cách Digital Wellbeing của Google tính toán nội bộ (không có API công
//    khai nào để đọc thẳng số liệu đã tính sẵn của Digital Wellbeing, nhưng
//    dùng cùng phương pháp thô này sẽ cho kết quả sát với nó hơn nhiều so với
//    UsageStatsManager.queryUsageStats() (cách cũ), vốn hay bị lệch do cách
//    Android gộp dữ liệu theo nhiều khung thời gian chồng lấn.
class MainActivity : FlutterActivity() {
    private val channelName = "eye_care_ai/usage_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // BUG DA SUA: UsageStatsHandler (kenh "eye_care/usage" - dung boi
        // UsageService.dart cho checkUsagePermission/openUsageSettings/
        // getTodayUsage/getWeeklyUsage) da ton tai san nhung CHUA BAO GIO
        // duoc dang ky (register) o day. Vi vay moi loi goi tu Dart toi kenh
        // nay deu roi vao MissingPluginException - day chinh la ly do nhan
        // vao "Thoi gian su dung ung dung" trong muc Quyen su dung du lieu
        // khong he mo man hinh cap quyen.
        UsageStatsHandler(this).register(flutterEngine.dartExecutor.binaryMessenger)
        FocusModeHandler(this).register(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageAccess" -> result.success(hasUsageAccessPermission())
                "getLaunchCounts" -> {
                    val (start, end) = extractRange(call) ?: return@setMethodCallHandler result.error("BAD_ARGS", "startMillis/endMillis required", null)
                    result.success(getLaunchCounts(start, end))
                }
                "getUsageBreakdown" -> {
                    val (start, end) = extractRange(call) ?: return@setMethodCallHandler result.error("BAD_ARGS", "startMillis/endMillis required", null)
                    result.success(getUsageBreakdown(start, end))
                }
                // Dùng cho tính năng cảnh báo "dùng điện thoại trong bóng
                // tối" chạy NỀN định kỳ (workmanager, xem
                // dark_room_background_service.dart): tránh báo nhầm khi máy
                // đang nằm trong túi/trên bàn với màn hình tắt nhưng phòng
                // vừa tối (không phải đang thật sự CẦM MÁY nhìn màn hình).
                "isScreenOn" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(powerManager.isInteractive)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun extractRange(call: io.flutter.plugin.common.MethodCall): Pair<Long, Long>? {
        val start = (call.argument<Number>("startMillis"))?.toLong() ?: return null
        val end = (call.argument<Number>("endMillis"))?.toLong() ?: return null
        return start to end
    }

    private fun hasUsageAccessPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getLaunchCounts(startMillis: Long, endMillis: Long): Map<String, Int> {
        val counts = mutableMapOf<String, Int>()
        if (!hasUsageAccessPermission()) return counts

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events: UsageEvents = usageStatsManager.queryEvents(startMillis, endMillis)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                counts[event.packageName] = (counts[event.packageName] ?: 0) + 1
            }
        }
        return counts
    }

    // Những package không nên tính vào "Phone Usage" giống Digital Wellbeing:
    // chính app mình (đứng "foreground" khi mở app để xem thống kê thì không
    // tính là "dùng điện thoại"), và các launcher/system-ui thường đứng nền
    // trước/sau mỗi lần chuyển app nhưng người dùng không thật sự "dùng" nó.
    private val excludedPackages by lazy {
        val launcherPackage = try {
            val intent = android.content.Intent(android.content.Intent.ACTION_MAIN)
            intent.addCategory(android.content.Intent.CATEGORY_HOME)
            packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.packageName
        } catch (e: Exception) {
            null
        }
        // Digital Wellbeing của Google KHÔNG tính thời gian ở màn hình chính
        // (launcher) vào tổng screen-time — loại trừ tương tự để số liệu sát
        // hơn với Digital Wellbeing.
        setOfNotNull(
            packageName, // com.eyecare.eye_care_ai — chính app này
            "com.android.systemui",
            launcherPackage,
        )
    }   

    // Ghép cặp MOVE_TO_FOREGROUND -> MOVE_TO_BACKGROUND (hoặc kết thúc
    // khoảng truy vấn nếu app vẫn đang mở) để tính tổng thời gian foreground
    // thật sự của từng app, kèm tên hiển thị (app label) để không cần gọi
    // thêm package_manager phía Dart.
    //
    // QUAN TRỌNG (lý do Phone Usage từng hiện SAI, cao hơn Digital Wellbeing
    // thực tế): nếu người dùng khoá màn hình trong khi một app vẫn là app
    // "foreground" gần nhất (ví dụ đang nghe nhạc/xem video rồi tắt màn
    // hình), Android không phải lúc nào cũng bắn MOVE_TO_BACKGROUND ngay khi
    // khoá máy — app đó có thể vẫn được tính là "đang mở" trong lúc màn hình
    // tắt, khiến tổng thời gian bị cộng dồn nhầm cả lúc không hề nhìn màn
    // hình. Cách xử lý: theo dõi thêm sự kiện SCREEN_INTERACTIVE /
    // SCREEN_NON_INTERACTIVE của hệ thống — mỗi khi màn hình tắt, CẮT NGAY
    // khoảng thời gian đang mở tại đúng thời điểm đó (coi như app đã "đóng"
    // tạm thời), rồi mở lại mốc bắt đầu mới khi màn hình sáng lại.
    private fun getUsageBreakdown(startMillis: Long, endMillis: Long): List<Map<String, Any>> {
        if (!hasUsageAccessPermission()) return emptyList()

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events: UsageEvents = usageStatsManager.queryEvents(startMillis, endMillis)
        val event = UsageEvents.Event()

        val openTimestamps = mutableMapOf<String, Long>()
        val totalMillis = mutableMapOf<String, Long>()
        var screenOn = true // giả định màn hình đang sáng tại startMillis

        fun closeAllOpenApps(atTime: Long) {
            for ((pkg, openedAt) in openTimestamps) {
                if (atTime > openedAt) {
                    totalMillis[pkg] = (totalMillis[pkg] ?: 0L) + (atTime - openedAt)
                }
            }
            openTimestamps.clear()
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    if (screenOn) {
                        openTimestamps[event.packageName] = event.timeStamp
                    }
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val openedAt = openTimestamps.remove(event.packageName)
                    if (openedAt != null && event.timeStamp > openedAt) {
                        val duration = event.timeStamp - openedAt
                        totalMillis[event.packageName] = (totalMillis[event.packageName] ?: 0L) + duration
                    }
                }
                UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                    // Màn hình vừa tắt/khoá -> cắt ngay mọi app đang "mở" tại
                    // đúng thời điểm này, không cộng dồn thêm thời gian sau đó.
                    closeAllOpenApps(event.timeStamp)
                    screenOn = false
                }
                UsageEvents.Event.SCREEN_INTERACTIVE -> {
                    // Màn hình sáng lại -> coi như app top hiện tại (nếu có)
                    // vừa được mở lại từ mốc này.
                    screenOn = true
                }
            }
        }
        // Bất kỳ app nào còn "đang mở" khi hết khoảng truy vấn VÀ màn hình
        // vẫn đang sáng lúc đó -> tính tới thời điểm endMillis.
        if (screenOn) {
            closeAllOpenApps(endMillis)
        }

        val pm = packageManager
        return totalMillis.entries
            .filter { it.value >= 30_000 && it.key !in excludedPackages } // bỏ app dùng <30s hoặc bị loại trừ
            .sortedByDescending { it.value }
            .map { (pkg, millis) ->
                val label = try {
                    pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                } catch (e: PackageManager.NameNotFoundException) {
                    pkg
                }
                mapOf(
                    "packageName" to pkg,
                    "appName" to label,
                    "usageMillis" to millis
                )
            }
    }
}