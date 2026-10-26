import 'package:a2ui_9_1_express/answer_content.dart';
import 'package:a2ui_9_1_express/generated_ui.dart';
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

  test('a block shows once it is complete', () {
    final String block = questionBlock();
    content.add('Where?\n\n${block.substring(0, block.length - 10)}');
    expect(texts(), ['Where?']);
    expect(content.parts.whereType<SurfacePart>(), isEmpty);

    content.add(block.substring(block.length - 10));
    expect(content.parts.whereType<SurfacePart>(), hasLength(1));
  });

  test('the start of a tag is held back until it is complete', () {
    content.add('Where?\n\n<a2');
    expect(texts(), ['Where?']);

    content.close();
    expect(texts(), ['Where?\n\n<a2']);
  });

  test('a block that fails keeps the text around it', () {
    content.add('Where?\n\n<a2ui>\nroot = Oops(1)\n');
    content.add('</a2ui>\n\nOr tell me.\n\n${questionBlock()}\n\nThanks.');
    content.close();

    expect(content.error, isNotNull);
    expect(texts(), ['Where?\n\nOr tell me.\n\nThanks.']);
    expect(content.parts.whereType<SurfacePart>(), isEmpty);
  });

  test('a block left open keeps the text before it', () {
    content.add('Where?\n\n<a2ui>\nsurface("q")\nroot = Button(Text("Under');
    content.close();

    expect(content.error, isNotNull);
    expect(texts(), ['Where?']);
  });

  for (final (name, block) in [
    ('a button', linkBlock),
    ('the cards of a carousel', linkCarouselBlock),
  ]) {
    test('$name can open a link', () {
      content.add(block());
      content.close();

      expect(content.error, isNull);
      expect(content.parts.single, isA<SurfacePart>());
    });
  }

  test('knows when the output ends inside a block', () {
    content.add('Where?\n\n<a2ui>\nsurface("q")');
    expect(content.isInBlock, isTrue);

    content.add('\nroot = Text("Here")\n</a2ui>');
    expect(content.isInBlock, isFalse);
  });
}
