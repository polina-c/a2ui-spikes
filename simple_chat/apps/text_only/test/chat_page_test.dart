import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:text_only/chat_page.dart';

import 'fake_assistant.dart';

void main() {
  late FakeAssistant assistant;

  setUp(() => assistant = FakeAssistant());

  Future<void> pumpPage(WidgetTester tester) =>
      tester.pumpWidget(MaterialApp(home: ChatPage(assistant: assistant)));

  testWidgets('starts with the first prompt ready to send', (tester) async {
    await pumpPage(tester);

    expect(find.text(ChatPage.firstPrompt), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
  });

  testWidgets('renders the answer as Markdown', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    assistant.write('Pick the **Slim**.');
    await tester.pump();

    expect(find.textContaining('**'), findsNothing);
    expect(
      find.textContaining('Pick the Slim.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('dots stay under the answer while it streams', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    assistant.write('Partial');
    await tester.pump();
    expect(find.byType(AnimatedEllipsis), findsOneWidget);

    await assistant.finish();
    await tester.pump();
    expect(find.byType(AnimatedEllipsis), findsNothing);
  });

  testWidgets('pause, add context, and resume', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    assistant.write('Partial');
    await tester.pump();
    expect(find.byTooltip('Send'), findsNothing);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.byTooltip('Resume'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'I rent');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(find.text('I rent'), findsOneWidget);
    expect(assistant.requests, hasLength(1));

    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    expect(assistant.requests, hasLength(2));
    expect(find.byTooltip('Pause'), findsOneWidget);
  });
}
