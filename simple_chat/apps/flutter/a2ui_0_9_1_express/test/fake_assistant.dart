import 'dart:async';

import 'package:a2ui_9_1_express/chat_controller.dart';

/// An assistant whose answers the test writes chunk by chunk.
class FakeAssistant implements Assistant {
  /// The history passed with each request, oldest request first.
  final List<List<ChatMessage>> requests = [];

  StreamController<AnswerChunk>? _answer;

  /// Whether the current answer has been cancelled, such as by a pause.
  bool cancelled = false;

  @override
  Stream<AnswerChunk> answer(List<ChatMessage> history) {
    requests.add(history);
    cancelled = false;
    _answer = StreamController<AnswerChunk>(onCancel: () => cancelled = true);
    return _answer!.stream;
  }

  void think(String text) => _answer!.add((text: text, isThought: true));

  void write(String text) => _answer!.add((text: text, isThought: false));

  void fail(Object error) => _answer!.addError(error);

  Future<void> finish() => _answer!.close();
}
