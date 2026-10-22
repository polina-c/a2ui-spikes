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

  testWidgets('context can be sent while the answer streams', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    assistant.write('Partial');
    await tester.pump();

    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.text('Add context, or pause'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'I rent');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(find.text('I rent'), findsOneWidget);
    expect(assistant.requests, hasLength(1));

    await assistant.finish();
    await tester.pump();
    expect(assistant.requests, hasLength(2));
  });

  Future<void> pumpAnswerAndPause(WidgetTester tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    assistant.write('Partial');
    await tester.pump();
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
  }

  testWidgets('paused shows send and cancel, and explains them', (
    tester,
  ) async {
    await pumpAnswerAndPause(tester);

    expect(find.text('Paused'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsNothing);
    expect(find.textContaining('send empty to resume'), findsOneWidget);
  });

  testWidgets('pausing while thinking keeps the thinking box', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    assistant.think('Weighing the options');
    await tester.pump();

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(find.byType(ThinkingBox), findsOneWidget);
    expect(find.textContaining('Weighing the options'), findsOneWidget);
    expect(
      tester.widget<AnimatedEllipsis>(find.byType(AnimatedEllipsis)).animate,
      isFalse,
    );
  });

  testWidgets('sending context while paused resumes', (tester) async {
    await pumpAnswerAndPause(tester);

    await tester.enterText(find.byType(TextField), 'I rent');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(find.text('I rent'), findsOneWidget);
    expect(assistant.requests, hasLength(2));
    expect(assistant.requests.last.last.text, 'I rent');
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('sending empty while paused just resumes', (tester) async {
    await pumpAnswerAndPause(tester);

    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(assistant.requests, hasLength(2));
    expect(assistant.requests.last.last.text, 'Partial');
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('cancel stops the answer for good', (tester) async {
    await pumpAnswerAndPause(tester);

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pump();

    expect(find.text('Stopped'), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsNothing);
    expect(find.text('Message'), findsOneWidget);
    expect(assistant.requests, hasLength(1));
  });
}
