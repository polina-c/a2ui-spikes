import 'package:flutter/material.dart';

/// Where the current answer is: none in progress, being written, or paused.
enum ChatStatus { idle, streaming, paused }

/// The text field for the next message, with the buttons that send it and
/// control the current answer.
///
/// While an answer streams, the user can add context or pause. While it is
/// paused, the user can add context and resume, just resume, or cancel.
class ChatInputPane extends StatefulWidget {
  const ChatInputPane({
    super.key,
    required this.status,
    required this.onSend,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    this.initialText = '',
  });

  final ChatStatus status;

  /// Called with the trimmed text, after which the field is cleared.
  final ValueChanged<String> onSend;

  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  /// Text in the field when the pane first appears.
  final String initialText;

  @override
  State<ChatInputPane> createState() => _ChatInputPaneState();
}

class _ChatInputPaneState extends State<ChatInputPane> {
  late final TextEditingController _input = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Sends the message, or, while paused with nothing typed, resumes.
  ///
  /// Enter in the text field lands here, so it does what the main button
  /// does.
  void _send() {
    final String text = _input.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _input.clear();
    } else if (widget.status == ChatStatus.paused) {
      widget.onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ChatStatus status = widget.status;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: switch (status) {
                  ChatStatus.idle => 'Message',
                  ChatStatus.streaming => 'Add context, or pause',
                  ChatStatus.paused =>
                    'Add context and resume, just resume, or cancel',
                },
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (status == ChatStatus.streaming) ...[
            IconButton.filledTonal(
              tooltip: 'Pause',
              icon: const Icon(Icons.pause),
              onPressed: widget.onPause,
            ),
            const SizedBox(width: 8),
          ],
          if (status == ChatStatus.paused) ...[
            IconButton.filledTonal(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: widget.onCancel,
            ),
            const SizedBox(width: 8),
          ],
          // Rebuilt as the user types, because the main button depends on
          // whether there is anything to send.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _input,
            builder: (context, value, _) {
              final bool hasText = value.text.trim().isNotEmpty;
              if (status == ChatStatus.paused && !hasText) {
                return IconButton.filled(
                  tooltip: 'Resume',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: widget.onResume,
                );
              }
              return IconButton.filled(
                tooltip: status == ChatStatus.paused
                    ? 'Send and resume'
                    : 'Send',
                icon: const Icon(Icons.send),
                onPressed: hasText ? _send : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
