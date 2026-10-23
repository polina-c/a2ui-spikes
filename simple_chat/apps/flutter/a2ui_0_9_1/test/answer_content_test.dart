import 'package:a2ui_9_1/answer_content.dart';
import 'package:a2ui_9_1/generated_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a2ui_samples.dart';

void main() {
  final ui = GeneratedUi();
  late AnswerContent content;

  setUp(() {
    content = ui.read(onReply: (_) {});
    addTearDown(content.dispose);
  });

  List<String> texts() => [
    for (final AnswerPart part in content.parts)
      if (part is MarkdownPart) part.markdown,
  ];

  test('text and a surface stream in, with tags split across chunks', () {
    final String output = 'Where?\n\n${questionBlock()}\n\nOr tell me.';
    for (var i = 0; i < output.length; i += 7) {
      content.add(output.substring(i, (i + 7).clamp(0, output.length)));
    }
    content.close();

    expect(content.error, isNull);
    expect(content.parts, [
      isA<MarkdownPart>(),
      isA<SurfacePart>(),
      isA<MarkdownPart>(),
    ]);
    expect(texts(), ['Where?', 'Or tell me.']);
  });

  test('a block that fails in a later chunk keeps the text around it', () {
    content.add('Where?\n\n<a2ui-json>[{"version": "v0.9.1", ');
    content.add('"oops": 1}]</a2ui-json>\n\nOr tell me.');
    content.close();

    expect(content.error, isNotNull);
    expect(texts(), ['Where?', 'Or tell me.']);
  });

  test('a block left open keeps the text before it', () {
    content.add('Where?\n\n<a2ui-json>[{"version": "v0.9.1"');
    content.close();

    expect(content.error, isNotNull);
    expect(texts(), ['Where?']);
  });

  test('knows when the output ends inside a block', () {
    content.add('Where?\n\n<a2ui-json>[');
    expect(content.isInBlock, isTrue);

    content.add(']</a2ui-json>');
    expect(content.isInBlock, isFalse);
  });
}
