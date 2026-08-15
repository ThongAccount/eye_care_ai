package com.eyecare.eye_care_ai

import android.annotation.SuppressLint
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Màn hình "gate" chặn app khác — khi hết thời gian dùng và người dùng mở
 * app bị chặn, native hiện overlay này PHỦ TRÊN app đó.
 *
 * - showTestOverlay(): preview (Settings -> Test) — tự đóng sau 4s.
 * - showGateOverlay(): gate THẬT — KHÔNG tự đóng; đóng khi người dùng rời
 *   app bị chặn (bấm Home / mở app khác) hoặc bấm nút "Đóng".
 * - Foreground watcher: poll UsageStatsManager.queryEvents mỗi [pollMs];
 *   khi phát hiện app bị chặn đang ở foreground VÀ gate đang bật → hiện
 *   overlay ngay (không đợi tick Dart 60s).
 *
 * ColorOS: quyền SYSTEM_ALERT_WINDOW phải được cấp THẬT. Nếu chưa,
 * addView ném WindowManager.BadTokenException → trả false, không crash.
 */
@SuppressLint("InflateParams")
class AppLockOverlayManager private constructor(private val context: Context) {

    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())

    private var overlayView: View? = null
    private var autoDismissRunnable: Runnable? = null

    // State của gate thật (có nên hiện không) — native giữ riêng, Dart chỉ
    // báo "hết budget" qua showGateOverlay; watcher tự theo dõi foreground.
    private val gateArmed = AtomicBoolean(false)

    // Danh sách app bị chặn (package names) — Dart set qua setBlockedPackages.
    private val blockedPackages = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()

    // Locale hiện tại của app (vi = true, en = false). Dart set qua
    // setLanguage khi khởi động / đổi ngôn ngữ; overlay dùng để chọn chuỗi.
    private var isVietnamese = true

    fun setLanguage(vi: Boolean) {
        isVietnamese = vi
        // Nếu overlay đang hiện, dựng lại với ngôn ngữ mới ngay.
        val current = overlayView ?: return
        val wasTest = testOverlayShown
        dismiss()
        if (wasTest) {
            showTestOverlay()
        } else {
            showGateOverlay()
        }
    }

    private var testOverlayShown = false

    private val watcherRunnable = object : Runnable {
        override fun run() {
            if (gateArmed.get()) checkForegroundAndShow()
            handler.postDelayed(this, POLL_MS)
        }
    }

    fun isShowing(): Boolean = overlayView != null

    /** Dart gọi khi hết budget — bật "vũ khí": từ giờ mở app bị chặn → gate. */
    fun armGate(blocked: List<String>) {
        blockedPackages.clear()
        blockedPackages.addAll(blocked)
        gateArmed.set(true)
        checkForegroundAndShow()
    }

    fun disarmGate() {
        gateArmed.set(false)
        dismiss()
    }

    fun setBlockedPackages(packages: List<String>) {
        blockedPackages.clear()
        blockedPackages.addAll(packages)
    }

    /** Preview (Settings -> Test): KHÔNG tự đóng — người dùng bấm "Đóng xem trước". */
    fun showTestOverlay(): Boolean {
        if (isShowing()) return true
        if (!android.provider.Settings.canDrawOverlays(context)) return false

        val (title, body, close) = if (isVietnamese) {
            Triple(
                "EyeCare AI — Xem trước hết giờ",
                "Chuyển sang app khác ngay — màn hình này sẽ che app đó.\n" +
                    "(Đây chỉ là bản xem trước. Màn hình thật sẽ hiện khi hết giờ dùng trong ngày.)",
                "Đóng xem trước"
            )
        } else {
            Triple(
                "EyeCare AI — Time up preview",
                "Switch to another app now — this gate will cover it.\n" +
                    "(This is the preview. The real gate appears when the daily limit runs out.)",
                "Close preview"
            )
        }
        val built = buildGateView(title = title, body = body, closeLabel = close) ?: return false

        val added = try {
            windowManager.addView(built, makeLayoutParams())
            true
        } catch (e: Exception) {
            false
        }
        if (!added) return false

        overlayView = built
        testOverlayShown = true
        return true
    }

    /** Gate THẬT khi hết budget — hiện ngay nếu đang ở app bị chặn, hoặc để
     *  watcher hiện khi người dùng chuyển sang app bị chặn. */
    fun showGateOverlay(): Boolean {
        if (isShowing()) return true
        if (!android.provider.Settings.canDrawOverlays(context)) return false

        val (title, body, close) = if (isVietnamese) {
            Triple(
                "Đã hết giờ dùng trong ngày",
                "Hạn mức dùng điện thoại hôm nay đã hết.\n" +
                    "Mở EyeCare AI để nghỉ mắt, hoặc quay lại vào ngày mai.",
                "Mở EyeCare AI"
            )
        } else {
            Triple(
                "Daily limit reached",
                "Your phone-usage budget for today is used up.\n" +
                    "Open EyeCare AI for a break, or come back tomorrow.",
                "Open EyeCare AI"
            )
        }
        val built = buildGateView(title = title, body = body, closeLabel = close) ?: return false

        val added = try {
            windowManager.addView(built, makeLayoutParams())
            true
        } catch (e: Exception) {
            false
        }
        if (!added) return false

        overlayView = built
        testOverlayShown = false
        return true
    }

    // --- Watcher internals ---

    private fun checkForegroundAndShow() {
        if (isShowing()) return
        val fg = currentForegroundPackage() ?: return
        if (fg in blockedPackages) {
            showGateOverlay()
        }
    }

    private fun currentForegroundPackage(): String? {
        val um = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = end - 2000
        val events: UsageEvents = um.queryEvents(start, end)
        val event = UsageEvents.Event()
        var lastPkg: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            ) {
                lastPkg = event.packageName
            }
        }
        return lastPkg
    }

    private fun buildGateView(title: String, body: String, closeLabel: String): View? {
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.argb(235, 13, 71, 161)) // AppColors.primaryBlue
            setPadding(48, 48, 48, 48)
        }
        val titleTv = TextView(context).apply {
            text = title
            setTextColor(Color.WHITE)
            textSize = 24f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        val bodyTv = TextView(context).apply {
            text = body
            setTextColor(Color.argb(220, 255, 255, 255))
            textSize = 16f
            gravity = Gravity.CENTER
        }
        val closeBtn = Button(context).apply {
            text = closeLabel
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.TRANSPARENT)
            textSize = 15f
            setOnClickListener { dismiss() }
        }
        root.addView(titleTv, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        root.addView(bodyTv, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).also {
            (root.getChildAt(1).layoutParams as LinearLayout.LayoutParams).topMargin = 24
        }
        root.addView(closeBtn, LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).also {
            (root.getChildAt(2).layoutParams as LinearLayout.LayoutParams).topMargin = 32
        }
        return root
    }

    private fun makeLayoutParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START }
    }

    fun dismiss() {
        autoDismissRunnable?.let { handler.removeCallbacks(it) }
        autoDismissRunnable = null
        overlayView?.let { windowManager.removeView(it) }
        overlayView = null
        testOverlayShown = false
    }

    /** MainActivity khởi động watcher 1 lần. */
    fun startWatcher() {
        handler.post(watcherRunnable)
    }

    fun stopWatcher() {
        handler.removeCallbacks(watcherRunnable)
        disarmGate()
    }

    companion object {
        private const val POLL_MS = 3000L
        private var instance: AppLockOverlayManager? = null
        fun get(context: Context): AppLockOverlayManager =
            instance ?: AppLockOverlayManager(context.applicationContext).also { instance = it }
    }
}