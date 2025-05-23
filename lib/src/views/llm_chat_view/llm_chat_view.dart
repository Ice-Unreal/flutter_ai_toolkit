// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../chat_view_model/chat_view_model.dart';
import '../../chat_view_model/chat_view_model_provider.dart';
import '../../dialogs/adaptive_dialog.dart';
import '../../dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';
import '../../llm_exception.dart';
import '../../providers/interface/attachments.dart';
import '../../providers/interface/chat_message.dart';
import '../../providers/interface/llm_provider.dart';
import '../../styles/llm_chat_view_style.dart';
import '../chat_history_view.dart';
import '../chat_input/chat_input.dart';
import '../response_builder.dart';
import 'llm_response.dart';
import 'welcome_view.dart';

/// A widget that displays a chat interface for interacting with an LLM
/// (Language Model).
///
/// This widget provides a complete chat interface, including a message history
/// view and an input area for sending new messages. It is configured with an
/// [LlmProvider] to manage the chat interactions.
///
/// Example usage:
/// ```dart
/// LlmChatView(
///   provider: MyLlmProvider(),
///   style: LlmChatViewStyle(
///     backgroundColor: Colors.white,
///     // ... other style properties
///   ),
/// )
/// ```
@immutable
class LlmChatView extends StatefulWidget {
  /// Creates an [LlmChatView] widget.
  ///
  /// This widget provides a chat interface for interacting with an LLM
  /// (Language Model). It requires an [LlmProvider] to manage the chat
  /// interactions and can be customized with various style and configuration
  /// options.
  ///
  /// - [provider]: The [LlmProvider] that manages the chat interactions.
  /// - [style]: Optional. The [LlmChatViewStyle] to customize the appearance of
  ///   the chat interface.
  /// - [responseBuilder]: Optional. A custom [ResponseBuilder] to handle the
  ///   display of LLM responses.
  /// - [messageSender]: Optional. A custom [LlmStreamGenerator] to handle the
  ///   sending of messages. If provided, this is used instead of the
  ///   `sendMessageStream` method of the provider. It's the responsibility of
  ///   the caller to ensure that the [messageSender] properly streams the
  ///   response. This is useful for augmenting the user's prompt with
  ///   additional information, in the case of prompt engineering or RAG. It's
  ///   also useful for simple logging.
  /// - [suggestions]: Optional. A list of predefined suggestions to display
  ///   when the chat history is empty. Defaults to an empty list.
  /// - [welcomeMessage]: Optional. A welcome message to display when the chat
  ///   is first opened.
  /// - [onCancelCallback]: Optional. The action to perform when the user
  ///   cancels a chat operation. By default, a snackbar is displayed with the
  ///   canceled message.
  /// - [onErrorCallback]: Optional. The action to perform when an
  ///   error occurs during a chat operation. By default, an alert dialog is
  ///   displayed with the error message.
  /// - [cancelMessage]: Optional. The message to display when the user cancels
  ///   a chat operation. Defaults to 'CANCEL'.
  /// - [errorMessage]: Optional. The message to display when an error occurs
  ///   during a chat operation. Defaults to 'ERROR'.
  /// - [autofocus]: Optional. Whether the input field should automatically focus when the chat view is created.
  ///   Defaults to true.
  /// - [aiDescription]: Optional. The description text that will be appended to each LLM message.
  ///   Defaults to "以上输出由AI生成，仅供参考。"
  /// - [startRecording]: Optional callback function triggered when recording starts.
  /// - [stopRecording]: Optional callback function triggered when recording stops.
  /// - [inputTextController]: Optional. The text controller for the input field. If not provided, a new one will be created.
  LlmChatView({
    required LlmProvider provider,
    LlmChatViewStyle? style,
    ResponseBuilder? responseBuilder,
    LlmStreamGenerator? messageSender,
    this.suggestions = const [],
    String? welcomeMessage,
    this.onCancelCallback,
    this.onErrorCallback,
    this.cancelMessage = 'CANCEL',
    this.errorMessage = 'ERROR',
    this.autofocus = true,
    String aiDescription = "以上输出由AI生成，仅供参考。",
    this.startRecording,
    this.stopRecording,
    this.inputTextController,
    super.key,
  }) : viewModel = ChatViewModel(
         provider: provider,
         responseBuilder: responseBuilder,
         messageSender: messageSender,
         style: style,
         welcomeMessage: welcomeMessage,
         aiDescription: aiDescription,
       );

  /// The list of suggestions to display in the chat interface.
  ///
  /// This list contains predefined suggestions that can be shown to the user
  /// when the chat history is empty. The user can select any of these
  /// suggestions to quickly start a conversation with the LLM.
  final List<String> suggestions;

  /// Whether the input field should automatically focus when the chat view is created.
  ///
  /// Defaults to true.
  final bool autofocus;

  /// The text controller for the input field. If not provided, a new one will be created.
  final TextEditingController? inputTextController;

  /// The view model containing the chat state and configuration.
  ///
  /// This [ChatViewModel] instance holds the LLM provider, transcript,
  /// response builder, welcome message, and LLM icon for the chat interface.
  /// It encapsulates the core data and functionality needed for the chat view.
  late final ChatViewModel viewModel;

  /// The action to perform when the user cancels a chat operation.
  ///
  /// By default, a snackbar is displayed with the canceled message.
  final void Function(BuildContext context)? onCancelCallback;

  /// The action to perform when an error occurs during a chat operation.
  ///
  /// By default, an alert dialog is displayed with the error message.
  final void Function(BuildContext context, LlmException error)?
  onErrorCallback;

  /// The text message to display when the user cancels a chat operation.
  ///
  /// Defaults to 'CANCEL'.
  final String cancelMessage;

  /// The text message to display when an error occurs during a chat operation.
  ///
  /// Defaults to 'ERROR'.
  final String errorMessage;

  /// Optional callback function triggered when recording starts.
  final Future<void> Function()? startRecording;

  /// Optional callback function triggered when recording stops.
  final Future<void> Function()? stopRecording;

  @override
  State<LlmChatView> createState() => _LlmChatViewState();
}

class _LlmChatViewState extends State<LlmChatView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  LlmResponse? _pendingPromptResponse;
  ChatMessage? _initialMessage;
  ChatMessage? _associatedResponse;

  @override
  void initState() {
    super.initState();
    widget.viewModel.provider.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    super.dispose();
    widget.viewModel.provider.removeListener(_onHistoryChanged);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // for AutomaticKeepAliveClientMixin

    final chatStyle = LlmChatViewStyle.resolve(widget.viewModel.style);
    return ListenableBuilder(
      listenable: widget.viewModel.provider,
      builder:
          (context, child) => ChatViewModelProvider(
            viewModel: widget.viewModel,
            child: Container(
              color: chatStyle.backgroundColor,
              width: double.infinity,
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ChatHistoryView(
                          // can only edit if we're not waiting on the LLM or if
                          // we're not already editing an LLM response
                          onEditMessage:
                              _pendingPromptResponse == null &&
                                      _associatedResponse == null
                                  ? _onEditMessage
                                  : null,
                        ),
                        if (widget.viewModel.provider.history.isEmpty)
                          WelcomeView(
                            suggestions: widget.suggestions,
                            onSelectSuggestion: _onSelectSuggestion,
                            welcomeMessage: widget.viewModel.welcomeMessage,
                          ),
                      ],
                    ),
                  ),
                  ChatInput(
                    initialMessage: _initialMessage,
                    onCancelEdit:
                        _associatedResponse != null ? _onCancelEdit : null,
                    onSendMessage: _onSendMessage,
                    onCancelMessage:
                        _pendingPromptResponse == null
                            ? null
                            : _onCancelMessage,
                    autofocus: widget.autofocus,
                    startRecording: widget.startRecording,
                    stopRecording: widget.stopRecording,
                    inputTextController: widget.inputTextController,
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _onSendMessage(
    String prompt,
    Iterable<Attachment> attachments,
  ) async {
    _initialMessage = null;
    _associatedResponse = null;

    // check the viewmodel for a user-provided message sender to use instead
    final sendMessageStream =
        widget.viewModel.messageSender ??
        widget.viewModel.provider.sendMessageStream;

    _pendingPromptResponse = LlmResponse(
      stream: sendMessageStream(prompt, attachments: attachments),
      // update during the streaming response input so that the end-user can see
      // the response as it streams in
      onUpdate: (_) => setState(() {}),
      onDone: _onPromptDone,
    );

    setState(() {});
  }

  void _onPromptDone(LlmException? error) {
    setState(() => _pendingPromptResponse = null);
    unawaited(_showLlmException(error));
  }

  void _onCancelMessage() => _pendingPromptResponse?.cancel();

  void _onEditMessage(ChatMessage message) {
    assert(_pendingPromptResponse == null);

    // remove the last llm message
    final history = widget.viewModel.provider.history.toList();
    assert(history.last.origin.isLlm);
    final llmMessage = history.removeLast();

    // remove the last user message
    assert(history.last.origin.isUser);
    final userMessage = history.removeLast();

    // set the history to the new history
    widget.viewModel.provider.history = history;

    // set the text  to the last userMessage to provide initial prompt and
    // attachments for the user to edit
    setState(() {
      _initialMessage = userMessage;
      _associatedResponse = llmMessage;
    });
  }

  Future<void> _showLlmException(LlmException? error) async {
    if (error == null) return;

    // stop from the progress from indicating in case there was a failure
    // before any text response happened; the progress indicator uses a null
    // text message to keep progressing. plus we don't want to just show an
    // empty LLM message.
    final llmMessage = widget.viewModel.provider.history.last;
    if (llmMessage.text == null) {
      llmMessage.append(
        error is LlmCancelException
            ? widget.cancelMessage
            : widget.errorMessage,
      );
    }

    switch (error) {
      case LlmCancelException():
        if (widget.onCancelCallback != null) {
          widget.onCancelCallback!(context);
        } else {
          AdaptiveSnackBar.show(context, 'LLM operation canceled by user');
        }
        break;
      case LlmFailureException():
      case LlmException():
        if (widget.onErrorCallback != null) {
          widget.onErrorCallback!(context, error);
        } else {
          await AdaptiveAlertDialog.show(
            context: context,
            content: Text(error.toString()),
            showOK: true,
          );
        }
    }
  }

  void _onSelectSuggestion(String suggestion) =>
      setState(() => _initialMessage = ChatMessage.user(suggestion, []));

  void _onHistoryChanged() {
    // if the history is cleared, clear the initial message
    if (widget.viewModel.provider.history.isEmpty) {
      setState(() {
        _initialMessage = null;
        _associatedResponse = null;
      });
    }
  }

  void _onCancelEdit() {
    assert(_initialMessage != null);
    assert(_associatedResponse != null);

    // add the original message and response back to the history
    final history = widget.viewModel.provider.history.toList();
    history.addAll([_initialMessage!, _associatedResponse!]);
    widget.viewModel.provider.history = history;

    // 清空输入框内容
    widget.inputTextController?.clear();

    setState(() {
      _initialMessage = null;
      _associatedResponse = null;
    });
  }
}
