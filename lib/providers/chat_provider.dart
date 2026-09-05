import 'package:flutter/foundation.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.isTyping = false,
    this.isAction = false,
  });

  String text;
  final bool isUser;
  bool isTyping;
  // true = đây là bong bóng xác nhận AI vừa thao tác thật với app (ví dụ
  // "Đã hạ mục tiêu dùng điện thoại xuống 4 giờ/ngày"), hiển thị khác màu
  // với bong bóng trả lời thông thường để người dùng dễ nhận ra.
  final bool isAction;
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

  // Chuyển lịch sử hội thoại hiện có (bỏ qua bong bóng "đang gõ..."/action)
  // sang đúng định dạng Messages API để gửi lên EyeChatService, giữ ngữ cảnh
  // nhiều lượt hỏi-đáp thay vì chỉ gửi mỗi câu hỏi mới nhất — nhưng CẮT BỚT
  // nếu hội thoại đã dài, chỉ giữ [_maxHistoryMessagesForApi] tin gần nhất.
  List<Map<String, String>> toApiHistory() {
    final full = messages
        .where((m) => !m.isTyping && !m.isAction && m.text.trim().isNotEmpty)
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();
    if (full.length <= _maxHistoryMessagesForApi) return full;
    return full.sublist(full.length - _maxHistoryMessagesForApi);
  }
}