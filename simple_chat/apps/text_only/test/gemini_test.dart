import 'package:flutter_test/flutter_test.dart';
import 'package:text_only/chat_controller.dart';
import 'package:text_only/gemini.dart';

void main() {
  List<String> roles(List<Map<String, Object?>> contents) => [
    for (final content in contents) content['role']! as String,
  ];

  List<String> textsOf(Map<String, Object?> content) => [
    for (final part in content['parts']! as List<Object?>)
      (part! as Map<String, Object?>)['text']! as String,
  ];

  test('alternates user and model turns', () {
    final contents = GeminiAssistant.contentsOf([
      ChatMessage.user('hi'),
      ChatMessage.model()..text = 'Hello',
      ChatMessage.user('a dishwasher'),
    ]);

    expect(roles(contents), ['user', 'model', 'user']);
  });

  test('asks to continue an answer paused with nothing added', () {
    final contents = GeminiAssistant.contentsOf([
      ChatMessage.user('hi'),
      ChatMessage.model()
        ..text = 'Hel'
        ..interrupted = true,
    ]);

    expect(roles(contents), ['user', 'model', 'user']);
    expect(textsOf(contents.last).single, contains('Continue'));
  });

  test('merges added context into one turn after a note', () {
    final contents = GeminiAssistant.contentsOf([
      ChatMessage.user('hi'),
      ChatMessage.model()
        ..text = 'Hel'
        ..interrupted = true,
      ChatMessage.user('45 cm'),
      ChatMessage.user('two people'),
    ]);

    expect(roles(contents), ['user', 'model', 'user']);
    final List<String> added = textsOf(contents.last);
    expect(added, hasLength(3));
    expect(added.first, contains('stopped'));
    expect(added.skip(1), ['45 cm', 'two people']);
  });
}
