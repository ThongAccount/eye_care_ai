package com.eyecare.eye_care_ai

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Kiểm tra NỀN: khi thời gian màn hình hôm nay vượt mục tiêu "Phone Usage"
 * thì nhắc người bảo hộ.
 *
 * Chạy HOÀN TOÀN NATIVE (WorkManager) — lý do giống DarkRoomWorker.kt:
 * isolate nền của WorkManager không đi qua MainActivity.configureFlutterEngine()
 * nên không gọi được MethodChannel riêng của app; worker này đọc thẳng
 * UsageStatsManager + SharedPreferences (cùng file mà plugin
 * shared_preferences của Flutter dùng, tiền tố "flutter.").
 *
 * Đường gửi:
 *  - Có endpoint HTTPS (người vận hành cấu hình lúc build bằng
 *    --dart-define=GUARDIAN_EMAIL_ENDPOINT=..., được Dart chép vào
 *    SharedPreferences lúc app khởi động) -> POST JSON tới endpoint đó.
 *  - Chưa có endpoint -> ghi trạng thái "đang chờ" (pref_guardian_pending_date)
 *    để app báo người dùng; đường lùi `mailto:` nằm trong Settings.
 *
 * KHÔNG có API key/secret nào trong mã nguồn — endpoint do người vận hành
 * cung cấp lúc build.
 */
class GuardianReminderWorker(appContext: Context, params: WorkerParameters) :
    CoroutineWorker(appContext, params) {

    companion object {
        const val UNIQUE_WORK_NAME = "guardian_reminder_periodic"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_EMAIL = "flutter.pref_guardian_email"
        private const val KEY_ENDPOINT = "flutter.pref_guardian_endpoint"
        private const val KEY_TARGET = "flutter.pref_habit_target_phone"
        private const val KEY_NOTIFIED_DATE = "flutter.pref_guardian_notified_date"
        private const val KEY_PENDING_DATE = "flutter.pref_guardian_pending_date"
    }

    private val prefs = applicationContext.getSharedPreferences(
        PREFS_NAME, Context.MODE_PRIVATE
    )

    override suspend fun doWork(): Result {
        return try {
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

            // Chưa cấu hình email người bảo hộ -> không làm gì (đây là opt-in).
            val guardianEmail = prefs.getString(KEY_EMAIL, null)?.trim() ?: ""
            if (guardianEmail.isEmpty()) return Result.success()

            // Mục tiêu thời gian dùng điện thoại (giờ) — cùng key với
            // HabitProvider.setHabitTarget('phone', ...).
            val targetHours = prefs.getFloat(KEY_TARGET, 6f).toDouble()
            if (targetHours <= 0.0) return Result.success()

            // Hôm nay đã gửi rồi -> không gửi lại (1 lần/ngày).
            if (prefs.getString(KEY_NOTIFIED_DATE, null) == today) return Result.success()

            val screenHours = ScreenTimeReader.readTodayScreenHours(applicationContext)
            if (screenHours <= targetHours) return Result.success()

            val endpoint = prefs.getString(KEY_ENDPOINT, null)?.trim() ?: ""
            if (!isValidEndpoint(endpoint)) {
                // Chưa cấu hình endpoint -> không thể gửi mail tự động từ nền.
                // Ghi trạng thái "đang chờ" để app nhắc người dùng lần mở kế
                // tiếp (đường lùi mailto: trong Settings).
                prefs.edit().putString(KEY_PENDING_DATE, today).apply()
                return Result.success()
            }

            if (postReminder(endpoint, guardianEmail, screenHours, targetHours, today)) {
                prefs.edit()
                    .putString(KEY_NOTIFIED_DATE, today)
                    .remove(KEY_PENDING_DATE)
                    .apply()
                Result.success()
            } else {
                // Lỗi mạng/endpoint -> thử lại ở lần chạy kế tiếp.
                Result.retry()
            }
        } catch (e: Exception) {
            Result.retry()
        }
    }

    // Chỉ chấp nhận endpoint HTTPS — email người bảo hộ là dữ liệu cá nhân.
    private fun isValidEndpoint(value: String): Boolean {
        return value.startsWith("https://") && value.length > "https://".length
    }

    private fun postReminder(
        endpoint: String,
        guardianEmail: String,
        screenHours: Double,
        targetHours: Double,
        today: String,
    ): Boolean {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15000
                readTimeout = 15000
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
            }

            val payload = JSONObject()
                .put("to", guardianEmail)
                .put("screenHours", screenHours)
                .put("targetHours", targetHours)
                .put("date", today)
                .put("source", "eyecare-ai-android")
            connection.outputStream.use {
                it.write(payload.toString().toByteArray(Charsets.UTF_8))
            }

            val code = connection.responseCode
            code in 200..299
        } catch (e: Exception) {
            false
        } finally {
            connection?.disconnect()
        }
    }
}
