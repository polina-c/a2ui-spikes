import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model_client.dart';
import 'models.dart';

/// Calls Gemini straight from the browser. There is no server in this app.
class GeminiClient implements ModelClient {
  GeminiClient(this.choice, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final ModelChoice choice;
  final http.Client _http;

  @override
  String get label => choice.modelId;

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Statuses Gemini returns when it is busy rather than when the call is bad.
  static const _transient = {429, 500, 502, 503};

  @override
  Future<String> send(String system, List<Turn> turns) async {
    final key = choice.apiKey;
    if (key == null || key.isEmpty) throw StateError('No Gemini API key.');

    final uri = Uri.parse(
      '$_endpoint/${choice.modelId}:generateContent'
      '?key=${Uri.encodeQueryComponent(key)}',
    );
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': [
        for (final turn in turns)
          {
            'role': turn.role,
            'parts': [
              {'text': turn.text},
            ],
          },
      ],
      'generationConfig': {
        'temperature': choice.temperature,
        'maxOutputTokens': choice.maxOutputTokens,
        'responseMimeType': 'application/json',
      },
    });

    final response = await _post(uri, body);
    if (response.statusCode != 200) {
      // The error body can echo the request, so only the status is surfaced.
      throw StateError('Gemini returned ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final candidates = decoded['candidates'] as List<Object?>? ?? const [];
    if (candidates.isEmpty) throw StateError('Gemini returned no candidates.');
    final content =
        (candidates.first as Map<String, Object?>)['content']
            as Map<String, Object?>?;
    final parts = content?['parts'] as List<Object?>? ?? const [];
    final text = parts
        .map((p) => (p as Map<String, Object?>)['text'] as String? ?? '')
        .join();
    if (text.isEmpty) throw StateError('Gemini returned no text.');
    return text;
  }

  /// Posts, and tries again when Gemini says it is overloaded. Without this a
  /// busy moment ends a recorded run.
  Future<http.Response> _post(Uri uri, String body, {int attempts = 4}) async {
    late http.Response response;
    for (var i = 0; i < attempts; i++) {
      response = await _http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode == 200 ||
          !_transient.contains(response.statusCode) ||
          i == attempts - 1) {
        return response;
      }
      await Future<void>.delayed(Duration(milliseconds: 1500 * (1 << i)));
    }
    return response;
  }
}
