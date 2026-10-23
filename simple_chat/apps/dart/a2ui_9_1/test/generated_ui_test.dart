import 'package:a2ui_9_1/generated_ui.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  A2uiRendererAction action(Map<String, dynamic> context) => A2uiRendererAction(
    name: 'reply',
    surfaceId: 'question',
    sourceComponentId: 'button',
    timestamp: DateTime.now(),
    context: context,
  );

  test('a button replies with the text in its context', () {
    expect(GeneratedUi.replyOf(action({'text': ' 45 cm '})), '45 cm');
  });

  test('a button without text replies with its name', () {
    expect(GeneratedUi.replyOf(action({})), 'reply');
  });

  test('the prompt teaches the catalog at protocol v0.9.1', () {
    final ui = GeneratedUi();

    expect(ui.prompt, contains(ui.catalog.id));
    expect(ui.prompt, contains('"version": "v0.9.1"'));
    expect(ui.prompt, contains('"MdCarousel"'));
    expect(ui.prompt, isNot(contains('"Slider"')));
  });
}
