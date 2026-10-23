import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  Future<void> pumpLayout(WidgetTester tester, List<Widget> messages) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLayout(messages: messages, input: const Text('input')),
          ),
        ),
      );

  testWidgets('shows the messages oldest first, above the input', (
    tester,
  ) async {
    await pumpLayout(tester, const [Text('first'), Text('second')]);

    final double first = tester.getTopLeft(find.text('first')).dy;
    final double second = tester.getTopLeft(find.text('second')).dy;
    final double input = tester.getTopLeft(find.text('input')).dy;
    expect(first, lessThan(second));
    expect(second, lessThan(input));
  });

  testWidgets('keeps the newest message in view as the list grows', (
    tester,
  ) async {
    await pumpLayout(tester, [
      for (var i = 0; i < 100; i++) SizedBox(height: 50, child: Text('m$i')),
    ]);

    expect(find.text('m99'), findsOneWidget);
    expect(find.text('m0'), findsNothing);
  });

  testWidgets('caps the width of the column', (tester) async {
    tester.view.physicalSize = const Size(2000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpLayout(tester, const []);

    expect(tester.getSize(find.byType(ListView)).width, 800);
  });
}
