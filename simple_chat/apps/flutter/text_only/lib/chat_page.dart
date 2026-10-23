import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

import 'chat_controller.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.assistant});

  final Assistant assistant;

  static const String firstPrompt =
      "Hi, I am looking for a dishwasher. I am overwhelmed with choices and "
      "don't know where to start.";

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatController _chat = ChatController(assistant: widget.assistant);

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _chat,
        builder: (context, _) => ChatLayout(
          messages: _buildMessages(),
          input: ChatInputPane(
            status: _chat.status,
            initialText: ChatPage.firstPrompt,
            onSend: _chat.send,
            onPause: _chat.pause,
            onResume: _chat.resume,
            onCancel: _chat.cancel,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMessages() {
    final ChatStatus status = _chat.status;
    final ChatMessage? current = _chat.currentAnswer;
    final String? error = _chat.error;
    return [
      for (final message in _chat.messages) ...[
        if (message.text.isNotEmpty)
          MessageBubble(
            text: message.text,
            isUser: message.role == Role.user,
            // A resumed answer is being written again, so it is marked only
            // while paused.
            interrupted:
                message.interrupted &&
                !(status == ChatStatus.streaming &&
                    identical(message, current)),
            // Only the current answer can still be resumed; an earlier one
            // was stopped for good.
            isPaused:
                status == ChatStatus.paused && identical(message, current),
          ),
        // Kept with the current answer, above any context the user sends
        // meanwhile.
        if (identical(message, current)) ...[
          ThinkingBox(controller: _chat.thinking),
          // Once the answer is streaming the thinking box is gone, so the
          // dots carry on under the answer instead.
          if (status == ChatStatus.streaming && !_chat.thinking.isVisible)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: AnimatedEllipsis(),
              ),
            ),
        ],
      ],
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Could not get an answer: $error\n'
            'Resume to try again, or cancel.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ];
  }
}
