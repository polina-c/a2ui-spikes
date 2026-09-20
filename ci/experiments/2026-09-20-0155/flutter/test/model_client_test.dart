import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:simple_chat_flutter/model_client.dart';

/// The in-browser model itself needs WebGPU and cannot run under `flutter
/// test`, so what is checked here is the pure part: the conversation turned
/// into the JSON the bridge hands to WebLLM.
void main() {
  test('the system prompt leads, and roles are mapped for an OpenAI shape', () {
    final json = webllmMessagesJson('BE A SALESPERSON', [
      ChatMessage.user('I need a dishwasher'),
      ChatMessage.model('Where will it go?'),
    ]);

    expect(jsonDecode(json), [
      {'role': 'system', 'content': 'BE A SALESPERSON'},
      {'role': 'user', 'content': 'I need a dishwasher'},
      // Gemini calls this role "model"; an OpenAI-shaped API calls it
      // "assistant", and WebLLM is the second kind.
      {'role': 'assistant', 'content': 'Where will it go?'},
    ]);
  });

  test('a button press crosses as text rather than as an empty message', () {
    final press = ChatMessage.user(
      '',
      parts: [UiInteractionPart.create('{"action":"chose_60cm"}')],
    );

    expect(textOf(press), contains('chose_60cm'));

    final decoded =
        jsonDecode(webllmMessagesJson('S', [press])) as List<Object?>;
    final last = decoded.last as Map<String, Object?>;
    expect(last['role'], 'user');
    expect(last['content'], contains('chose_60cm'));
  });

  test('an empty message still carries something the model can read', () {
    // An API rejects a message with no content at all, so this is never empty.
    expect(textOf(ChatMessage.user('')), isNotEmpty);
  });
}
