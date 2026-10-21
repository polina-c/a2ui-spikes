import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'chat_controller.dart';

/// Hidden turns that tell the model about a pause.
class _Note {
  static const String resume =
      '(The answer above was paused by the user and is now resumed. '
      'Continue it exactly where it stopped, without repeating anything.)';
  static const String interrupted =
      '(The answer above was paused by the user, who then added what follows. '
      'Take it into account in a new answer.)';
}

/// Streams answers from the Gemini API, called directly from the app.
class GeminiAssistant implements Assistant {
  GeminiAssistant({required this.apiKey, required this.systemPrompt});

  final String apiKey;
  final String systemPrompt;

  static const String model = 'gemini-flash-latest';

  static final Uri _endpoint = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$model:streamGenerateContent?alt=sse',
  );

  @override
  Stream<AnswerChunk> answer(List<ChatMessage> history) async* {
    final request = http.Request('POST', _endpoint)
      ..headers['Content-Type'] = 'application/json'
      ..headers['x-goog-api-key'] = apiKey
      ..body = jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'contents': contentsOf(history),
        'generationConfig': {
          'thinkingConfig': {'includeThoughts': true},
        },
      });

    // A client per answer, so that closing it aborts this answer only.
    final client = http.Client();
    try {
      final http.StreamedResponse response = await client.send(request);
      if (response.statusCode != 200) {
        throw http.ClientException('Gemini returned ${response.statusCode}.');
      }

      // Server-sent events: each 'data:' line holds one JSON response.
      final Stream<String> lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final String line in lines) {
        if (!line.startsWith('data:')) continue;
        final json = jsonDecode(line.substring(5)) as Map<String, Object?>;
        for (final part in _parts(json)) {
          final text = part['text'] as String?;
          if (text == null || text.isEmpty) continue;
          yield (text: text, isThought: part['thought'] == true);
        }
      }
    } finally {
      client.close();
    }
  }

  static List<Map<String, Object?>> _parts(Map<String, Object?> json) {
    final candidates = json['candidates'] as List<Object?>? ?? const [];
    if (candidates.isEmpty) return const [];
    final candidate = candidates.first as Map<String, Object?>;
    final content = candidate['content'] as Map<String, Object?>?;
    final parts = content?['parts'] as List<Object?>? ?? const [];
    return parts.cast<Map<String, Object?>>();
  }

  /// The conversation in Gemini's format, with notes about paused answers.
  ///
  /// Gemini expects the roles to alternate, so consecutive turns of one role,
  /// such as context added during a pause, are merged into one.
  @visibleForTesting
  static List<Map<String, Object?>> contentsOf(List<ChatMessage> history) {
    final List<(Role, String)> turns = [];
    for (final ChatMessage message in history) {
      if (message.text.isEmpty) continue;
      turns.add((message.role, message.text));
      if (message.interrupted) {
        final bool isLast = identical(message, history.last);
        turns.add((Role.user, isLast ? _Note.resume : _Note.interrupted));
      }
    }

    final List<Map<String, Object?>> contents = [];
    Role? previous;
    for (final (Role role, String text) in turns) {
      final part = {'text': text};
      if (role == previous) {
        (contents.last['parts'] as List<Object?>).add(part);
      } else {
        contents.add({
          'role': role == Role.model ? 'model' : 'user',
          'parts': <Object?>[part],
        });
      }
      previous = role;
    }
    return contents;
  }
}
