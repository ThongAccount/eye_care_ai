package com.eyecare.eye_care_ai

import es.antonborri.home_widget.HomeWidgetProvider

// Receiver cụ thể cho widget màn hình chính. BẮT BUỘC phải là class cụ thể
// (concrete): Android khởi tạo receiver qua Class.newInstance() nên KHÔNG
// thể đăng ký thẳng class của package (abstract) trong Manifest — làm vậy
// gây crash InstantiationException ngay khi hệ thống bắn broadcast tới app
// (đã dính 3 crash liên tiếp trên OPPO CPH2461, Android 14).
class EyeWidgetProvider : HomeWidgetProvider()
