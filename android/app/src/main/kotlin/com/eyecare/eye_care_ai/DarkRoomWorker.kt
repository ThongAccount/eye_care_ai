package com.eyecare.eye_care_ai

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

// ============================================================================
// TẠI SAO FILE NÀY TỒN TẠI (đọc trước khi sửa gì ở đây):
//
// Tính năng "cảnh báo dùng điện thoại trong bóng tối" chạy NỀN ĐỊNH KỲ
// TRƯỚC ĐÂY được implement bằng package `workmanager` (Flutter) gọi vào 1
// Dart callback (dark_room_background_service.dart), callback đó lại gọi
// MethodChannel "eye_care_ai/usage_events" để hỏi "màn hình có đang bật
// không" (_isScreenOn) trước khi đọc cảm biến ánh sáng.
//
// BUG GỐC: MethodChannel đó CHỈ được đăng ký trong
// MainActivity.configureFlutterEngine() — tức là chỉ tồn tại trên
// FlutterEngine gắn liền với Activity đang mở. `workmanager` khi chạy nền
// lại tự tạo ra 1 FlutterEngine "headless" HOÀN TOÀN RIÊNG BIỆT để chạy
// callback Dart — FlutterEngine đó KHÔNG BAO GIỜ đi qua
// MainActivity.configureFlutterEngine(), nên kênh "isScreenOn" không tồn
// tại ở đó. Mọi lần gọi từ isolate nền đều ném MissingPluginException, bị
// code Dart nuốt im lặng (catch -> return true), khiến "màn hình có đang
// tắt không" LUÔN LUÔN trả về true bất kể thực tế. Kết quả: code cứ thế cố
// đọc cảm biến ánh sáng ngay cả khi máy đang khoá màn hình trong túi quần —
// mà Android trên phần lớn thiết bị KHÔNG gửi sự kiện cảm biến ánh sáng khi
// màn hình tắt (tiết kiệm pin) -> lux=null VĨNH VIỄN, dù task nền vẫn chạy
// đều đặn thật (đã xác nhận qua thông báo debug).
//
// FIX: bỏ hẳn đường đi qua Dart isolate nền cho tính năng NÀY. Worker này
// chạy 100% NATIVE KOTLIN, không cần FlutterEngine/MethodChannel nào cả —
// PowerManager.isInteractive() và SensorManager được gọi trực tiếp, đáng
// tin cậy tuyệt đối bất kể app có đang mở hay đã bị dọn sạch khỏi bộ nhớ.
// Được đăng ký 1 lần trong MainActivity.onCreate() (xem cuối file đó), lặp
// lại mỗi 15 phút bởi androidx.work.WorkManager gốc — package `workmanager`
// (Flutter) và file dark_room_background_service.dart giờ CHỈ còn tác dụng
// dọn dẹp task cũ (migration), không còn chạy logic thật nào nữa.
// ============================================================================
class DarkRoomWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    companion object {
        const val UNIQUE_WORK_NAME = "dark_room_native_periodic"

        private const val REAL_CHANNEL_ID = "dark_room_background_channel"
        private const val REAL_CHANNEL_NAME = "Cảnh báo bóng tối (nền)"
        private const val REAL_NOTIFICATION_ID = 1004

        private const val DEBUG_CHANNEL_ID = "dark_room_debug_channel"
        private const val DEBUG_CHANNEL_NAME = "Dark Room Debug (tạm thời)"
        private const val DEBUG_NOTIFICATION_ID = 9999

        // Cùng file + cùng tiền tố "flutter." mà package shared_preferences
        // (Flutter) dùng — để nếu sau này cần đọc lại từ phía Dart (ví dụ
        // hiển thị "lần cảnh báo gần nhất" trong Settings) thì đọc được luôn
        // giá trị này mà không cần đồng bộ 2 nơi lưu trữ khác nhau.
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_IN_DARK_SESSION = "flutter.pref_dark_bg_in_dark_session"

        private const val DARK_LUX_THRESHOLD = 10f

        // Đổi thành false trước khi phát hành bản chính thức cho người dùng
        // — cờ này chỉ để chẩn đoán tạm thời, thông báo debug xuất hiện mỗi
        // ~15 phút sẽ làm phiền người dùng thật nếu để quên bật.
        private const val DEBUG_LOGGING = true
    }

    override fun doWork(): Result {
        return try {
            val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            val screenOn = powerManager.isInteractive
            if (!screenOn) {
                // Màn hình đang tắt (máy trong túi/trên bàn) -> không phải
                // đang thật sự NHÌN màn hình. Reset session để lần bật màn
                // hình tiếp theo trong bóng tối vẫn được cảnh báo bình thường.
                prefs.edit().putBoolean(KEY_IN_DARK_SESSION, false).apply()
                if (DEBUG_LOGGING) showDebugNotification("screenOn=false -> bỏ qua")
                return Result.success()
            }

            val lux = readAmbientLuxOnceBlocking(timeoutMs = 5000)
            if (lux == null) {
                if (DEBUG_LOGGING) {
                    showDebugNotification("screenOn=true, lux=null — máy này không có cảm biến ánh sáng, hoặc không phản hồi trong 5s")
                }
                return Result.success()
            }

            if (lux >= DARK_LUX_THRESHOLD) {
                prefs.edit().putBoolean(KEY_IN_DARK_SESSION, false).apply()
                if (DEBUG_LOGGING) showDebugNotification("screenOn=true, lux=$lux (đủ sáng)")
                return Result.success()
            }

            // Đang tối + màn hình đang bật. Chỉ cảnh báo 1 LẦN cho mỗi ĐỢT
            // tối liên tục (không lặp lại mỗi 15 phút trong khi vẫn tối).
            val alreadyNotified = prefs.getBoolean(KEY_IN_DARK_SESSION, false)
            if (alreadyNotified) {
                if (DEBUG_LOGGING) showDebugNotification("lux=$lux (tối) nhưng đã cảnh báo đợt này rồi")
                return Result.success()
            }

            prefs.edit().putBoolean(KEY_IN_DARK_SESSION, true).apply()
            if (DEBUG_LOGGING) showDebugNotification("lux=$lux (tối) -> GỬI CẢNH BÁO THẬT")
            showRealDarkRoomNotification()
            Result.success()
        } catch (e: Exception) {
            // Không để lỗi làm WorkManager coi task thất bại rồi retry dồn
            // dập — bỏ qua, chờ lần kiểm tra kế tiếp sau 15 phút.
            if (DEBUG_LOGGING) showDebugNotification("LỖI khi chạy worker: ${e.message}")
            Result.success()
        }
    }

    // Đăng ký lắng nghe cảm biến ánh sáng, CHẶN THREAD HIỆN TẠI (worker đã
    // chạy trên background thread riêng của WorkManager, chặn ở đây an toàn,
    // không ảnh hưởng UI) tới khi có sự kiện đầu tiên hoặc hết timeout.
    private fun readAmbientLuxOnceBlocking(timeoutMs: Long): Float? {
        val sensorManager = applicationContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val lightSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT) ?: return null

        val latch = CountDownLatch(1)
        var result: Float? = null
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (event.values.isNotEmpty()) {
                    result = event.values[0]
                }
                latch.countDown()
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        sensorManager.registerListener(listener, lightSensor, SensorManager.SENSOR_DELAY_NORMAL)
        try {
            latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        } finally {
            sensorManager.unregisterListener(listener)
        }
        return result
    }

    private fun showRealDarkRoomNotification() {
        val nm = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(REAL_CHANNEL_ID, REAL_CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Cảnh báo dùng điện thoại trong bóng tối, kiểm tra định kỳ dù app đã đóng"
            }
            nm.createNotificationChannel(channel)
        }
        val notification = NotificationCompat.Builder(applicationContext, REAL_CHANNEL_ID)
            .setSmallIcon(applicationContext.applicationInfo.icon)
            .setContentTitle("🌙 Bạn đang dùng điện thoại trong bóng tối")
            .setContentText("Ánh sáng yếu khiến mắt phải điều tiết nhiều hơn, dễ gây mỏi mắt. Hãy bật đèn hoặc giảm độ sáng màn hình.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        nm.notify(REAL_NOTIFICATION_ID, notification)
    }

    private fun showDebugNotification(detail: String) {
        val nm = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(DEBUG_CHANNEL_ID, DEBUG_CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW).apply {
                description = "Ghi lại mỗi lần task nền dark-room được đánh thức, dùng để chẩn đoán"
            }
            nm.createNotificationChannel(channel)
        }
        val now = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
        val notification = NotificationCompat.Builder(applicationContext, DEBUG_CHANNEL_ID)
            .setSmallIcon(applicationContext.applicationInfo.icon)
            .setContentTitle("🔧 Debug (native): task chạy lúc $now")
            .setContentText(detail)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            // id cố định -> mỗi lần chạy ĐÈ LÊN thông báo debug cũ, tránh
            // spam kéo dài danh sách thông báo.
            .build()
        nm.notify(DEBUG_NOTIFICATION_ID, notification)
    }
}