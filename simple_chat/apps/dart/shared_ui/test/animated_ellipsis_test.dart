import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/shared_ui.dart';

void main() {
  Future<void> pumpDots(WidgetTester tester, {double dotSize = 10.0}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: AnimatedEllipsis(dotSize: dotSize)),
          ),
        ),
      );

  int visibleDots(WidgetTester tester) => tester
      .widgetList<Opacity>(find.byType(Opacity))
      .where((o) => o.opacity == 1.0)
      .length;

  testWidgets('cycles from one dot to three', (tester) async {
    await pumpDots(tester);

    final counts = <int>[];
    for (var i = 0; i < 12; i++) {
      counts.add(visibleDots(tester));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(counts.toSet(), {1, 2, 3});
  });

  testWidgets('keeps its width as the count changes', (tester) async {
    await pumpDots(tester);
    final Size first = tester.getSize(find.byType(AnimatedEllipsis));

    await tester.pump(const Duration(milliseconds: 800));

    expect(tester.getSize(find.byType(AnimatedEllipsis)), first);
  });

  testWidgets('dots are as big as asked', (tester) async {
    await pumpDots(tester, dotSize: 14.0);

    expect(tester.getSize(find.byType(DecoratedBox).first), const Size(14, 14));
  });
}
