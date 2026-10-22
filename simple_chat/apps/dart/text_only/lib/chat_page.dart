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

  /// Sends the message, or, while paused with nothing typed, resumes.
  ///
  /// Enter in the text field lands here, so it does what the main button
  /// does.
  void _send() {
    final String text = _input.text.trim();
    if (text.isNotEmpty) {
      _chat.send(text);
      _input.clear();
    } else if (_chat.status == ChatStatus.paused) {
      _chat.resume();
    }
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
    final ChatStatus status = _chat.status;
    final ChatMessage? current = _chat.currentAnswer;
    final String? error = _chat.error;
    final List<Widget> items = [
      for (final message in _chat.messages) ...[
        if (message.text.isNotEmpty)
          _MessageBubble(
            message: message,
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
              onPressed: _chat.pause,
            ),
            const SizedBox(width: 8),
          ],
          if (status == ChatStatus.paused) ...[
            IconButton.filledTonal(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: _chat.cancel,
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
                  onPressed: _chat.resume,
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isPaused});

  final ChatMessage message;
  final bool isPaused;

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
                imageBuilder: (uri, title, alt) =>
                    _MarkdownImage(uri: uri, alt: alt),
              ),
            if (message.interrupted)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isPaused ? 'Paused' : 'Stopped',
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

/// A picture in an answer, such as the photo of a recommended product.
///
/// Kept narrower than the bubble so that it does not push the text out of
/// view, and replaced by its alt text when it cannot be loaded.
class _MarkdownImage extends StatelessWidget {
  const _MarkdownImage({required this.uri, required this.alt});

  final Uri uri;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            uri.toString(),
            semanticLabel: alt,
            errorBuilder: (context, error, stackTrace) => Text(alt ?? ''),
          ),
        ),
      ),
    );
  }
}
