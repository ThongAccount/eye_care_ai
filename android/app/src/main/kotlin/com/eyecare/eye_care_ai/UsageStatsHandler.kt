package com.eyecare.eye_care_ai

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import java.util.Calendar
import android.content.pm.PackageManager
class UsageStatsHandler(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "eye_care/usage"
    }

    fun register(binaryMessenger: BinaryMessenger) {
        MethodChannel(binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(
        
        call: MethodCall,
        result: MethodChannel.Result
    ) {

        when (call.method) {

            "checkUsagePermission" -> {
                result.success(checkUsagePermission())
            }

            "openUsageSettings" -> {
                openUsageSettings()
                result.success(true)
            }

            "getTodayUsage" -> {
                try {
                    result.success(getTodayUsage())
                } catch (e: Exception) {
                    result.error(
                        "USAGE_ERROR",
                        e.message,
                        null
                    )
                }
            }
            "getWeeklyUsage" -> {
                result.success(getWeeklyUsage())
            }

            "getSleepEstimate" -> {
                try {
                    result.success(getSleepEstimate())
                } catch (e: Exception) {
                    result.error("USAGE_ERROR", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Kiểm tra quyền Usage Access
     */
    private fun checkUsagePermission(): Boolean {

        val appOps =
            context.getSystemService(Context.APP_OPS_SERVICE)
                    as AppOpsManager

        val mode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {

                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )

            } else {

                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )

            }

        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Mở màn hình cấp quyền Usage Access
     */
    private fun openUsageSettings() {

        // Thử mở thẳng tới đúng app trong danh sách Usage Access trước
        // (một số máy OEM như Xiaomi/Oppo cần data URI mới hiện đúng app).
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.data = android.net.Uri.fromParts("package", context.packageName, null)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            return
        } catch (e: Exception) {
            // fallthrough
        }

        // Fallback: mở danh sách chung Usage Access (không kèm package)
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            return
        } catch (e: Exception) {
            // fallthrough
        }

        // Fallback cuối: mở trang chi tiết app, người dùng tự vào Permissions
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = android.net.Uri.fromParts("package", context.packageName, null)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            // Không còn cách nào khác, bỏ qua
        }
    }

    private fun getAppName(packageName: String): String {

        return try {

            val appInfo =
                context.packageManager.getApplicationInfo(packageName, 0)

            context.packageManager
                .getApplicationLabel(appInfo)
                .toString()

        } catch (e: PackageManager.NameNotFoundException) {

            packageName

        }
    }
    
    /**
    * Lấy Usage Stats từ 00:00 hôm nay đến hiện tại.
    */
    private fun getTodayUsage(): List<Map<String, Any>> {
        if (!checkUsagePermission()) {
            throw Exception("Usage permission not granted")
        }

        val usageManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE)
                    as UsageStatsManager

        // 00:00 hôm nay
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        val stats = usageManager.queryAndAggregateUsageStats(
            startTime,
            endTime
        )

        val result = mutableListOf<Map<String, Any>>()
        val ignoredPackages = setOf(
            "android",
            "com.android.systemui",
            "com.google.android.gms"
        )

        for ((packageName, usage) in stats) {
            if (packageName in ignoredPackages)
                continue

            val totalTime =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                    usage.totalTimeVisible
                else
                    @Suppress("DEPRECATION")
                    usage.totalTimeInForeground

            if (totalTime <= 0)
                continue

            val item = hashMapOf<String, Any>()

            item["packageName"] = packageName

            item["appName"] = getAppName(packageName)

            item["totalTime"] = totalTime

            item["lastTimeUsed"] = usage.lastTimeUsed

            result.add(item)
        }

        result.sortByDescending {

            (it["totalTime"] as Long)

        }

        return result
    }

    private fun getWeeklyUsage(): Map<String, List<Map<String, Any>>> {
        if (!checkUsagePermission()) {
            throw Exception("Usage permission not granted")
        }

        val usageManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE)
                    as UsageStatsManager

        val calendar = Calendar.getInstance()

        // Bắt đầu tuần (thứ 2)
        calendar.set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)

        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        val stats = usageManager.queryAndAggregateUsageStats(
            startTime,
            endTime
        )

        val result = mutableMapOf<String, MutableList<Map<String, Any>>>()
        val ignoredPackages = setOf(
            "android",
            "com.android.systemui",
            "com.google.android.gms"
        )

        for ((packageName, usage) in stats) {
            if (packageName in ignoredPackages)
                continue

            val totalTime =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                    usage.totalTimeVisible
                else
                    @Suppress("DEPRECATION")
                    usage.totalTimeInForeground

            if (totalTime <= 0)
                continue

            val item = hashMapOf<String, Any>()

            item["packageName"] = packageName

            item["appName"] = getAppName(packageName)

            item["totalTime"] = totalTime

            item["lastTimeUsed"] = usage.lastTimeUsed

            // Lấy ngày sử dụng
            val dayCalendar = Calendar.getInstance().apply {
                timeInMillis = usage.lastTimeUsed
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            val dayKey =
                "${dayCalendar.get(Calendar.YEAR)}-${dayCalendar.get(Calendar.MONTH) + 1}-${dayCalendar.get(Calendar.DAY_OF_MONTH)}"

            if (!result.containsKey(dayKey)) {
                result[dayKey] = mutableListOf()
            }

            result[dayKey]?.add(item)
        }

        return result
    }

    /**
     * ƯỚC LƯỢNG GIỜ NGỦ TỪ USAGE EVENTS — thay cho Health Connect (đã bị bỏ,
     * không phải máy nào cũng cài, và bắt cấp thêm 1 quyền riêng gây phiền).
     *
     * Cách làm: quét raw UsageEvents.MOVE_TO_FOREGROUND (mỗi lần người dùng
     * mở/chuyển tới 1 app tính là "màn hình đang hoạt động") trong khung giờ
     * CỐ ĐỊNH theo lịch — luôn là "18:00 HÔM QUA -> hiện tại", KHÔNG phụ
     * thuộc app đang được mở vào giờ nào trong ngày hôm nay (xem lịch sử bug
     * đã sửa ngay dưới đây nếu tò mò tại sao trước đây hay bị null).
     *   - "Đêm qua dùng máy lần cuối" = sự kiện MUỘN NHẤT nằm trong khung
     *     "tối" (18:00 hôm qua -> 04:00 hôm nay).
     *   - "Sáng nay dùng máy lần đầu" = sự kiện SỚM NHẤT nằm trong khung
     *     "sáng" (04:00 -> 12:00 hôm nay) và PHẢI sau mốc "đêm qua" ở trên.
     * Đây là suy luận (không phải đo trực tiếp giấc ngủ), có thể sai nếu
     * người dùng KHÔNG chạm máy trong lúc thức (đọc sách giấy...) hoặc có
     * chạm máy trong lúc mất ngủ giữa đêm — nên FE nên hiển thị rõ đây là
     * "ước lượng", không phải số đo chính xác.
     */
    private fun getSleepEstimate(): Map<String, Any?> {
        if (!checkUsagePermission()) {
            throw Exception("Usage permission not granted")
        }

        val usageManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val now = Calendar.getInstance()

        // BUG ĐÃ SỬA: bản cũ chọn cửa sổ "đêm" dựa theo bây giờ đang trước
        // hay sau 12h trưa HÔM NAY — nếu app được mở vào buổi CHIỀU/TỐI (gần
        // như mọi lúc người dùng thực sự cầm điện thoại lên, KHÔNG PHẢI chỉ
        // trong khung 4h-12h sáng), cửa sổ "đêm" bị đặt vào 18h TỐI NAY (CHƯA
        // xảy ra) thay vì tối HÔM QUA (đã xảy ra) -> luôn bỏ sót hoàn toàn dữ
        // liệu tối qua -> kết quả luôn null, hiện "Chưa có nguồn dữ liệu" dù
        // dữ liệu thật sự có tồn tại.
        //
        // Giờ cửa sổ được CỐ ĐỊNH theo lịch, không phụ thuộc giờ hiện tại:
        // luôn xét đúng 1 chu kỳ "tối HÔM QUA (18:00) -> sáng HÔM NAY
        // (04:00-12:00)" — đây luôn là chu kỳ ngủ GẦN NHẤT đã (hoặc đang)
        // diễn ra, dù người dùng mở app vào bất kỳ giờ nào trong ngày.
        val nightStart = (now.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, -1)
            set(Calendar.HOUR_OF_DAY, 18); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val nightEnd = (nightStart.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1); set(Calendar.HOUR_OF_DAY, 4) }
        val morningStart = nightEnd
        val morningEnd = (morningStart.clone() as Calendar).apply { set(Calendar.HOUR_OF_DAY, 12) }
        val queryStart = nightStart

        val events: UsageEvents = usageManager.queryEvents(queryStart.timeInMillis, now.timeInMillis)
        val event = UsageEvents.Event()

        var lastNightUsage: Long? = null
        var firstMorningUsage: Long? = null

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType != UsageEvents.Event.MOVE_TO_FOREGROUND) continue
            val t = event.timeStamp

            if (t in nightStart.timeInMillis until nightEnd.timeInMillis) {
                if (lastNightUsage == null || t > lastNightUsage!!) lastNightUsage = t
            } else if (t in morningStart.timeInMillis..morningEnd.timeInMillis) {
                if (firstMorningUsage == null || t < firstMorningUsage!!) firstMorningUsage = t
            }
        }

        var sleepMinutes: Long? = null
        if (lastNightUsage != null && firstMorningUsage != null && firstMorningUsage!! > lastNightUsage!!) {
            val minutes = (firstMorningUsage!! - lastNightUsage!!) / 60000
            // Chặn giá trị vô lý (>16h hoặc <1h) — coi như không đủ tin cậy
            // để hiển thị, tốt hơn là hiện số sai lệch nặng.
            if (minutes in 60..960) sleepMinutes = minutes
        }

        return mapOf(
            "lastNightUsage" to lastNightUsage,
            "firstMorningUsage" to firstMorningUsage,
            "sleepMinutes" to sleepMinutes
        )
    }
}