package com.eyecare.eye_care_ai

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

// ============================================================================
// TẠI SAO FILE NÀY TỒN TẠI:
//
// DarkRoomWorker (WorkManager, đánh thức mỗi 15 phút) ĐÃ chạy đúng lịch kể cả
// khi app bị ẩn/kill (xác nhận qua thông báo debug) — nhưng khi nó gọi
// SensorManager.registerListener() lúc app không còn tiến trình "đang hoạt
// động", nhiều máy (MIUI/ColorOS/One UI...) coi app là "cached/background" và
// KHÔNG gửi sự kiện cảm biến, dù isInteractive() = true. Kết quả: lux=null
// vĩnh viễn ngay cả khi task nền chạy đều đặn thật.
//
// FIX: chuyển việc đọc cảm biến sang 1 Foreground Service có thông báo ghim
// (ưu tiên thấp, im lặng). Foreground service được Android coi là ứng dụng
// "đang hoạt động" nên KHÔNG bị áp các giới hạn cảm biến nền nói trên, dù màn
// hình chính/Activity đã bị đóng hay bị hệ thống dọn khỏi bộ nhớ. Service này
// đăng ký lắng nghe cảm biến ánh sáng LIÊN TỤC (không phải đọc 1 lần rồi bỏ),
// tự đánh giá ngưỡng tối mỗi khi có giá trị mới.
//
// DarkRoomWorker (WorkManager) giờ chỉ còn vai trò "watchdog": mỗi 15 phút
// kiểm tra xem service này có đang chạy không, nếu không thì khởi động lại —
// phòng trường hợp hiếm khi OS diệt luôn cả foreground service.
//
// CHECK CHỐNG BÁO NHẦM (úp màn hình xuống bàn): lux thấp không chỉ xảy ra
// trong phòng tối, mà còn khi máy úp mặt xuống bàn hoặc nhét trong túi —
// những lúc đó KHÔNG phải đang "nhìn màn hình trong bóng tối" nên không nên
// cảnh báo. CHỈ khi lux đã thấp mới đọc thêm cảm biến khoảng cách
// (proximity — cùng loại cảm biến giúp tắt màn hình lúc áp tai nghe điện
// thoại): nếu nó báo "có vật cản sát ngay trước mặt" (< 5cm, giá trị proximity
// = 0) thì gần như chắc chắn là mặt màn hình đang úp xuống 1 bề mặt, bỏ qua
// không cảnh báo. Lux đã đủ sáng thì KHÔNG đọc proximity nữa (đúng yêu cầu:
// chỉ check thêm khi nghi ngờ tối, sáng rồi thì thôi, đỡ tốn thêm 1 sensor).
// ============================================================================
class DarkRoomForegroundService : Service(), SensorEventListener {

    companion object {
        const val CHANNEL_ID = "dark_room_fg_channel"
        const val FG_NOTIFICATION_ID = 1005

        private const val REAL_CHANNEL_ID = "dark_room_background_channel"
        private const val REAL_CHANNEL_NAME = "Cảnh báo bóng tối (nền)"
        private const val REAL_NOTIFICATION_ID = 1004

        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_IN_DARK_SESSION = "flutter.pref_dark_bg_in_dark_session"
        private const val DARK_LUX_THRESHOLD = 10f

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private lateinit var sensorManager: SensorManager
    private var lightSensor: Sensor? = null
    private var proximitySensor: Sensor? = null

    // Giá trị proximity mới nhất đọc được (cm). null nếu máy không có cảm
    // biến này hoặc chưa có sự kiện nào -> khi đó KHÔNG chặn cảnh báo (thà
    // báo nhầm còn hơn bỏ sót, vì không phải máy nào cũng có proximity).
    @Volatile
    private var lastProximityCm: Float? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        lightSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT)
        proximitySensor = sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        startForeground(FG_NOTIFICATION_ID, buildForegroundNotification())
        lightSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
        // Đăng ký sẵn luôn, không đợi lux thấp mới đăng ký: proximity gần
        // như không tốn pin (chỉ bắn sự kiện khi giá trị đổi), và đăng ký
        // sẵn giúp có ngay giá trị mới nhất đúng lúc cần dùng, khỏi phải
        // chờ 1 nhịp "đăng ký -> đợi sự kiện đầu tiên" mỗi lần lux thấp.
        proximitySensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // START_STICKY: nếu hệ thống buộc phải diệt service để giải phóng
        // RAM, sẽ tự khởi động lại ngay khi có đủ tài nguyên (intent null).
        return START_STICKY
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_PROXIMITY -> {
                if (event.values.isNotEmpty()) lastProximityCm = event.values[0]
                return
            }
            Sensor.TYPE_LIGHT -> handleLightEvent(event)
        }
    }

    private fun handleLightEvent(event: SensorEvent) {
        if (event.values.isEmpty()) return
        val lux = event.values[0]

        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        if (lux >= DARK_LUX_THRESHOLD) {
            // Đủ sáng -> không cần xem proximity làm gì, chỉ reset session.
            prefs.edit().putBoolean(KEY_IN_DARK_SESSION, false).apply()
            return
        }

        // Lux thấp -> CHỈ ĐẾN ĐÂY mới kiểm tra thêm proximity, đúng như yêu
        // cầu: sáng rồi thì bỏ qua, nghi tối mới check thêm.
        val proximity = lastProximityCm
        val maxRange = proximitySensor?.maximumRange
        val isCovered = proximity != null && maxRange != null && proximity < maxRange
        if (isCovered) {
            // Có vật cản sát màn hình (úp bàn / trong túi) -> không phải
            // đang thật sự nhìn màn hình trong bóng tối, bỏ qua, và reset
            // session để nếu sau đó nhấc lên soi trong bóng tối thật vẫn
            // được cảnh báo bình thường.
            prefs.edit().putBoolean(KEY_IN_DARK_SESSION, false).apply()
            return
        }

        val alreadyNotified = prefs.getBoolean(KEY_IN_DARK_SESSION, false)
        if (alreadyNotified) return

        prefs.edit().putBoolean(KEY_IN_DARK_SESSION, true).apply()
        showRealDarkRoomNotification()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        isRunning = false
        sensorManager.unregisterListener(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildForegroundNotification(): android.app.Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Theo dõi ánh sáng môi trường",
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                description = "Cần chạy nền để cảnh báo dùng điện thoại trong bóng tối kể cả khi app đã đóng"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(applicationContext.applicationInfo.icon)
            .setContentTitle("EyeCare AI đang theo dõi ánh sáng")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun showRealDarkRoomNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
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
}