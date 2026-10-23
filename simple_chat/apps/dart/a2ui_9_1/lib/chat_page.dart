import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shared_ui/shared_ui.dart';

import 'answer_content.dart';
import 'chat_controller.dart';
import 'generated_ui.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.assistant, required this.ui});

  final Assistant assistant;
  final GeneratedUi ui;

  static const String firstPrompt =
      "Hi, I am looking for a dishwasher. I am overwhelmed with choices and "
      "don't know where to start.";

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatController _chat = ChatController(
    assistant: widget.assistant,
    ui: widget.ui,
  );

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
        if (message.role == Role.user)
          MessageBubble(text: message.text, isUser: true)
        else
          ..._buildAnswer(
            message,
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

  /// The text and the UI of [answer], in the order the model wrote them.
  ///
  /// An interrupted answer is marked on its last bubble, so when it ends in
  /// UI, an empty bubble follows to carry the mark.
  List<Widget> _buildAnswer(ChatMessage answer, {required bool isPaused}) {
    final AnswerContent content = _chat.contentOf(answer);
    final List<AnswerPart> parts = content.parts;
    final A2uiError? uiError = content.error;
    return [
      for (final AnswerPart part in parts)
        switch (part) {
          MarkdownPart(:final String markdown) => MessageBubble(
            text: markdown,
            isUser: false,
            interrupted: answer.interrupted && identical(part, parts.last),
            isPaused: isPaused,
          ),
          SurfacePart(:final surface) => _AnswerSurface(
            key: ObjectKey(surface),
            surface: surface,
          ),
        },
      if (answer.interrupted &&
          answer.text.isNotEmpty &&
          parts.lastOrNull is! MarkdownPart)
        MessageBubble(
          text: '',
          isUser: false,
          interrupted: true,
          isPaused: isPaused,
        ),
      if (uiError != null)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Could not show all of the UI: ${uiError.message}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ];
  }
}

/// UI the model generated for an answer.
class _AnswerSurface extends StatelessWidget {
  const _AnswerSurface({super.key, required this.surface});

  final SurfaceModel<ComponentImplementation> surface;

  /// Renders the Markdown that models often write in a `Text` component.
  static Widget _markdown(
    BuildContext context,
    String markdown,
    TextStyle style,
  ) => MarkdownBody(
    data: markdown,
    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
        .copyWith(p: style),
    onTapLink: (text, href, title) => openLink(href),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: A2uiMarkdown(
        builder: _markdown,
        child: A2uiSurface(surface: surface),
      ),
    );
  }
}
