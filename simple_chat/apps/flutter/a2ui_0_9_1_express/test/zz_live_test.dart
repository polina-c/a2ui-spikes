import 'dart:io';
import 'package:a2ui_9_1_express/answer_content.dart';
import 'package:a2ui_9_1_express/chat_controller.dart';
import 'package:a2ui_9_1_express/chat_page.dart';
import 'package:a2ui_9_1_express/gemini.dart';
import 'package:a2ui_9_1_express/generated_ui.dart';
import 'package:test/test.dart';

String systemPrompt(String generatedUi) {
  const domain = 'assets/doc/domain/just_shining';
  final pages = Directory('$domain/landing_pages').listSync().whereType<File>()
      .where((f) => f.path.endsWith('.md') && !f.path.endsWith('README.md')).map((f) => f.path).toList()..sort();
  return [
    for (final p in ['assets/doc/blueprints/0-chat-specifications.md', '$domain/knowledge.md', ...pages]) File(p).readAsStringSync(),
    generatedUi,
  ].join('\n\n---\n\n');
}

void main() {
  test('live', () async {
    final ui = GeneratedUi();
    final chat = ChatController(
      assistant: GeminiAssistant(apiKey: Platform.environment['GEMINI_API_KEY']!, systemPrompt: systemPrompt(ui.prompt)),
      ui: ui,
    );
    for (final msg in [ChatPage.firstPrompt, 'It goes under the counter, a standard 60 cm space.', 'Quiet matters most. Up to 900 dollars.']) {
      final sw = Stopwatch()..start();
      int? firstSurfaceMs;
      chat.addListener(() {
        final m = chat.messages.last;
        if (firstSurfaceMs == null && m.role != Role.user && chat.contentOf(m).parts.any((p) => p is SurfacePart)) firstSurfaceMs = sw.elapsedMilliseconds;
      });
      chat.send(msg);
      while (chat.status != ChatStatus.idle) { await Future<void>.delayed(const Duration(milliseconds: 50)); }
      final m = chat.messages.last;
      final AnswerContent c = chat.contentOf(m);
      print('=== USER: $msg\n--- ${sw.elapsedMilliseconds} ms, first surface at ${firstSurfaceMs} ms, parts: ${c.parts.map((p) => p is SurfacePart ? 'Surface' : 'Text').join(', ')}, error: ${c.error}');
      print(m.text);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
