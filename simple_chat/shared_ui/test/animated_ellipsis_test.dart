import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  Future<void> pumpDots(
    WidgetTester tester, {
    double dotSize = 10.0,
    bool animate = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: AnimatedEllipsis(dotSize: dotSize, animate: animate),
        ),
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

  testWidgets('stops moving when not animated, and carries on after', (
    tester,
  ) async {
    await pumpDots(tester);
    await tester.pump(const Duration(milliseconds: 500));
    final int frozen = visibleDots(tester);

    await pumpDots(tester, animate: false);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(visibleDots(tester), frozen);
    }

    await pumpDots(tester);
    final counts = <int>{};
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      counts.add(visibleDots(tester));
    }
    expect(counts.length, greaterThan(1));
  });
}
