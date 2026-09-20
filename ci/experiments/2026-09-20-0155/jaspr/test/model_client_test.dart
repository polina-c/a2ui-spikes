import 'dart:convert';

import 'package:simple_chat_jaspr/model_client.dart';
import 'package:test/test.dart';

/// The in-browser model itself needs WebGPU and a browser, so what is checked
/// here is the pure part: the conversation turned into the JSON the bridge
/// hands to WebLLM.
void main() {
  test('the system prompt leads, and roles are mapped for an OpenAI shape', () {
    final json = webllmMessagesJson('BE A SALESPERSON', const [
      Turn('user', 'I need a dishwasher'),
      Turn('model', 'Where will it go?'),
    ]);

    expect(jsonDecode(json), [
      {'role': 'system', 'content': 'BE A SALESPERSON'},
      {'role': 'user', 'content': 'I need a dishwasher'},
      // Gemini calls this role "model"; an OpenAI-shaped API calls it
      // "assistant", and WebLLM is the second kind.
      {'role': 'assistant', 'content': 'Where will it go?'},
    ]);
  });

  test('the turn describing a button press crosses unchanged', () {
    const press = Turn('user', 'The user pressed "gap60" in the UI you drew.');
    final decoded =
        jsonDecode(webllmMessagesJson('S', const [press])) as List<Object?>;

    expect((decoded.last as Map<String, Object?>)['content'], press.text);
  });
}
