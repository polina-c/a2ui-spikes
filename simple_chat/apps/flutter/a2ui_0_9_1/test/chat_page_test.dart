import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:a2ui_9_1/chat_page.dart';
import 'package:a2ui_9_1/generated_ui.dart';

import 'a2ui_samples.dart';
import 'fake_assistant.dart';

void main() {
  final ui = GeneratedUi();
  late FakeAssistant assistant;

  setUp(() => assistant = FakeAssistant());

  Future<void> pumpPage(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: ChatPage(assistant: assistant, ui: ui),
    ),
  );

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
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(_input(tester).text, isEmpty, reason: 'the message was sent');
    expect(find.text('I rent'), findsOneWidget);
    expect(assistant.requests, hasLength(1));

    await assistant.finish();
    await tester.pump();
    expect(assistant.requests, hasLength(2));
  });

  Future<void> pumpAnswer(WidgetTester tester, String answer) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    assistant.write(answer);
    await assistant.finish();
    await tester.pump();
  }

  testWidgets('a button in the UI answers for the user', (tester) async {
    await pumpAnswer(tester, 'Where will it go?\n\n${questionBlock()}');
    expect(find.textContaining('a2ui-json'), findsNothing);

    await tester.tap(
      find.textContaining('Under the counter', findRichText: true),
    );
    await tester.pump();

    expect(find.text(underTheCounter), findsOneWidget);
    expect(assistant.requests, hasLength(2));
    expect(assistant.requests.last.last.text, underTheCounter);
  });

  testWidgets('selecting a card in a carousel answers for the user', (
    tester,
  ) async {
    await pumpAnswer(tester, 'Two fit.\n\n${carouselBlock()}');

    await tester.tap(find.text('Select').at(1));
    await tester.pump();

    expect(assistant.requests.last.last.text, takeTheEco);
  });

  testWidgets('UI that does not read leaves the text readable', (tester) async {
    await pumpAnswer(
      tester,
      'Where will it go?\n\n<a2ui-json>[{"oops": 1}]</a2ui-json>\n\nOr tell me.',
    );

    expect(
      find.textContaining('Where will it go?', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Or tell me.', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('oops', findRichText: true), findsNothing);
    expect(find.textContaining('Could not show all of the UI'), findsOneWidget);
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

  testWidgets('paused shows resume and cancel, and explains them', (
    tester,
  ) async {
    await pumpAnswerAndPause(tester);

    expect(find.text('Paused'), findsOneWidget);
    expect(find.byTooltip('Resume'), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsNothing);
    expect(
      find.text('Add context and resume, just resume, or cancel'),
      findsOneWidget,
    );
  });

  testWidgets('typing while paused turns resume into send and resume', (
    tester,
  ) async {
    await pumpAnswerAndPause(tester);

    await tester.enterText(find.byType(TextField), 'I rent');
    await tester.pump();
    expect(find.byTooltip('Send and resume'), findsOneWidget);
    expect(find.byTooltip('Resume'), findsNothing);

    await tester.enterText(find.byType(TextField), '  ');
    await tester.pump();
    expect(find.byTooltip('Resume'), findsOneWidget);
  });

  testWidgets('send is disabled for whitespace only', (tester) async {
    await pumpPage(tester);
    IconButton sendButton() => tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.send),
        matching: find.byType(IconButton),
      ),
    );
    expect(sendButton().onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(sendButton().onPressed, isNull);
  });

  testWidgets('pausing while thinking keeps the thinking box, without dots', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    assistant.think('Weighing the options');
    await tester.pump();

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(find.byType(ThinkingBox), findsOneWidget);
    expect(find.textContaining('Weighing the options'), findsOneWidget);
    expect(find.byType(AnimatedEllipsis), findsNothing);
  });

  testWidgets('sending context while paused resumes', (tester) async {
    await pumpAnswerAndPause(tester);

    await tester.enterText(find.byType(TextField), 'I rent');
    await tester.pump();
    await tester.tap(find.byTooltip('Send and resume'));
    await tester.pump();

    expect(find.text('I rent'), findsOneWidget);
    expect(assistant.requests, hasLength(2));
    expect(assistant.requests.last.last.text, 'I rent');
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('resume with the field empty continues the answer', (
    tester,
  ) async {
    await pumpAnswerAndPause(tester);

    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();

    expect(assistant.requests, hasLength(2));
    expect(assistant.requests.last.last.text, 'Partial');
    expect(find.byTooltip('Pause'), findsOneWidget);
    // The answer is being written again, so it is not marked.
    expect(find.text('Paused'), findsNothing);
    expect(find.text('Stopped'), findsNothing);
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

TextEditingController _input(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!;
