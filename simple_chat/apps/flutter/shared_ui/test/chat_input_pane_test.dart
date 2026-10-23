import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  late List<String> calls;

  setUp(() => calls = []);

  Future<void> pumpPane(
    WidgetTester tester,
    ChatStatus status, {
    String initialText = '',
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatInputPane(
          status: status,
          initialText: initialText,
          onSend: (text) => calls.add('send $text'),
          onPause: () => calls.add('pause'),
          onResume: () => calls.add('resume'),
          onCancel: () => calls.add('cancel'),
        ),
      ),
    ),
  );

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('sends the trimmed text and clears the field', (tester) async {
    await pumpPane(tester, ChatStatus.idle, initialText: ' Hi ');

    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(calls, ['send Hi']);
    expect(fieldText(tester), isEmpty);
  });

  testWidgets('send is disabled for whitespace only', (tester) async {
    await pumpPane(tester, ChatStatus.idle, initialText: '   ');

    final IconButton send = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.send),
    );
    expect(send.onPressed, isNull);
  });

  testWidgets('streaming offers pause next to send', (tester) async {
    await pumpPane(tester, ChatStatus.streaming);

    expect(find.text('Add context, or pause'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    expect(calls, ['pause']);
    expect(find.byTooltip('Send'), findsOneWidget);
  });

  testWidgets('paused offers resume and cancel', (tester) async {
    await pumpPane(tester, ChatStatus.paused);

    await tester.tap(find.byTooltip('Resume'));
    await tester.tap(find.byTooltip('Cancel'));
    expect(calls, ['resume', 'cancel']);
    expect(find.byTooltip('Pause'), findsNothing);
  });

  testWidgets('typing while paused turns resume into send and resume', (
    tester,
  ) async {
    await pumpPane(tester, ChatStatus.paused);

    await tester.enterText(find.byType(TextField), 'I rent');
    await tester.pump();
    expect(find.byTooltip('Resume'), findsNothing);

    await tester.tap(find.byTooltip('Send and resume'));
    expect(calls, ['send I rent']);
  });

  testWidgets('enter with an empty field resumes while paused', (tester) async {
    await pumpPane(tester, ChatStatus.paused);

    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.send);

    expect(calls, ['resume']);
  });
}
