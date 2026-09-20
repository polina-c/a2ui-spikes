import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_chat_flutter/models.dart';
import 'package:simple_chat_flutter/picker_page.dart';

void main() {
  /// The picker is taller than the default 800x600 test window, and a ListView
  /// only builds what is on screen. Giving the test a tall window keeps these
  /// tests about the picker rather than about scrolling.
  void useTallWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('the picker opens on the recommended model and asks for a key', (
    tester,
  ) async {
    useTallWindow(tester);
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
    final startButton = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(startButton).onPressed, isNull);

    await tester.enterText(keyField, 'a-key');
    await tester.pump();
    await tester.tap(startButton);
    await tester.pump();

    expect(started, isNotNull);
    expect(started!.modelId, 'gemini-flash-latest');
    expect(started!.temperature, 0.7);
    expect(started!.maxOutputTokens, 4096);
    expect(started!.apiKey, 'a-key');
  });

  testWidgets('the in-browser family starts without a key', (tester) async {
    useTallWindow(tester);
    ModelChoice? started;
    await tester.pumpWidget(
      MaterialApp(home: PickerPage(onStart: (choice) => started = choice)),
    );

    await tester.tap(find.text('In this browser'));
    await tester.pump();

    // No key box, and nothing standing between Jane and the chat: this is the
    // path she takes when her key is not to hand.
    expect(find.widgetWithText(TextField, 'Gemini API key'), findsNothing);

    final startButton = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(startButton).onPressed, isNotNull);

    await tester.tap(startButton);
    await tester.pump();

    expect(started, isNotNull);
    expect(started!.familyId, 'local');
    expect(started!.modelId, 'Llama-3.2-3B-Instruct-q4f16_1-MLC');
    expect(started!.apiKey, anyOf(isNull, isEmpty));
  });
}
