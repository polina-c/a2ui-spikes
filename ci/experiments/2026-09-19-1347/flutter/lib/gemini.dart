// A direct HTTP client for Gemini.
//
// genui_a2a connects genui to an A2A agent over a server. This app has no
// server: the browser talks to Gemini and pipes the reply into genui's
// transport, so the model is the agent.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const _endpoint = 'https://generativelanguage.googleapis.com/v1beta/models';

/// Gemini returns these when it is busy rather than when anything is wrong.
const _transient = {429, 500, 503};

class GeminiClient {
  GeminiClient({
    required this.modelId,
    required this.apiKey,
    required this.temperature,
    required this.maxOutputTokens,
  });

  final String modelId;
  final String apiKey;
  final double temperature;
  final int maxOutputTokens;

  final List<Map<String, Object?>> _history = [];
  String? _system;

  void setSystemPrompt(String prompt) => _system = prompt;

  Future<String> send(String text) async {
    _history.add({
      'role': 'user',
      'parts': [
        {'text': text},
      ],
    });

    final body = <String, Object?>{
      if (_system != null)
        'systemInstruction': {
          'parts': [
            {'text': _system},
          ],
        },
      'contents': _history,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxOutputTokens,
      },
    };

    final response = await _postWithRetry(body);
    final decoded = jsonDecode(response) as Map<String, Object?>;

    if (decoded['error'] != null) {
      final err = decoded['error'] as Map<String, Object?>;
      throw Exception('Gemini ${err['code']}: ${err['message']}');
    }

    final candidates = decoded['candidates'] as List<Object?>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }
    final content = (candidates.first as Map<String, Object?>)['content']
        as Map<String, Object?>?;
    final parts = content?['parts'] as List<Object?>? ?? const [];
    final reply = parts
        .map((p) => (p as Map<String, Object?>)['text'] as String? ?? '')
        .join();

    if (reply.isEmpty) throw Exception('Gemini returned no text.');

    _history.add({
      'role': 'model',
      'parts': [
        {'text': reply},
      ],
    });
    return reply;
  }

  Future<String> _postWithRetry(
    Map<String, Object?> body, {
    int attempts = 4,
  }) async {
    final uri = Uri.parse('$_endpoint/$modelId:generateContent?key=$apiKey');
    late http.Response res;
    for (var i = 0; i < attempts; i++) {
      res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200 ||
          !_transient.contains(res.statusCode) ||
          i == attempts - 1) {
        return res.body;
      }
      await Future<void>.delayed(Duration(seconds: 2 << i));
    }
    return res.body;
  }
}
