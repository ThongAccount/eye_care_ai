package com.eyecare.eye_care_ai

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// ============================================================================
// LỊCH SỬ NGẮN GỌN (đọc trước khi sửa gì ở đây):
//
// v1: dùng package `workmanager` (Flutter) -> lux=null vĩnh viễn vì
//     MethodChannel không tồn tại trên FlutterEngine "headless" chạy nền.
// v2: chuyển hẳn sang native, worker này tự đăng ký cảm biến one-shot mỗi
//     15 phút -> VẪN lux=null khi app bị dọn khỏi bộ nhớ, vì nhiều máy
//     (MIUI/ColorOS/One UI...) không gửi sự kiện cảm biến cho app "không
//     đang hoạt động", dù task WorkManager vẫn được đánh thức đúng giờ và
//     màn hình đang bật thật.
// v3 (hiện tại): việc đọc lux thật chuyển hẳn sang DarkRoomForegroundService
//     — chạy liên tục với 1 thông báo ghim im lặng, được OS coi là "đang
//     dùng" nên không bị chặn cảm biến, dù app đã bị ẩn/kill hoàn toàn.
//     Worker này (WorkManager) giờ chỉ còn là WATCHDOG: mỗi 15 phút kiểm
//     tra xem service có đang sống không, chết thì khởi động lại — phòng
//     khi hiếm hoi OS diệt luôn cả foreground service.
// ============================================================================
class DarkRoomWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    companion object {
        const val UNIQUE_WORK_NAME = "dark_room_native_periodic"

        private const val DEBUG_CHANNEL_ID = "dark_room_debug_channel"
        private const val DEBUG_CHANNEL_NAME = "Dark Room Debug (tạm thời)"
        private const val DEBUG_NOTIFICATION_ID = 9999

        // Đổi thành true tạm thời nếu cần chẩn đoán lại việc watchdog có
        // chạy đúng lịch không; nhớ đổi lại false trước khi phát hành.
        private const val DEBUG_LOGGING = false
    }

    override fun doWork(): Result {
        return try {
            if (!DarkRoomForegroundService.isRunning) {
                if (DEBUG_LOGGING) showDebugNotification("service không chạy -> khởi động lại")
                val intent = Intent(applicationContext, DarkRoomForegroundService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    applicationContext.startForegroundService(intent)
                } else {
                    applicationContext.startService(intent)
                }
            } else if (DEBUG_LOGGING) {
                showDebugNotification("service đang chạy bình thường")
            }
            Result.success()
        } catch (e: Exception) {
            if (DEBUG_LOGGING) showDebugNotification("LỖI khi chạy watchdog: ${e.message}")
            Result.success()
        }
    }

    private fun showDebugNotification(detail: String) {
        val nm = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(DEBUG_CHANNEL_ID, DEBUG_CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW).apply {
                description = "Ghi lại mỗi lần watchdog dark-room được đánh thức, dùng để chẩn đoán"
            }
            nm.createNotificationChannel(channel)
        }
        val now = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
        val notification = NotificationCompat.Builder(applicationContext, DEBUG_CHANNEL_ID)
            .setSmallIcon(applicationContext.applicationInfo.icon)
            .setContentTitle("🔧 Debug watchdog: chạy lúc $now")
            .setContentText(detail)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        nm.notify(DEBUG_NOTIFICATION_ID, notification)
    }
}