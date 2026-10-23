import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

import 'chat_page.dart';
import 'gemini.dart';
import 'prompt.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final String systemPrompt = await loadSystemPrompt();
  runApp(TextOnlyApp(apiKey: loadGeminiApiKey(), systemPrompt: systemPrompt));
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
