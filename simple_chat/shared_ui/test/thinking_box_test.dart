import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  late ThinkingBoxController controller;

  setUp(() {
    controller = ThinkingBoxController();
    addTearDown(controller.dispose);
  });

  Finder findEllipsis() => find.byType(AnimatedEllipsis);

  /// How many dots of the ellipsis are showing.
  int visibleDots(WidgetTester tester) => tester
      .widgetList<Opacity>(
        find.descendant(of: findEllipsis(), matching: find.byType(Opacity)),
      )
      .where((o) => o.opacity == 1.0)
      .length;

  /// The ellipsis animates forever, so `pumpAndSettle` would never return.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpBox(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ThinkingBox(controller: controller)),
      ),
    );
  }

  testWidgets('shows nothing while not visible', (tester) async {
    await pumpBox(tester);

    expect(find.byType(Card), findsNothing);
    expect(tester.getSize(find.byType(ThinkingBox)), Size.zero);
  });

  testWidgets('stays hidden while not visible, even with thought', (
    tester,
  ) async {
    await pumpBox(tester);

    controller.addChunk('thinking about it');
    await tester.pump();

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('visible with no thought shows just the ellipsis', (
    tester,
  ) async {
    await pumpBox(tester);

    controller.isVisible = true;
    await tester.pump();

    expect(find.byType(Card), findsOneWidget);
    expect(findEllipsis(), findsOneWidget);
    // No markdown, and so nothing to scroll.
    expect(
      find.descendant(of: find.byType(Card), matching: find.byType(Scrollable)),
      findsNothing,
    );
  });

  testWidgets('shows the thought once a chunk arrives', (tester) async {
    await pumpBox(tester);
    controller.isVisible = true;

    controller.addChunk('thinking about it');
    await tester.pump();

    expect(find.textContaining('thinking about it'), findsOneWidget);
    expect(findEllipsis(), findsOneWidget);
  });

  testWidgets('chunks accumulate into one thought', (tester) async {
    await pumpBox(tester);
    controller.isVisible = true;

    controller.addChunk('first ');
    controller.addChunk('second');
    await tester.pump();

    expect(controller.text, 'first second');
    expect(find.textContaining('first second'), findsOneWidget);
  });

  testWidgets('clear falls back to the ellipsis, staying visible', (
    tester,
  ) async {
    await pumpBox(tester);
    controller.isVisible = true;
    controller.addChunk('a thought');
    await tester.pump();
    expect(find.textContaining('a thought'), findsOneWidget);

    controller.clear();
    await tester.pump();

    expect(controller.isEmpty, isTrue);
    expect(find.textContaining('a thought'), findsNothing);
    expect(find.byType(Card), findsOneWidget);
    expect(findEllipsis(), findsOneWidget);
  });

  testWidgets('hiding removes the box', (tester) async {
    await pumpBox(tester);
    controller.isVisible = true;
    controller.addChunk('a thought');
    await tester.pump();
    expect(find.byType(Card), findsOneWidget);

    controller.isVisible = false;
    await tester.pump();

    expect(find.byType(Card), findsNothing);
    expect(tester.getSize(find.byType(ThinkingBox)), Size.zero);
  });

  testWidgets('stops growing and shows the tail', (tester) async {
    await pumpBox(tester);
    controller.isVisible = true;

    for (var i = 0; i < 60; i++) {
      controller.addChunk('line $i\n\n');
    }
    await tester.pump();
    // Let the post-frame scroll run.
    await tester.pump();

    final double height = tester.getSize(find.byType(Card)).height;
    expect(height, lessThan(200), reason: 'capped rather than unbounded');

    final Finder scrollable = find.descendant(
      of: find.byType(Card),
      matching: find.byType(Scrollable),
    );
    final ScrollPosition position = tester
        .state<ScrollableState>(scrollable)
        .position;
    expect(
      position.pixels,
      position.maxScrollExtent,
      reason: 'pinned to the newest thought',
    );
    expect(position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('the ellipsis animates', (tester) async {
    await pumpBox(tester);
    controller.isVisible = true;
    await tester.pump();

    final seen = <int>{};
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      seen.add(visibleDots(tester));
    }
    expect(seen.length, greaterThan(1), reason: 'dot count should change');
  });

  testWidgets('scrolling up stops the auto-follow', (tester) async {
    await pumpBox(tester);
    controller.isVisible = true;
    for (var i = 0; i < 60; i++) {
      controller.addChunk('line $i\n\n');
    }
    await tester.pump();
    await tester.pump();

    final Finder scrollable = find.descendant(
      of: find.byType(Card),
      matching: find.byType(Scrollable),
    );
    ScrollPosition positionOf() =>
        tester.state<ScrollableState>(scrollable).position;
    expect(positionOf().pixels, positionOf().maxScrollExtent);

    // Read back through the thought.
    await tester.drag(scrollable, const Offset(0, 60));
    await settle(tester);
    final double afterDrag = positionOf().pixels;
    expect(afterDrag, lessThan(positionOf().maxScrollExtent));

    // More thought arrives; the view must stay where it was left.
    controller.addChunk('a later line\n\n');
    await tester.pump();
    await tester.pump();

    expect(positionOf().pixels, afterDrag);
    expect(positionOf().pixels, lessThan(positionOf().maxScrollExtent));
  });

  testWidgets('scrolling back to the bottom resumes the auto-follow', (
    tester,
  ) async {
    await pumpBox(tester);
    controller.isVisible = true;
    for (var i = 0; i < 60; i++) {
      controller.addChunk('line $i\n\n');
    }
    await tester.pump();
    await tester.pump();

    final Finder scrollable = find.descendant(
      of: find.byType(Card),
      matching: find.byType(Scrollable),
    );
    ScrollPosition positionOf() =>
        tester.state<ScrollableState>(scrollable).position;

    await tester.drag(scrollable, const Offset(0, 60));
    await settle(tester);
    expect(positionOf().pixels, lessThan(positionOf().maxScrollExtent));

    // Back to the end.
    await tester.drag(scrollable, const Offset(0, -400));
    await settle(tester);
    expect(positionOf().pixels, positionOf().maxScrollExtent);

    controller.addChunk('a later line\n\n');
    await tester.pump();
    await tester.pump();

    expect(positionOf().pixels, positionOf().maxScrollExtent);
  });

  testWidgets('clearing restores the auto-follow', (tester) async {
    await pumpBox(tester);
    controller.isVisible = true;
    for (var i = 0; i < 60; i++) {
      controller.addChunk('line $i\n\n');
    }
    await tester.pump();
    await tester.pump();

    final Finder scrollable = find.descendant(
      of: find.byType(Card),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, 60));
    await settle(tester);

    controller.clear();
    await tester.pump();
    for (var i = 0; i < 60; i++) {
      controller.addChunk('fresh $i\n\n');
    }
    await tester.pump();
    await tester.pump();

    final ScrollPosition position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(Card),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.pixels, position.maxScrollExtent);
  });

  testWidgets('pausing keeps the box and its thought, and stops the dots', (
    tester,
  ) async {
    await pumpBox(tester);
    controller
      ..isVisible = true
      ..addChunk('a thought');
    await tester.pump();

    controller.isPaused = true;
    await tester.pump();

    expect(find.byType(Card), findsOneWidget);
    expect(find.textContaining('a thought'), findsOneWidget);
    final int frozen = visibleDots(tester);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(visibleDots(tester), frozen);
    }
  });
}
