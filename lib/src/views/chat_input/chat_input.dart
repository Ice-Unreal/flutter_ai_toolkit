// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../chat_view_model/chat_view_model_client.dart';
import '../../providers/interface/attachments.dart';
import '../../providers/interface/chat_message.dart';
import '../../styles/chat_input_style.dart';
import '../../styles/llm_chat_view_style.dart';
import '../../utility.dart';
import '../chat_text_field.dart';
import 'attachments_action_bar.dart';
import 'attachments_view.dart';
import 'editing_indicator.dart';
import 'input_button.dart';
import 'input_state.dart';

/// A widget that provides a chat input interface with support for text input,
/// speech-to-text, and attachments.
@immutable
class ChatInput extends StatefulWidget {
  /// Creates a [ChatInput] widget.
  ///
  /// The [onSendMessage] parameters are required.
  ///
  /// [initialMessage] can be provided to pre-populate the input field.
  ///
  /// [inputTextController] can be provided to control the text input externally.
  ///
  /// [onCancelMessage] and [onCancelStt] are optional callbacks for cancelling
  /// message submission or speech-to-text translation respectively.
  ///
  /// [onStartRecording] is an optional callback triggered when recording starts.
  ///
  /// [onStopRecording] is an optional callback triggered when recording stops.
  ///
  /// [autofocus] determines whether the input field should automatically focus
  /// when the chat input is created. Defaults to true.
  const ChatInput({
    required this.onSendMessage,
    this.initialMessage,
    this.inputTextController,
    this.onCancelEdit,
    this.onCancelMessage,
    this.startRecording,
    this.stopRecording,
    this.autofocus = true,
    super.key,
  }) : assert(
         !(onCancelEdit != null && initialMessage == null),
         'Cannot cancel edit of a message if no initial message is provided',
       );

  /// Callback function triggered when a message is sent.
  ///
  /// Takes a [String] for the message text and [`Iterable<Attachment>`] for
  /// any attachments.
  final void Function(String, Iterable<Attachment>) onSendMessage;

  /// The initial message to populate the input field, if any.
  final ChatMessage? initialMessage;

  /// The text controller for the input field. If not provided, a new one will be created.
  final TextEditingController? inputTextController;

  /// Whether the input field should automatically focus when the chat input is created.
  ///
  /// Defaults to true.
  final bool autofocus;

  /// Optional callback function to cancel an ongoing edit of a message, passed
  /// via [initialMessage], that has already received a response. To allow for a
  /// non-destructive edit, if the user cancels the editing of the message, we
  /// call [onCancelEdit] to revert to the original message and response.
  final void Function()? onCancelEdit;

  /// Optional callback function to cancel an ongoing message submission.
  final void Function()? onCancelMessage;

  /// Optional callback function triggered when recording starts.
  final Future<void> Function()? startRecording;

  /// Optional callback function triggered when recording stops.
  final Future<void> Function()? stopRecording;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  // Notes on the way focus works in this widget:
  // - we use a focus node to request focus when the input is submitted or
  //   cancelled
  // - we leave the text field enabled so that it never artifically loses focus
  //   (you can't have focus on a disabled widget)
  // - this means we're not taking back focus after a submission or a
  //   cancellation is complete from another widget in the app that might have
  //   it, e.g. if we attempted to take back focus in didUpdateWidget
  // - this also means that we don't need any complicated logic to request focus
  //   in didUpdateWidget only the first time after a submission or cancellation
  //   that would be required to keep from stealing focus from other widgets in
  //   the app
  // - also, if the user is submitting and they press Enter while inside the
  //   text field, we want to put the focus back in the text field but otherwise
  //   ignore the Enter key; it doesn't make sense for Enter to cancel - they
  //   can use the Cancel button for that.
  // - the reason we need to request focus in the onSubmitted function of the
  //   TextField is because apparently it gives up focus as part of its
  //   implementation somehow (just how is something to discover)
  // - the reason we need to request focus in the implementation of the separate
  //   submit/cancel button is because  clicking on another widget when the
  //   TextField is focused causes it to lose focus (as it should)
  final _focusNode = FocusNode();
  late final TextEditingController _textController;
  bool _isRecording = false;
  final _attachments = <Attachment>[];
  static const _minInputHeight = 48.0;
  static const _maxInputHeight = 144.0;

  @override
  void initState() {
    super.initState();
    _textController = widget.inputTextController ?? TextEditingController();
  }

  @override
  void didUpdateWidget(covariant ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMessage != null) {
      final newText = widget.initialMessage!.text ?? '';
      if (_textController.text != newText) {
        _textController.text = newText;
      }
      _attachments.clear();
      _attachments.addAll(widget.initialMessage!.attachments);
    }
  }

  @override
  void dispose() {
    if (widget.inputTextController == null) {
      _textController.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatViewModelClient(
    builder: (context, viewModel, child) {
      final chatStyle = LlmChatViewStyle.resolve(viewModel.style);
      final inputStyle = ChatInputStyle.resolve(
        viewModel.style?.chatInputStyle,
      );

      return Container(
        color: inputStyle.backgroundColor,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AttachmentsView(
              attachments: _attachments,
              onRemove: onRemoveAttachment,
            ),
            if (_attachments.isNotEmpty) const SizedBox(height: 6),
            ValueListenableBuilder(
              valueListenable: _textController,
              builder:
                  (context, value, child) => Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: AttachmentActionBar(
                          onAttachments: onAttachments,
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: widget.onCancelEdit != null ? 24 : 8,
                                bottom: 8,
                              ),
                              child: DecoratedBox(
                                decoration: inputStyle.decoration!,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: _minInputHeight,
                                    maxHeight: _maxInputHeight,
                                  ),
                                  child: SingleChildScrollView(
                                    child: ChatTextField(
                                      minLines: 1,
                                      maxLines: 1024,
                                      controller: _textController,
                                      autofocus: widget.autofocus,
                                      focusNode: _focusNode,
                                      textInputAction:
                                          isMobile
                                              ? TextInputAction.newline
                                              : TextInputAction.done,
                                      onSubmitted:
                                          _inputState ==
                                                  InputState.canSubmitPrompt
                                              ? (_) => onSubmitPrompt()
                                              : (_) =>
                                                  _focusNode.requestFocus(),
                                      style: inputStyle.textStyle!,
                                      hintText: inputStyle.hintText!,
                                      hintStyle: inputStyle.hintStyle!,
                                      hintPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child:
                                  widget.onCancelEdit != null
                                      ? EditingIndicator(
                                        onCancelEdit: widget.onCancelEdit!,
                                        cancelButtonStyle:
                                            chatStyle.cancelButtonStyle!,
                                      )
                                      : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: InputButton(
                          inputState: _inputState,
                          chatStyle: chatStyle,
                          onSubmitPrompt: onSubmitPrompt,
                          onCancelPrompt: onCancelPrompt,
                          onStartRecording: _onStartRecording,
                          onStopRecording: _onStopRecording,
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ),
      );
    },
  );

  InputState get _inputState {
    if (_isRecording) return InputState.isRecording;
    if (widget.onCancelMessage != null) return InputState.canCancelPrompt;
    if (_textController.text.trim().isEmpty &&
        widget.startRecording != null &&
        widget.stopRecording != null) {
      return InputState.canStt;
    }
    return InputState.canSubmitPrompt;
  }

  void onSubmitPrompt() {
    assert(_inputState == InputState.canSubmitPrompt);

    // the mobile vkb can still cause a submission even if there is no text
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    widget.onSendMessage(text, List.from(_attachments));
    _attachments.clear();
    _textController.clear();
    _focusNode.unfocus();
  }

  void onCancelPrompt() {
    assert(_inputState == InputState.canCancelPrompt);
    widget.onCancelMessage!();
    _focusNode.requestFocus();
  }

  Future<void> _onStartRecording() async {
    try {
      setState(() => _isRecording = true);
      await widget.startRecording?.call();
    } catch (e) {
      setState(() => _isRecording = false);
      rethrow;
    }
  }

  Future<void> _onStopRecording() async {
    try {
      // 停止录音的时候，先把状态改掉。
      // 因为stopRecording方法可能要等一会儿才能返回，不能干等着，否则用户会以为点击停止没有反应呢。
      setState(() => _isRecording = false);
      await widget.stopRecording?.call();
    } catch (e) {
      setState(() => _isRecording = false);
      rethrow;
    }
  }

  void onAttachments(Iterable<Attachment> attachments) =>
      setState(() => _attachments.addAll(attachments));

  void onRemoveAttachment(Attachment attachment) =>
      setState(() => _attachments.remove(attachment));
}
