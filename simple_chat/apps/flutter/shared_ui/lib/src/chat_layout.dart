import 'package:flutter/material.dart';

/// The frame of a chat page: the messages, with the input under them.
///
/// The column is centered and capped in width, so that lines stay readable on
/// a wide window.
class ChatLayout extends StatelessWidget {
  const ChatLayout({
    super.key,
    required this.messages,
    required this.input,
    this.maxWidth = 800,
  });

  /// What the conversation shows, oldest first.
  final List<Widget> messages;

  /// Shown under the messages, such as a [ChatInputPane].
  final Widget input;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              Expanded(
                // Reversed, so the list stays pinned to the newest message as
                // it grows.
                child: ListView(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  children: messages.reversed.toList(),
                ),
              ),
              input,
            ],
          ),
        ),
      ),
    );
  }
}
