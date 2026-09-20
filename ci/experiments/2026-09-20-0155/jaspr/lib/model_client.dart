import 'dart:convert';

/// One turn of the conversation.
class Turn {
  const Turn(this.role, this.text);

  /// 'user' or 'model', the way Gemini names them.
  final String role;
  final String text;
}

/// What the chat talks to, so a cloud model and an in-browser one are the same
/// thing to it.
abstract interface class ModelClient {
  /// What to show in the chat header.
  String get label;

  /// Answers one turn, given the system prompt and the conversation so far.
  Future<String> send(String system, List<Turn> turns);
}

/// Reports a model loading itself, which the in-browser model does slowly
/// enough that the user has to be told about it.
typedef StatusCallback = void Function(String message);

/// The conversation as the JSON an OpenAI-shaped chat API wants.
///
/// WebLLM takes the system prompt as the first message, where Gemini takes it
/// in a field of its own. This is pure so it can be tested without a browser,
/// which matters because everything downstream of it needs WebGPU.
String webllmMessagesJson(String system, List<Turn> turns) {
  return jsonEncode([
    {'role': 'system', 'content': system},
    for (final turn in turns)
      {
        'role': turn.role == 'model' ? 'assistant' : 'user',
        'content': turn.text,
      },
  ]);
}
