import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'open_link.dart';

/// One message of a chat, in a rounded bubble.
///
/// A message from the user sits on the right and shows its text as typed. A
/// message from the model sits on the left and renders its text as Markdown,
/// with tappable links and images. An answer the user interrupted is marked
/// 'Paused' while it can still be resumed, and 'Stopped' after that.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.interrupted = false,
    this.isPaused = false,
  });

  final String text;

  /// Whether the user wrote this message, rather than the model.
  final bool isUser;

  /// Whether the user paused this answer before it was finished.
  final bool interrupted;

  /// Whether this interrupted answer can still be resumed.
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
              SelectableText(text)
            else
              MarkdownBody(
                data: text,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme),
                onTapLink: (text, href, title) => openLink(href),
                imageBuilder: (uri, title, alt) =>
                    _MarkdownImage(uri: uri, alt: alt),
              ),
            if (interrupted)
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
