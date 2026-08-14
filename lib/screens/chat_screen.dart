import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../services/ai_action_handler.dart';
import '../services/eye_chat_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/formatted_chat_text.dart';
import '../widgets/shared_widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Chào 1 lần đầu tiên khi mở màn hình chat (không lặp lại giữa các lần
    // mở nếu đã chào rồi, nhờ cờ `greeted` sống trong ChatProvider).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chat = context.read<ChatProvider>();
      if (!chat.greeted) {
        final strings = context.read<LanguageProvider>().strings;
        chat.addBotMessage(strings.chatGreeting);
        chat.markGreeted();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  // Tóm tắt mục tiêu (target) hiện tại của người dùng thành vài dòng text
  // ngắn gọn, gửi kèm mỗi lượt hỏi để AI đề xuất số hợp lý (ví dụ biết mục
  // tiêu Phone Usage đang là 6 giờ thì mới hạ xuống 4 giờ được, chứ không
  // đoán mò) — xem cách dùng ở EyeChatService.sendMessageStream(contextInfo:).
  String _buildHabitContext(HabitProvider habits, bool isVi) {
    final buffer = StringBuffer();
    for (final habit in habits.habits) {
      if (habit.isComingSoon) continue;
      final unit = switch (habit.id) {
        'phone' || 'sleep' => isVi ? 'giờ/ngày' : 'hrs/day',
        'outdoor' => isVi ? 'phút/ngày' : 'min/day',
        'breaks' => isVi ? 'lần/ngày' : 'times/day',
        _ => habit.unit,
      };
      final decimals = habit.target == habit.target.roundToDouble() ? 0 : 1;
      buffer.writeln('- ${habit.title} (id: "${habit.id}"): mục tiêu hiện tại = ${habit.target.toStringAsFixed(decimals)} $unit');
    }
    return buffer.toString();
  }

  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _sending) return;

    final chat = context.read<ChatProvider>();
    final strings = context.read<LanguageProvider>().strings;

    _inputController.clear();
    chat.addUserMessage(text);
    _scrollToBottom();

    // Câu hỏi khớp ĐÚNG 1 trong 4 gợi ý nhanh (chatQuickPrompts) -> trả lời
    // ngay bằng câu trả lời soạn sẵn (chatResponses), KHÔNG gọi API — vừa
    // nhanh tức thì, vừa đỡ tốn quota/tiền gọi model cho đúng 4 câu cố định
    // mà app đã tự đề xuất sẵn cho người dùng bấm. Chỉ áp dụng khi khớp
    // NGUYÊN VĂN (kể cả khi người dùng tự gõ tay trùng y hệt gợi ý), còn lại
    // vẫn đi qua AI như bình thường.
    final cannedAnswer = strings.chatResponses[text];
    if (cannedAnswer != null) {
      chat.addBotMessage(cannedAnswer);
      _scrollToBottom();
      return;
    }

    setState(() => _sending = true);
    // Bong bóng trả lời của AI, bắt đầu ở trạng thái "đang gõ..." rồi được
    // nối chữ dần dần (appendToLastMessage) ngay khi từng mẩu chữ về tới —
    // đây là điều tạo ra hiệu ứng "gõ chữ" thay vì chờ xong mới hiện.
    chat.addMessage(ChatMessage(text: '', isUser: false, isTyping: true));
    _scrollToBottom();

    try {
      final history = chat.toApiHistory();
      final habits = context.read<HabitProvider>();
      final isVi = context.read<LanguageProvider>().isVietnamese;
      var gotAnyChunk = false;
      await for (final delta in EyeChatService.instance.sendMessageStream(
        history: history,
        contextInfo: _buildHabitContext(habits, isVi),
      )) {
        gotAnyChunk = true;
        chat.appendToLastMessage(delta);
        _scrollToBottom();
      }
      if (!gotAnyChunk) {
        chat.appendToLastMessage(strings.chatErrorGeneric);
      } else {
        // Model có thể đã chèn khối %%ACTION%%...%%END%% ở cuối câu trả lời
        // (xem system prompt trong eye_chat_service.dart) — tách nó ra khỏi
        // văn bản hiển thị rồi THỰC SỰ áp dụng thay đổi vào app.
        final result = AiActionHandler.extract(chat.messages.last.text);
        chat.setLastMessageText(result.cleanedText);
        if (result.actions.isNotEmpty) {
          final confirmations = await AiActionHandler.execute(
            result.actions,
            habits: habits,
            isVietnamese: isVi,
          );
          for (final line in confirmations) {
            chat.addActionMessage(line);
          }
          _scrollToBottom();
        }
      }
    } catch (e) {
      final message = e.toString();
      String friendly;
      if (message.contains('missing_api_key')) {
        friendly = strings.chatErrorMissingKey;
      } else if (message.contains('invalid_api_key')) {
        friendly = strings.chatErrorInvalidKey;
      } else if (message.contains('rate_limited')) {
        friendly = strings.chatErrorRateLimited;
      } else if (message.contains('network_error')) {
        friendly = strings.chatErrorNetwork;
      } else {
        friendly = strings.chatErrorGeneric;
      }
      chat.appendToLastMessage(friendly);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.read<LanguageProvider>().isVietnamese ? 'Quay lại' : 'Back',
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppTheme.gradientFor(primary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_outlined, size: 22, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.aiAssistant, style: Theme.of(context).textTheme.titleMedium),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        strings.online,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.success,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chat, _) {
                  if (chat.messages.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                      final message = chat.messages[index];
                      return _ChatBubble(message: message, isDark: isDark);
                    },
                  );
                },
              ),
            ),
            Consumer<ChatProvider>(
              builder: (context, chat, _) {
                // Gợi ý câu hỏi nhanh — chỉ hiện khi mới vào chat (chưa hỏi gì).
                final onlyGreeting = chat.messages.length <= 1;
                if (!onlyGreeting) return const SizedBox.shrink();
                return SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: strings.chatQuickPrompts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final prompt = strings.chatQuickPrompts[index];
                      return ActionChip(
                        label: Text(prompt, style: const TextStyle(fontSize: 13)),
                        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                        onPressed: _sending ? null : () => _send(prompt),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _ChatInputBar(
              controller: _inputController,
              focusNode: _inputFocus,
              hintText: strings.askAboutEyeHealth,
              sending: _sending,
              onSend: _send,
              primary: primary,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isDark});

  final ChatMessage message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isUser = message.isUser;

    // Bong bóng xác nhận AI vừa thao tác thật với app (đổi target, bật Focus
    // Mode...) — hiện dạng pill xanh lá nhạt, căn giữa, tách biệt hẳn khỏi
    // bong bóng chat thường để người dùng nhận ra ngay đây là 1 THAY ĐỔI
    // THẬT chứ không phải chỉ là câu trả lời bằng lời.
    if (message.isAction) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: isDark ? 0.16 : 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
          ),
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.success,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final bubbleColor = isUser
        ? null
        : (isDark ? AppColors.darkSurface : AppColors.surface);
    final textColor = isUser
        ? Colors.white
        : (isDark ? Colors.white : AppColors.textPrimary);

    Widget content;
    if (!isUser && message.isTyping && message.text.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: TypingDots(),
      );
    } else if (isUser) {
      content = Text(message.text, style: TextStyle(color: textColor, height: 1.4));
    } else {
      // AI trả lời có thể dùng **đậm**/*nghiêng* -> render đúng định dạng
      // thay vì hiện nguyên dấu * thô.
      content = FormattedChatText(
        text: message.text,
        style: TextStyle(color: textColor, height: 1.4, fontSize: 14.5),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isUser ? AppTheme.gradientFor(primary) : null,
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: content,
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.sending,
    required this.onSend,
    required this.primary,
    required this.isDark,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool sending;
  final ValueChanged<String> onSend;
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: sending ? null : onSend,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: sending ? null : () => onSend(controller.text),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppTheme.gradientFor(primary),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
