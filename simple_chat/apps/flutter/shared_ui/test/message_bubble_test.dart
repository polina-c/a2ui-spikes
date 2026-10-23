import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  Future<void> pumpBubble(WidgetTester tester, MessageBubble bubble) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: bubble)));

  testWidgets('shows the text of a user message as typed', (tester) async {
    await pumpBubble(
      tester,
      const MessageBubble(text: 'I **rent**', isUser: true),
    );

    expect(find.text('I **rent**'), findsOneWidget);
  });

  testWidgets('renders a model message as Markdown', (tester) async {
    await pumpBubble(
      tester,
      const MessageBubble(text: 'Pick the **Slim**.', isUser: false),
    );

    expect(find.textContaining('**'), findsNothing);
    expect(
      find.textContaining('Pick the Slim.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('marks an interrupted answer as paused or stopped', (
    tester,
  ) async {
    await pumpBubble(
      tester,
      const MessageBubble(
        text: 'Partial',
        isUser: false,
        interrupted: true,
        isPaused: true,
      ),
    );
    expect(find.text('Paused'), findsOneWidget);

    await pumpBubble(
      tester,
      const MessageBubble(text: 'Partial', isUser: false, interrupted: true),
    );
    expect(find.text('Stopped'), findsOneWidget);
  });

  testWidgets('shows the alt text when an image cannot load', (tester) async {
    await pumpBubble(
      tester,
      const MessageBubble(
        text: '![Just Shining Eco](https://example.com/eco.png)',
        isUser: false,
      ),
    );
    // Network requests fail in tests, so the image falls back to its alt text.
    await tester.pumpAndSettle();

    expect(find.text('Just Shining Eco'), findsOneWidget);
  });
}
