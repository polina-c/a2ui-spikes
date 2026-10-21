import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_ui/shared_ui.dart';

enum Role { user, model }

class ChatMessage {
  ChatMessage.user(this.text) : role = Role.user;

  ChatMessage.model() : role = Role.model, text = '';

  final Role role;

  /// Grows while a model answer streams in.
  String text;

  /// Whether the user paused this answer before it was finished.
  bool interrupted = false;
}

/// A piece of a streamed answer: either text of the answer itself, or a
/// thought the model had on the way to it.
typedef AnswerChunk = ({String text, bool isThought});

abstract interface class Assistant {
  /// Streams the answer to [history].
  ///
  /// Cancelling the subscription stops the answer.
  Stream<AnswerChunk> answer(List<ChatMessage> history);
}

enum ChatStatus { idle, streaming, paused }

/// The conversation, and the answer currently being written.
class ChatController extends ChangeNotifier {
  ChatController({required this.assistant});

  final Assistant assistant;

  /// Shows the model's thinking while the user waits for an answer.
  final ThinkingBoxController thinking = ThinkingBoxController();

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatStatus _status = ChatStatus.idle;
  ChatStatus get status => _status;

  /// Why the last answer stopped, if it failed.
  String? _error;
  String? get error => _error;

  StreamSubscription<AnswerChunk>? _answer;

  /// Adds a user message.
  ///
  /// While idle, this starts an answer. While paused, the message is context
  /// for the answer that [resume] continues.
  void send(String text) {
    assert(_status != ChatStatus.streaming);
    _messages.add(ChatMessage.user(text));
    if (_status == ChatStatus.idle) {
      _startAnswer();
    } else {
      notifyListeners();
    }
  }

  void pause() {
    assert(_status == ChatStatus.streaming);
    _interrupt();
    notifyListeners();
  }

  /// Continues the paused answer, or writes a new one when the user added
  /// context while it was paused.
  void resume() {
    assert(_status == ChatStatus.paused);
    _startAnswer();
  }

  void _startAnswer() {
    // The assistant sees the conversation as it is now: the last message is
    // either the user's, or the partial answer to continue.
    final List<ChatMessage> history = List.of(_messages);
    final ChatMessage answer;
    if (_messages.last.role == Role.model) {
      answer = _messages.last;
    } else {
      answer = ChatMessage.model();
      _messages.add(answer);
    }

    _status = ChatStatus.streaming;
    _error = null;
    thinking
      ..clear()
      ..isVisible = true;
    notifyListeners();

    _answer = assistant
        .answer(history)
        .listen(
          (chunk) {
            if (chunk.isThought) {
              thinking.addChunk(chunk.text);
              return;
            }
            thinking.isVisible = false;
            answer.text += chunk.text;
            notifyListeners();
          },
          onError: (Object error) {
            // Failing works like pausing, so resuming is how to try again.
            _interrupt();
            _error = '$error';
            notifyListeners();
          },
          onDone: () {
            answer.interrupted = false;
            _answer = null;
            _status = ChatStatus.idle;
            thinking.isVisible = false;
            notifyListeners();
          },
        );
  }

  /// Stops the answer and keeps what has been written of it.
  void _interrupt() {
    _answer?.cancel();
    _answer = null;
    _status = ChatStatus.paused;
    thinking.isVisible = false;

    final ChatMessage answer = _messages.last;
    if (answer.text.isEmpty) {
      _messages.removeLast();
    } else {
      answer.interrupted = true;
    }
  }

  @override
  void dispose() {
    _answer?.cancel();
    thinking.dispose();
    super.dispose();
  }
}
