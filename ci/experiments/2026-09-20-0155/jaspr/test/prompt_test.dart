import 'package:simple_chat_jaspr/prompt.dart';
import 'package:test/test.dart';

void main() {
  group('parseReply', () {
    test('reads the spoken half and the messages', () {
      final reply = parseReply(
        '{"say":"Where will it go?","a2ui":[{"version":"v0.9"}]}',
      );
      expect(reply.say, 'Where will it go?');
      expect(reply.a2ui, hasLength(1));
    });

    test('tolerates the markdown fence the model sometimes adds', () {
      final reply = parseReply('```json\n{"say":"Hello","a2ui":[]}\n```');
      expect(reply.say, 'Hello');
      expect(reply.a2ui, isEmpty);
    });

    test('a reply with no object at all is an error, not empty output', () {
      expect(() => parseReply('I am sorry, I cannot.'), throwsFormatException);
    });
  });

  test('the prompt carries the catalog, the corpus and the machine names', () {
    final prompt = systemPrompt(
      inlineCatalog: {'components': {}},
      catalogId: 'test-catalog',
      corpus: 'THE KNOWLEDGE',
      modelIds: const ['mini', 'eco'],
    );
    expect(prompt, contains('test-catalog'));
    expect(prompt, contains('THE KNOWLEDGE'));
    expect(prompt, contains('mini, eco'));
    // The app opens the landing pages itself, so the model must not write one.
    expect(prompt, contains('do not write a URL'));
  });
}
