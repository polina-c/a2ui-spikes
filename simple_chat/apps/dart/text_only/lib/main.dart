import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'chat_page.dart';
import 'gemini.dart';
import 'prompt.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final String systemPrompt = await loadSystemPrompt();
  runApp(TextOnlyApp(apiKey: _apiKey(), systemPrompt: systemPrompt));
}

/// Takes the key from `--dart-define=GEMINI_API_KEY=...`, or, outside the
/// browser, from the environment.
String _apiKey() {
  const String defined = String.fromEnvironment('GEMINI_API_KEY');
  if (defined.isNotEmpty || kIsWeb) return defined;
  return Platform.environment['GEMINI_API_KEY'] ?? '';
}

class TextOnlyApp extends StatelessWidget {
  const TextOnlyApp({
    super.key,
    required this.apiKey,
    required this.systemPrompt,
  });

  final String apiKey;
  final String systemPrompt;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: apiKey.isEmpty
          ? const Scaffold(
              body: Center(child: Text('Set GEMINI_API_KEY to start a chat.')),
            )
          : ChatPage(
              assistant: GeminiAssistant(
                apiKey: apiKey,
                systemPrompt: systemPrompt,
              ),
            ),
    );
  }
}
