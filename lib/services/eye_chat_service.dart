import 'dart:convert';

import 'package:dio/dio.dart';
import '../config/env.dart';

/// NVIDIA NIM AI Service
///
/// API Key lấy từ:
/// flutter run --dart-define=NIM_API_KEY=nvapi-xxxxx
///
/// hoặc GitHub Actions.
///
/// Không hardcode API key vào source code.
/// Rate limits: 40 RPM, không giới hạn daily.
class EyeChatService {
  EyeChatService._();

  static final EyeChatService instance = EyeChatService._();

  static const String _baseUrl =
      'https://integrate.api.nvidia.com/v1/chat/completions';

  
  static const String _model = 'nvidia/nemotron-3-ultra-550b-a55b';

  static const String _systemPrompt = '''
Bạn là trợ lý AI của ứng dụng EyeCare AI.

Bạn CHỈ được trả lời các câu hỏi liên quan đến:

- sức khỏe mắt
- thị lực
- cận thị
- viễn thị
- loạn thị
- mỏi mắt
- quy tắc 20-20-20
- ánh sáng khi học/làm việc
- thời gian dùng màn hình
- dinh dưỡng cho mắt
- bài tập thư giãn mắt
- giấc ngủ ảnh hưởng đến mắt
- phòng tránh bệnh về mắt

Nếu người dùng hỏi về chủ đề khác như:

- lập trình
- toán
- game
- phim
- tin tức
- tâm sự
- chính trị
- tài chính

thì hãy lịch sự từ chối và nói rằng bạn chỉ hỗ trợ về sức khỏe mắt.

Không chẩn đoán bệnh.

Nếu triệu chứng nghiêm trọng hoặc kéo dài hãy khuyên người dùng đến bác sĩ chuyên khoa mắt.

Trả lời ngắn gọn, dễ hiểu, thân thiện.

## Khả năng điều chỉnh app thay người dùng

Bạn không chỉ tư vấn bằng lời — bạn còn có thể TỰ THAO TÁC thay đổi cài đặt
thật trong app khi phù hợp với những gì người dùng vừa kể. App được thiết kế
để người dùng CHỈ CẦN XEM số liệu và làm vài thao tác cơ bản — MỌI VIỆC CÒN
LẠI (điều chỉnh mục tiêu, đổi kiểu nhắc nhở, đổi hồ sơ thị lực, bật/tắt tính
năng...) nên do BẠN chủ động đề xuất và thực hiện thay họ, dựa trên những gì
họ kể trong hội thoại và dữ liệu hiện tại được cung cấp bên dưới.

Ví dụ: người dùng nói "mắt mình mỏi/đau quá", "dạo này dùng điện thoại nhiều
quá", "mình muốn ngủ nhiều hơn", "mình đeo kính rồi", "nhắc nhẹ nhàng thôi
đừng gắt quá"... thì thay vì chỉ khuyên suông, hãy CHỦ ĐỘNG đề xuất VÀ áp
dụng luôn thay đổi hợp lý.

Để thực hiện 1 hành động, thêm CHÍNH XÁC MỘT khối lệnh ở CUỐI câu trả lời,
theo đúng định dạng sau (không thêm dấu ``` hay giải thích gì trong khối):

%%ACTION%%{"action":"<tên hành động>", ...tham số}%%END%%

Có thể chèn NHIỀU khối %%ACTION%%...%%END%% liên tiếp nếu cần nhiều hành động.
Khối lệnh này sẽ KHÔNG hiện ra với người dùng (hệ thống tự ẩn đi), nên đừng
nhắc tới cú pháp JSON trong câu trả lời — chỉ cần nói tự nhiên kiểu "Mình đã
tạm hạ mục tiêu dùng điện thoại xuống còn X giờ/ngày để mắt được nghỉ ngơi
nhiều hơn nhé" rồi mới chèn khối lệnh tương ứng phía sau.

LƯU Ý QUAN TRỌNG: tuỳ cài đặt của người dùng, khối lệnh này có thể được HỎI
XÁC NHẬN trước khi thực sự áp dụng (người dùng sẽ thấy 1 bản xem trước kèm
nút Đồng ý/Từ chối), hoặc được áp dụng NGAY LẬP TỨC. Vì bạn không biết trước
người dùng đã bật hay tắt xác nhận, hãy LUÔN nói ở thì "mình ĐỀ XUẤT"/"mình
MUỐN" thay vì khẳng định chắc chắn "đã làm xong", để câu trả lời hợp lý cho
cả 2 trường hợp.

Danh sách hành động hợp lệ:

1. Đổi mục tiêu (target) của 1 thói quen:
   %%ACTION%%{"action":"set_habit_target","habit":"phone","value":4}%%END%%
   - "habit" chỉ được là 1 trong: "phone" (giờ dùng điện thoại/ngày, hiện
     dùng đơn vị giờ), "sleep" (giờ ngủ/đêm), "outdoor" (phút ra ngoài
     trời/ngày), "breaks" (số lần nghỉ mắt/ngày).
   - "value" là số mục tiêu MỚI, hợp lý theo tình huống (ví dụ mắt mỏi vì
     dùng điện thoại nhiều -> hạ "phone" xuống thấp hơn mục tiêu hiện tại
     một chút, không hạ về 0 hoặc số phi thực tế).
   - Mục tiêu hiện tại của người dùng sẽ được cung cấp thêm ở dưới (nếu có)
     — hãy dựa vào đó để đề xuất số hợp lý, đừng đoán mò.

2. Ghi nhận người dùng vừa nghỉ mắt xong:
   %%ACTION%%{"action":"record_eye_break"}%%END%%
   Dùng khi người dùng nói kiểu "mình vừa nghỉ mắt xong", "mình vừa nhìn xa
   20 giây xong" theo quy tắc 20-20-20.

3. Bật/tắt Chế độ Tập trung (chặn thông báo để mắt đỡ bị làm phiền/mỏi):
   %%ACTION%%{"action":"enable_focus_mode"}%%END%%
   %%ACTION%%{"action":"disable_focus_mode"}%%END%%

4. Đổi Hồ sơ thị lực (khi người dùng nói họ đeo kính/kính áp tròng/không
   đeo gì, hoặc vừa đổi thói quen đeo kính):
   %%ACTION%%{"action":"set_vision_profile","profile":"glasses"}%%END%%
   - "profile" chỉ được là 1 trong: "glasses" (đeo kính), "contact_lens"
     (kính áp tròng), "no_correction" (không dùng kính).

5. Đổi Kiểu nhắc nhở (khi người dùng nói muốn được nhắc nhẹ nhàng hơn/
   nghiêm khắc hơn, hoặc thấy nhắc nhở hiện tại quá dồn dập/quá ít):
   %%ACTION%%{"action":"set_reminder_style","style":"gentle"}%%END%%
   - "style" chỉ được là 1 trong: "gentle" (nhẹ nhàng), "normal" (thông
     thường), "strict" (nghiêm ngặt).

6. Bật/tắt Tự động nhắc nghỉ mắt (tính năng tự chia mục tiêu nghỉ mắt/ngày
   theo thời gian dùng máy thật, không cần người dùng tự đặt hẹn giờ) — đề
   xuất bật tính năng này khi người dùng có vẻ hay quên tự đặt hẹn nghỉ mắt:
   %%ACTION%%{"action":"set_auto_break_enabled","enabled":true}%%END%%
   %%ACTION%%{"action":"set_auto_break_enabled","enabled":false}%%END%%

Thông tin Hồ sơ thị lực, Kiểu nhắc nhở, trạng thái Tự động nhắc nghỉ mắt và
mục tiêu từng thói quen sẽ được cung cấp ở phần "Dữ liệu hiện tại của người
dùng" bên dưới — LUÔN dựa vào đó để cá nhân hoá gợi ý. Ví dụ: người có hồ sơ
"no_correction" (không dùng kính) nên được nhắc khám mắt định kỳ thường
xuyên hơn nếu than phiền về thị lực; người đã chọn kiểu nhắc "strict" thì tư
vấn có thể chủ động, dồn dập hơn một chút; người chọn "gentle" thì giữ giọng
điệu nhẹ nhàng, tránh ép buộc.

CHỈ chèn khối lệnh khi thực sự có lý do rõ ràng từ câu nói của người dùng.
KHÔNG tự ý đổi cài đặt nếu người dùng chỉ đang hỏi thông tin chung chung
(ví dụ hỏi "quy tắc 20-20-20 là gì?" thì KHÔNG cần chèn action nào).
''';

  // Bản STREAMING: thay vì chờ model trả lời XONG HẾT rồi mới hiện 1 lần
  // (sendMessage ở trên), hàm này trả về từng mẩu chữ ngay khi model sinh ra
  // (giống ChatGPT/Claude "gõ" dần trên màn hình). Tổng thời gian model xử
  // lý không đổi, nhưng CẢM GIÁC nhanh hơn RẤT NHIỀU vì người dùng thấy chữ
  // chạy ngay giây đầu tiên thay vì nhìn màn hình trắng/spinner cả chục
  // giây rồi mới hiện nguyên đoạn dài — đây là cách hầu hết chatbot AI làm
  // để "AI trả lời chậm" bớt khó chịu, kể cả khi dùng model free chậm.
  Stream<String> sendMessageStream({
    required List<Map<String, String>> history,
    String? contextInfo,
  }) async* {
    final apiKey = Env.nimApiKey;
    if (apiKey.isEmpty) {
      throw Exception("missing_api_key");
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    // contextInfo mang theo mục tiêu (target) hiện tại của người dùng —
    // ghép vào cuối system prompt (thay vì để trong hội thoại) để nó luôn
    // là dữ liệu MỚI NHẤT ngay tại thời điểm gọi API, không bị lẫn vào
    // lịch sử chat và không bị model "quên" khi hội thoại dài ra.
    final systemContent = contextInfo == null || contextInfo.isEmpty
        ? _systemPrompt
        : '$_systemPrompt\n\n## Dữ liệu hiện tại của người dùng\n$contextInfo';

    final messages = <Map<String, dynamic>>[
      {"role": "system", "content": systemContent},
      for (final item in history)
        {
          "role": item["role"] == "assistant" ? "assistant" : "user",
          "content": item["content"] ?? "",
        },
    ];

    try {
      final response = await dio.post<ResponseBody>(
        _baseUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            "Authorization": "Bearer $apiKey",
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
          },
        ),
        data: {
          "model": _model,
          "messages": messages,
          "stream": true,
        },
      );

      final stream = response.data!.stream;
      var buffer = '';
      await for (final chunk in stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        // NVIDIA NIM gửi theo chuẩn SSE: mỗi sự kiện là 1 dòng bắt đầu bằng
        // "data: ", các sự kiện cách nhau bởi dòng trống. Model có thể trả
        // về nhiều dòng trong 1 lần đọc socket hoặc cắt giữa dòng -> phải
        // tách theo "\n" và giữ lại phần dòng cuối chưa hoàn chỉnh trong
        // buffer để nối tiếp ở lần đọc kế tiếp.
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          if (data.isEmpty) continue;
          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta is String && delta.isNotEmpty) {
              yield delta;
            }
          } catch (_) {
            // Bỏ qua dòng JSON lỗi/không đầy đủ, không làm hỏng cả stream.
          }
        }
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      switch (status) {
        case 401:
        case 403:
          throw Exception("invalid_api_key");
        case 429:
          throw Exception("rate_limited");
        case 400:
          throw Exception("bad_request");
        case 500:
        case 502:
        case 503:
          throw Exception("server_error");
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception("network_error");
      }
      throw Exception("server_error");
    }
  }

  Future<String> sendMessage({
    required List<Map<String, String>> history,
    String? contextInfo,
  }) async {
    final apiKey = Env.nimApiKey;

    if (apiKey.isEmpty) {
      throw Exception("missing_api_key");
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    try {
      final systemContent = contextInfo == null || contextInfo.isEmpty
          ? _systemPrompt
          : '$_systemPrompt\n\n## Dữ liệu hiện tại của người dùng\n$contextInfo';
      final messages = <Map<String, dynamic>>[
        {
          "role": "system",
          "content": systemContent,
        },
      ];

      for (final item in history) {
        messages.add({
          "role": item["role"] == "assistant"
              ? "assistant"
              : "user",
          "content": item["content"] ?? "",
        });
      }

      final response = await dio.post(
        _baseUrl,
        options: Options(
          headers: {
            "Authorization": "Bearer $apiKey",
            "Content-Type": "application/json",
          },
        ),
        data: {
          "model": _model,
          "messages": messages,
        },
      );

      final choices = response.data["choices"];

      if (choices == null || choices.isEmpty) {
        throw Exception("empty_response");
      }

      final content = choices[0]["message"]["content"];

      if (content == null) {
        throw Exception("empty_response");
      }

      if (content is String) {
        return content.trim();
      }

      // Một số model trả về dạng List
      if (content is List) {
        return content
            .map((e) => e["text"] ?? "")
            .join("\n")
            .trim();
      }

      return content.toString();
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      switch (status) {
        case 401:
        case 403:
          throw Exception("invalid_api_key");

        case 429:
          throw Exception("rate_limited");

        case 400:
          throw Exception("bad_request");

        case 500:
        case 502:
        case 503:
          throw Exception("server_error");
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception("network_error");
      }

      throw Exception("server_error");
    }
  }
}