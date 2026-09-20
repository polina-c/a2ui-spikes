import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_chat_flutter/models.dart';
import 'package:simple_chat_flutter/picker_page.dart';

void main() {
  testWidgets('the picker opens on the recommended model and asks for a key', (
    tester,
  ) async {
    ModelChoice? started;
    await tester.pumpWidget(
      MaterialApp(home: PickerPage(onStart: (choice) => started = choice)),
    );

    expect(find.text('Just Shining'), findsOneWidget);
    expect(find.text('gemini-flash-latest (recommended)'), findsOneWidget);
    // The key goes in behind dots, so it is never on screen or in a video.
    final keyField = find.widgetWithText(TextField, 'Gemini API key');
    expect(keyField, findsOneWidget);
    expect(tester.widget<TextField>(keyField).obscureText, isTrue);

    // Without a key there is nothing to start.
    final start = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(start.onPressed, isNull);

    await tester.enterText(keyField, 'a-key');
    await tester.pump();
    await tester.tap(find.text('Start the chat'));
    await tester.pump();

    expect(started, isNotNull);
    expect(started!.modelId, 'gemini-flash-latest');
    expect(started!.temperature, 0.7);
    expect(started!.maxOutputTokens, 4096);
    expect(started!.apiKey, 'a-key');
  });
}
