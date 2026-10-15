package com.eyecare.eye_care_ai

import android.app.usage.UsageStatsManager
import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import java.text.SimpleDateFormat
import java.util.*

/**
 * Chạy ~23:55 mỗi ngày, HOÀN TOÀN NATIVE (không qua Dart) — lý do xem
 * DarkRoomWorker.kt: WorkManager spawn 1 FlutterEngine headless riêng biệt,
 * không đi qua MainActivity.configureFlutterEngine(), nên MethodChannel
 * "eye_care_ai/usage_events" không gọi được từ đây. Đọc thẳng
 * UsageStatsManager + file SharedPreferences (cùng file mà plugin
 * shared_preferences của Flutter dùng, prefix "flutter.") để tự tính và ghi
 * snapshot của HÔM NAY, không cần người dùng mở app.
 */
class DailySnapshotWorker(appContext: Context, params: WorkerParameters) :
    CoroutineWorker(appContext, params) {

    private val prefs = applicationContext.getSharedPreferences(
        "FlutterSharedPreferences", Context.MODE_PRIVATE
    )

    override suspend fun doWork(): Result {
        return try {
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

            // Nếu đã có snapshot hôm nay rồi (người dùng lỡ mở app trước
            // 23:55, refreshHabitsFromDevice() đã tự lưu) -> không ghi đè,
            // tránh đá văng số liệu mới hơn/chính xác hơn bằng số cũ hơn.
            if (prefs.contains("flutter.daily_snapshot_$today")) return Result.success()

            val screenHours = readTodayScreenHours()
            val sleepHours = readManualOrZeroSleepHours(today)
            val outdoorMinutes = readOutdoorMinutesToday(today)
            val breaksCount = readEyeBreaksToday(today)

            val score = computeScore(screenHours, sleepHours, breaksCount)

            prefs.edit()
                .putString(
                    "flutter.daily_snapshot_$today",
                    "$score|$screenHours|$sleepHours|$outdoorMinutes|$breaksCount"
                )
                .apply()

            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    private fun readTodayScreenHours(): Double {
        val usm = applicationContext.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val start = cal.timeInMillis
        val end = System.currentTimeMillis()

        val events = usm.queryEvents(start, end)
        val foregroundStart = HashMap<String, Long>()
        var totalMs = 0L
        val e = android.app.usage.UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            when (e.eventType) {
                android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND ->
                    foregroundStart[e.packageName] = e.timeStamp
                android.app.usage.UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val fgAt = foregroundStart.remove(e.packageName)
                    if (fgAt != null) totalMs += (e.timeStamp - fgAt)
                }
            }
        }
        // App còn đang foreground tại thời điểm chạy worker (hiếm, vì worker
        // chạy 23:55) -> cộng nốt phần còn dang dở.
        foregroundStart.values.forEach { totalMs += (end - it) }

        val elapsed = end - start
        val clamped = if (totalMs > elapsed) elapsed else totalMs
        return clamped / 3_600_000.0
    }

    // Ước lượng giấc ngủ THẬT (dựa vào UsageEvents đêm hôm trước) phức tạp
    // hơn nhiều so với đọc screen time trong ngày -> ở worker nền, chỉ dùng
    // số đã NHẬP TAY hôm nay nếu có (xem HabitProvider.setManualSleepHours),
    // không thì để 0 — Dart vẫn tự ước lượng lại đầy đủ khi người dùng mở
    // app lần sau, không mất dữ liệu, chỉ là snapshot lúc 23:55 thiếu phần
    // ngủ nếu họ không nhập tay.
    private fun readManualOrZeroSleepHours(today: String): Double {
        val savedDate = prefs.getString("flutter.pref_manual_sleep_date", null)
        if (savedDate != today) return 0.0
        return prefs.getFloat("flutter.pref_manual_sleep_hours", 0f).toDouble()
    }

    private fun readOutdoorMinutesToday(today: String): Double {
        val date = prefs.getString("flutter.outdoor_minutes_date", null)
        if (date != today) return 0.0
        return prefs.getFloat("flutter.outdoor_minutes_today", 0f).toDouble()
    }

    private fun readEyeBreaksToday(today: String): Int {
        val date = prefs.getString("flutter.eye_breaks_date", null)
        if (date != today) return 0
        return prefs.getInt("flutter.eye_breaks_today", 0)
    }

    // Bản RÚT GỌN của HabitProvider._updateHabitsCompletion() — chỉ tính
    // từ 3 yếu tố đọc được HOÀN TOÀN native (screen time, sleep, breaks).
    // Environment/Distance (cần mẫu cảm biến ánh sáng/camera rải rác trong
    // ngày) không tái tạo được ở một lần chạy 23:55 -> bỏ qua, giống cách
    // Dart xử lý khi 1 yếu tố null (average trên các yếu tố ĐANG CÓ, không
    // tính là 0, không phạt điểm oan).
    private fun computeScore(screenHours: Double, sleepHours: Double, breaks: Int): Int {
        val phoneTarget = prefs.getFloat("flutter.pref_habit_target_phone", 6f).toDouble()
        val sleepTarget = prefs.getFloat("flutter.pref_habit_target_sleep", 9f).toDouble()
        val breaksTarget = prefs.getFloat("flutter.pref_habit_target_breaks", 12f).toDouble()

        val screenScore: Double = if (phoneTarget <= 0) {
            100.0
        } else {
            val ratio = screenHours / phoneTarget
            if (ratio <= 1) (70 + (1 - ratio) * 30).coerceIn(0.0, 100.0)
            else (70 - (ratio - 1) * 70).coerceIn(0.0, 100.0)
        }

        val sleepScore: Double? = if (sleepTarget <= 0 || sleepHours <= 0) {
            null // chưa có dữ liệu ngủ hôm nay -> bỏ qua yếu tố này
        } else if (sleepHours < sleepTarget) {
            (sleepHours / sleepTarget * 100).coerceIn(0.0, 100.0)
        } else {
            val oversleepAt = sleepTarget * 1.25
            if (sleepHours <= oversleepAt) 100.0
            else (100 - (sleepHours - oversleepAt) / sleepTarget * 100).coerceIn(0.0, 100.0)
        }

        val breaksScore: Double = if (breaksTarget <= 0) 0.0 else (breaks / breaksTarget * 100).coerceIn(0.0, 100.0)

        val available = listOfNotNull(screenScore, sleepScore, breaksScore)
        return if (available.isEmpty()) 0 else available.average().toInt()
    }
}
