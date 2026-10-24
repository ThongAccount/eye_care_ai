package com.eyecare.eye_care_ai

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import java.util.Calendar

/**
 * Đọc thời gian màn hình (screen-on time) của HÔM NAY từ UsageStatsManager.
 *
 * Tách ra khỏi DailySnapshotWorker để dùng lại cho GuardianReminderWorker
 * (cùng 1 cách tính, cùng 1 nguồn dữ liệu) — cần quyền Usage access mà
 * người dùng đã cấp cho tính năng "Phone Usage".
 */
object ScreenTimeReader {

    fun readTodayScreenHours(context: Context): Double {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
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
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            when (e.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND ->
                    foregroundStart[e.packageName] = e.timeStamp
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val fgAt = foregroundStart.remove(e.packageName)
                    if (fgAt != null) totalMs += (e.timeStamp - fgAt)
                }
            }
        }
        // App còn đang foreground tại thời điểm đọc -> cộng nốt phần còn dang dở.
        foregroundStart.values.forEach { totalMs += (end - it) }

        val elapsed = end - start
        val clamped = if (totalMs > elapsed) elapsed else totalMs
        return clamped / 3_600_000.0
    }
}
