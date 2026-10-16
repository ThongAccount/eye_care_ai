import 'package:flutter/foundation.dart';

import '../services/ai_action_handler.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.isTyping = false,
    this.isAction = false,
    this.isConfirmation = false,
    this.pendingActions,
  });

  String text;
  final bool isUser;
  bool isTyping;
  // true = đây là bong bóng xác nhận AI vừa thao tác thật với app (ví dụ
  // "Đã hạ mục tiêu dùng điện thoại xuống 4 giờ/ngày"), hiển thị khác màu
  // với bong bóng trả lời thông thường để người dùng dễ nhận ra.
  final bool isAction;
  // true = đây là bong bóng "AI muốn thực hiện: ..." kèm 2 nút Đồng ý/Từ
  // chối — chỉ xuất hiện khi cài đặt "Hỏi trước khi AI tự thao tác" đang
  // bật (xem SettingsMoreProvider.aiConfirmBeforeActing). Sau khi người
  // dùng bấm 1 trong 2 nút, cờ này được set về false (xem
  // resolveConfirmation) để 2 nút biến mất, tránh bấm lại nhiều lần.
  bool isConfirmation;
  List<AiAction>? pendingActions;
}

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> messages = [];
  bool isTyping = false;
  bool greeted = false;

  void addMessage(ChatMessage message) {
    messages.add(message);
    notifyListeners();
  }

  void addUserMessage(String text) {
    messages.add(ChatMessage(text: text.trim(), isUser: true));
    notifyListeners();
  }

  void addBotMessage(String text) {
    messages.add(ChatMessage(text: text, isUser: false));
    notifyListeners();
  }

  // Nối thêm 1 mẩu chữ vào tin nhắn CUỐI CÙNG (dùng khi đang stream phản
  // hồi AI dần dần) — sửa TRỰC TIẾP trên object ChatMessage cuối thay vì
  // tạo tin nhắn mới mỗi lần, để không bị "nháy" danh sách liên tục.
  void appendToLastMessage(String delta) {
    if (messages.isEmpty) return;
    final last = messages.last;
    last.text += delta;
    last.isTyping = false;
    notifyListeners();
  }

  // Ghi đè toàn bộ nội dung tin nhắn CUỐI CÙNG — dùng khi stream đang chạy để
  // hiện phần text ĐÃ CHẮC CHẮN an toàn (không dính khối %%ACTION%%...%%END%%,
  // xem ChatScreen._send) và sau khi stream xong để xoá khối action khỏi văn
  // bản hiển thị — không cần tạo lại tin nhắn mới (giữ nguyên vị trí, tránh
  // giật list). `last.text` có thể NGẮN HƠN lần gọi trước nếu cleanedText sau
  // extract() ngắn hơn phần preview lúc đang stream — đó là hành vi đúng.
  void setLastMessageText(String text) {
    if (messages.isEmpty) return;
    final last = messages.last;
    last.text = text;
    // Text không rỗng (hoặc chuẩn bị không rỗng ngay sau) -> không còn ở
    // trạng thái "đang gõ..." (TypingDots) nữa, dù được gọi từ đường nào.
    if (text.isNotEmpty) last.isTyping = false;
    notifyListeners();
  }

  void addActionMessage(String text) {
    messages.add(ChatMessage(text: text, isUser: false, isAction: true));
    notifyListeners();
  }

  // Thêm bong bóng "AI muốn thực hiện: ..." kèm danh sách action đang chờ
  // xác nhận — dùng khi cài đặt "Hỏi trước khi AI tự thao tác" đang bật
  // (xem ChatScreen._send). [previewText] là mô tả bằng ngôn ngữ tự nhiên
  // đã được sinh sẵn (xem AiActionHandler.describeActions), [actions] là
  // danh sách gốc để execute() dùng khi người dùng bấm "Đồng ý".
  void addConfirmationMessage(String previewText, List<AiAction> actions) {
    messages.add(ChatMessage(
      text: previewText,
      isUser: false,
      isConfirmation: true,
      pendingActions: actions,
    ));
    notifyListeners();
  }

  // Đánh dấu 1 bong bóng xác nhận đã được xử lý (đồng ý/từ chối) — để 2 nút
  // biến mất khỏi bong bóng đó, tránh người dùng bấm lại nhiều lần cho cùng
  // 1 lô action.
  void resolveConfirmation(ChatMessage message) {
    message.isConfirmation = false;
    message.pendingActions = null;
    notifyListeners();
  }

  void setTyping(bool value) {
    isTyping = value;
    notifyListeners();
  }

  void markGreeted() {
    greeted = true;
    notifyListeners();
  }

  void clearMessages() {
    messages.clear();
    greeted = false;
    isTyping = false;
    notifyListeners();
  }

  // Số tin nhắn GẦN NHẤT gửi kèm lên API (không tính system prompt/contextInfo
  // — 2 thứ đó được EyeChatService ghép riêng, luôn có mặt đầy đủ). Chỉ giới
  // hạn phần GỬI LÊN NIM để hội thoại dài không kéo dài thời gian tới token
  // đầu tiên — KHÔNG xoá gì khỏi `messages` (UI vẫn hiện đủ, người dùng cuộn
  // lên vẫn thấy toàn bộ lịch sử như cũ). 16 tin nhắn ~ 8 lượt hỏi-đáp gần
  // nhất, đủ giữ mạch hội thoại cho use-case tư vấn ngắn của app này.
  static const int _maxHistoryMessagesForApi = 16;

  // Chuyển lịch sử hội thoại hiện có (bỏ qua bong bóng "đang gõ..."/action/
  // xác nhận) sang đúng định dạng Messages API để gửi lên EyeChatService,
  // giữ ngữ cảnh nhiều lượt hỏi-đáp thay vì chỉ gửi mỗi câu hỏi mới nhất —
  // nhưng CẮT BỚT nếu hội thoại đã dài, chỉ giữ [_maxHistoryMessagesForApi]
  // tin gần nhất. Bong bóng "isConfirmation" bị loại khỏi lịch sử gửi lên vì
  // nội dung của nó (danh sách gạch đầu dòng "AI muốn thực hiện: ...") không
  // phải văn phong hội thoại tự nhiên, dễ gây nhiễu ngữ cảnh cho model.
  List<Map<String, String>> toApiHistory() {
    final full = messages
        .where((m) => !m.isTyping && !m.isAction && !m.isConfirmation && m.text.trim().isNotEmpty)
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();
    if (full.length <= _maxHistoryMessagesForApi) return full;
    return full.sublist(full.length - _maxHistoryMessagesForApi);
  }
}