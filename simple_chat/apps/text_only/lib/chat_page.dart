import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final TextEditingController _input = TextEditingController(
    text: ChatPage.firstPrompt,
  );

  late final ChatController _chat = ChatController(assistant: widget.assistant);

  @override
  void dispose() {
    _input.dispose();
    _chat.dispose();
    super.dispose();
  }

  void _send() {
    if (_chat.status == ChatStatus.streaming) return;
    final String text = _input.text.trim();
    if (text.isEmpty) return;
    _chat.send(text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListenableBuilder(
              listenable: _chat,
              builder: (context, _) => Column(
                children: [
                  Expanded(child: _buildMessages()),
                  _buildInput(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    final List<ChatMessage> messages = _chat.messages;
    final String? error = _chat.error;
    final List<Widget> items = [
      for (final message in messages)
        if (message.text.isNotEmpty) _MessageBubble(message: message),
      ThinkingBox(controller: _chat.thinking),
      // Once the answer is streaming the thinking box is gone, so the dots
      // carry on under the answer instead.
      if (_chat.status == ChatStatus.streaming && !_chat.thinking.isVisible)
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: AnimatedEllipsis(),
          ),
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Could not get an answer: $error\nResume to try again.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ];

    // Reversed, so the list stays pinned to the newest message as it grows.
    return ListView(
      reverse: true,
      padding: const EdgeInsets.all(16),
      children: items.reversed.toList(),
    );
  }

  Widget _buildInput() {
    final ChatStatus status = _chat.status;
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
                hintText: status == ChatStatus.paused
                    ? 'Add context, then resume'
                    : 'Message',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (status == ChatStatus.streaming)
            IconButton.filled(
              tooltip: 'Pause',
              icon: const Icon(Icons.pause),
              onPressed: _chat.pause,
            )
          else ...[
            if (status == ChatStatus.paused)
              IconButton.filledTonal(
                tooltip: 'Resume',
                icon: const Icon(Icons.play_arrow),
                onPressed: _chat.resume,
              ),
            IconButton.filled(
              tooltip: 'Send',
              icon: const Icon(Icons.send),
              onPressed: _send,
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isUser = message.role == Role.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUser)
              SelectableText(message.text)
            else
              MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme),
                onTapLink: (text, href, title) {
                  if (href != null) launchUrl(Uri.parse(href));
                },
              ),
            if (message.interrupted)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Paused',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
