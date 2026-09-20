import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_chat_flutter/models.dart';
import 'package:simple_chat_flutter/picker_page.dart';

void main() {
  testWidgets('the picker opens on a default model and can start', (
    tester,
  ) async {
    ModelChoice? started;
    await tester.pumpWidget(
      MaterialApp(home: PickerPage(onStart: (c) => started = c)),
    );

    expect(find.text('Just Shining'), findsOneWidget);
    expect(find.textContaining('(default)'), findsOneWidget);

    // Gemini needs a key, so the button stays disabled until one is typed.
    final start = find.widgetWithText(FilledButton, 'Start the chat');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'test-key');
    await tester.pump();

    // The picker is taller than the test viewport, so the button has to be
    // brought into view before it can be tapped.
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pump();

    expect(started, isNotNull);
    expect(started!.modelId, defaultModel.id);
    expect(started!.familyId, 'gemini');
    expect(started!.apiKey, 'test-key');
  });

  testWidgets('every parameter shows the range the UI allows', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PickerPage(onStart: (_) {})));
    for (final p in defaultModel.params) {
      expect(find.text(p.label), findsOneWidget);
    }
    expect(find.textContaining('allowed'), findsNWidgets(defaultModel.params.length));
  });
}
