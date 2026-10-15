// File NÀY CHỈ dùng cho máy phát triển cá nhân (flutter run ở chế độ debug)
// — KHÔNG được commit lên git với key thật bên trong (đã thêm đường dẫn
// này vào .gitignore, xem hướng dẫn cuối file). Khi build bản release qua
// GitHub Actions (xem .github/workflows/build-apk.yml), biến môi trường
// --dart-define=NIM_API_KEY=... vẫn được ưu tiên dùng trước (xem
// lib/config/env.dart) — file này chỉ là phương án dự phòng để bạn chạy
// `flutter run` bình thường (không cần gõ --dart-define mỗi lần) mà vẫn
// gọi được AI, không cần tải bản APK chính thức về chỉ để lấy key.
//
// CÁCH DÙNG:
// 1. Lấy API key NVIDIA NIM thật của bạn (hoặc key dev nội bộ team đang dùng).
// 2. Dán đè vào biến `localNimApiKey` bên dưới.
// 3. Lưu file — `flutter run`/`flutter run --debug` giờ tự dùng được AI.
//
// THÊM DÒNG SAU VÀO .gitignore CỦA PROJECT (nếu chưa có) ĐỂ KHÔNG LỠ COMMIT
// KEY THẬT LÊN GIT CÔNG KHAI:
//   lib/config/local_env.dart
//
// Nếu bạn làm việc nhóm: mỗi người tự tạo file này trên máy mình (không
// chia sẻ qua git), hoặc coi đây là file "mẫu" rỗng commit sẵn (giữ nguyên
// chuỗi rỗng bên dưới) rồi mỗi người tự điền key cục bộ và KHÔNG commit lại
// thay đổi của mình (git update-index --assume-unchanged đường dẫn file này
// cũng là một cách, tuỳ quy trình của team).
const String localNimApiKey = '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';