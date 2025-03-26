import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../chat_input/chat_suggestion_view.dart';
import '../../styles/llm_chat_view_style.dart';
import '../../styles/llm_message_style.dart';
import '../../chat_view_model/chat_view_model_client.dart';

/// 一个显示欢迎信息的视图组件
/// 
/// 显示欢迎消息和建议提示，未来可以扩展添加更多欢迎信息
class WelcomeView extends StatelessWidget {
  /// 创建 [WelcomeView] 组件
  const WelcomeView({
    this.suggestions = const [],
    this.onSelectSuggestion,
    this.welcomeMessage,
    super.key,
  });

  /// 建议提示列表，默认为空列表
  final List<String> suggestions;

  /// 当用户选择建议时的回调函数
  final void Function(String)? onSelectSuggestion;

  /// 欢迎消息文本，支持markdown格式
  final String? welcomeMessage;

  @override
  Widget build(BuildContext context) => ChatViewModelClient(
    builder: (context, viewModel, child) {
      final chatStyle = LlmChatViewStyle.resolve(viewModel.style);
      final llmStyle = LlmMessageStyle.resolve(chatStyle.llmMessageStyle);

      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (welcomeMessage != null) ...[
                MarkdownBody(
                  data: welcomeMessage!,
                  selectable: false,
                  styleSheet: llmStyle.markdownStyle,
                ),
                const SizedBox(height: 24),
              ],
              if (suggestions.isNotEmpty)
                ChatSuggestionsView(
                  suggestions: suggestions,
                  onSelectSuggestion: onSelectSuggestion ?? (_) {},
                ),
            ],
          ),
        ),
      );
    },
  );
} 