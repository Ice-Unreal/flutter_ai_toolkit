// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../chat_view_model/chat_view_model_client.dart';
import '../../providers/interface/chat_message.dart';
import '../../styles/llm_chat_view_style.dart';
import '../../styles/llm_message_style.dart';
import '../jumping_dots_progress_indicator/jumping_dots_progress_indicator.dart';
import 'adaptive_copy_text.dart';
import 'hovering_buttons.dart';

/// A widget that displays an LLM (Language Model) message in a chat interface.
@immutable
class LlmMessageView extends StatelessWidget {
  /// Creates an [LlmMessageView].
  ///
  /// The [message] parameter is required and represents the LLM chat message to
  /// be displayed.
  const LlmMessageView(
    this.message, {
    this.isWelcomeMessage = false,
    super.key,
  });

  /// The LLM chat message to be displayed.
  final ChatMessage message;

  /// Whether the message is the welcome message.
  final bool isWelcomeMessage;

  @override
  Widget build(BuildContext context) => ChatViewModelClient(
    builder: (context, viewModel, child) {
      final text = message.text;
      final chatStyle = LlmChatViewStyle.resolve(viewModel.style);
      final llmStyle = LlmMessageStyle.resolve(chatStyle.llmMessageStyle);
      final messageWidthRatio = llmStyle.messageWidthRatio ?? 0.75;
      final messageFlex = (messageWidthRatio * 100).round();
      final spacerFlex = 100 - messageFlex;

      return Row(
        children: [
          Flexible(
            flex: messageFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        height: llmStyle.iconContainerHeight ?? 20,
                        width: llmStyle.iconContainerWidth ?? 20,
                        decoration: llmStyle.iconDecoration,
                        child: Icon(
                          llmStyle.icon,
                          color: llmStyle.iconColor,
                          size: llmStyle.iconSize ?? 12,
                        ),
                      ),
                    ),
                    HoveringButtons(
                      isUserMessage: false,
                      chatStyle: chatStyle,
                      clipboardText: text,
                      child: Container(
                        decoration: llmStyle.decoration,
                        margin: const EdgeInsets.only(left: 28),
                        padding: const EdgeInsets.all(8),
                        child:
                            text == null
                                ? SizedBox(
                                  width: 24,
                                  child: JumpingDotsProgressIndicator(
                                    fontSize: 24,
                                    color: chatStyle.progressIndicatorColor!,
                                  ),
                                )
                                : AdaptiveCopyText(
                                  clipboardText: text,
                                  chatStyle: chatStyle,
                                  child:
                                      isWelcomeMessage ||
                                              viewModel.responseBuilder == null
                                          ? MarkdownBody(
                                            data: text,
                                            selectable: false,
                                            styleSheet: llmStyle.markdownStyle,
                                          )
                                          : viewModel.responseBuilder!(
                                            context,
                                            text,
                                          ),
                                ),
                      ),
                    ),
                  ],
                ),
                if (text != null && !isWelcomeMessage)
                  Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Text(
                      viewModel.aiDescription,
                      style: llmStyle.markdownStyle?.p?.copyWith(
                        fontSize: (llmStyle.markdownStyle?.p?.fontSize ?? 14) * 0.8,
                      ) ?? const TextStyle(),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(flex: spacerFlex, child: const SizedBox()),
        ],
      );
    },
  );
}
