package com.eyecare.eye_care_ai

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Receiver cụ thể cho widget màn hình chính. Hai yêu cầu bắt buộc mà bản
// đầu tiên đều vi phạm (gây crash InstantiationException + lỗi biên dịch
// "does not implement abstract base class member"):
// 1. Phải là class cụ thể (concrete) — Android khởi tạo receiver qua
//    Class.newInstance().
// 2. Phải override onUpdate(..., widgetData) — đọc dữ liệu Dart đã đẩy qua
//    HomeWidget.saveWidgetData() và vẽ lại RemoteViews.
class EyeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.eye_widget_layout).apply {
                // Tap vào widget mở app.
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                setTextViewText(R.id.widget_title,
                    widgetData.getString("widget_title", null) ?: "EyeCare AI")
                setTextViewText(R.id.widget_score,
                    widgetData.getString("widget_score", null) ?: "--")
                setTextViewText(R.id.widget_streak,
                    widgetData.getString("widget_streak", null) ?: "--")
                setTextViewText(R.id.widget_next,
                    widgetData.getString("widget_next", null) ?: "--")
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
