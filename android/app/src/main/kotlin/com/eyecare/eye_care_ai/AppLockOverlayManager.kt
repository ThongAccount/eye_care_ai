package com.eyecare.eye_care_ai

import android.annotation.SuppressLint
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

/**
 * Màn hình "gate" chặn app khác — PHIÊN BẢN TEST (preview).
 *
 * Phase 1 thật sự: khi hết thời gian dùng và người dùng mở app bị chặn,
 * native hiện overlay này PHỦ TRÊN app đó. Bản test này chỉ cần người dùng
 * bấm nút trong Settings để chứng minh "Always on top" hoạt động (ColorOS
 * hay từ chối ngầm), KHÔNG cần đợi hết budget.
 *
 * Ghi chú ColorOS: quyền SYSTEM_ALERT_WINDOW phải được cấp THẬT trong
 * Settings -> Apps -> đặc quyền -> Hiển thị trên màn hình. Nếu chưa cấp,
 * addView sẽ ném WindowManager.BadTokenException ngay lập tức.
 */
@SuppressLint("InflateParams")
class AppLockOverlayManager private constructor(private val context: Context) {

    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())

    private var overlayView: View? = null
    private var autoDismissRunnable: Runnable? = null

    fun isShowing(): Boolean = overlayView != null

    /**
     * Hiện overlay test toàn màn hình. Tự đóng sau [durationMs] hoặc khi bấm
     * "Đóng". Trả về true nếu hiện được (đã có quyền overlay).
     */
    @SuppressLint("SetTextI18n")
    fun showTestOverlay(durationMs: Long = 4000L): Boolean {
        if (isShowing()) return true
        if (!android.provider.Settings.canDrawOverlays(context)) return false

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START

        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.argb(230, 13, 71, 161)) // AppColors.primaryBlue
            setPadding(48, 48, 48, 48)
        }

        val title = TextView(context).apply {
            text = "EyeCare AI — Time up preview"
            setTextColor(Color.WHITE)
            textSize = 24f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        val body = TextView(context).apply {
            text = "Switch to another app now — this gate will cover it.\n" +
                "(This is the preview. The real gate appears when the daily limit runs out.)"
            setTextColor(Color.argb(220, 255, 255, 255))
            textSize = 16f
            gravity = Gravity.CENTER
        }
        val closeBtn = Button(context).apply {
            text = "Close preview"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.TRANSPARENT)
            textSize = 15f
            setOnClickListener { dismiss() }
        }

        root.addView(title, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        root.addView(
            body,
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).also {
            (root.getChildAt(1).layoutParams as LinearLayout.LayoutParams).topMargin = 24
        }
        root.addView(closeBtn, LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).also {
            (root.getChildAt(2).layoutParams as LinearLayout.LayoutParams).topMargin = 32
        }

        return try {
            windowManager.addView(root, params)
            overlayView = root
            autoDismissRunnable = Runnable { dismiss() }
            handler.postDelayed(autoDismissRunnable!!, durationMs)
            true
        } catch (e: Exception) {
            overlayView = null
            false
        }
    }

    fun dismiss() {
        autoDismissRunnable?.let { handler.removeCallbacks(it) }
        autoDismissRunnable = null
        overlayView?.let { windowManager.removeView(it) }
        overlayView = null
    }

    companion object {
        private var instance: AppLockOverlayManager? = null
        fun get(context: Context): AppLockOverlayManager =
            instance ?: AppLockOverlayManager(context.applicationContext).also { instance = it }
    }
}