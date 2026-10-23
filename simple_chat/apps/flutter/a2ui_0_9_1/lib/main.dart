import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

import 'chat_page.dart';
import 'gemini.dart';
import 'generated_ui.dart';
import 'prompt.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ui = GeneratedUi();
  final String systemPrompt = await loadSystemPrompt(generatedUi: ui.prompt);
  runApp(
    A2uiChatApp(apiKey: loadGeminiApiKey(), systemPrompt: systemPrompt, ui: ui),
  );
}

class A2uiChatApp extends StatelessWidget {
  const A2uiChatApp({
    super.key,
    required this.apiKey,
    required this.systemPrompt,
    required this.ui,
  });

  final String apiKey;
  final String systemPrompt;
  final GeneratedUi ui;

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
              ui: ui,
            ),
    );
  }
}
