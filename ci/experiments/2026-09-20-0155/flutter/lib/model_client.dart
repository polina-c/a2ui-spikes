import 'dart:convert';

import 'package:genui/genui.dart';

/// What the chat talks to, so a cloud model and an in-browser one are the same
/// thing to it.
abstract interface class ModelClient {
  /// What to show in the chat header.
  String get label;

  /// Answers one turn, given the system prompt and the conversation so far.
  Future<String> send(String system, List<ChatMessage> history);
}

/// Reports a model loading itself, which the in-browser model does slowly
/// enough that the user has to be told about it.
typedef StatusCallback = void Function(String message);

/// The text of one message, whichever kind of part carries it.
///
/// A press on a generated button arrives as an interaction part rather than as
/// words, and both kinds of model need it as text.
String textOf(ChatMessage message) {
  if (message.text.isNotEmpty) return message.text;
  final interactions = message.parts.uiInteractionParts
      .map((p) => p.interaction)
      .join('\n');
  return interactions.isNotEmpty ? interactions : ' ';
}

/// The conversation as the JSON an OpenAI-shaped chat API wants.
///
/// WebLLM takes the system prompt as the first message, where Gemini takes it
/// in a field of its own. This is pure so it can be tested without a browser,
/// which matters because everything downstream of it needs WebGPU.
String webllmMessagesJson(String system, List<ChatMessage> history) {
  return jsonEncode([
    {'role': 'system', 'content': system},
    for (final message in history)
      {
        'role': message.role == ChatMessageRole.model ? 'assistant' : 'user',
        'content': textOf(message),
      },
  ]);
}
