import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_ui/shared_ui.dart';

export 'package:shared_ui/shared_ui.dart' show ChatStatus;

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

  /// The answer being written, or the paused one.
  ChatMessage? _current;
  ChatMessage? get currentAnswer => _current;

  /// Adds a user message, and starts an answer that takes it into account.
  ///
  /// While an answer is streaming, the message waits for that answer to
  /// finish. While paused, it starts a new answer straight away.
  void send(String text) {
    _messages.add(ChatMessage.user(text));
    if (_status == ChatStatus.streaming) {
      notifyListeners();
    } else {
      _startAnswer();
    }
  }

  void pause() {
    assert(_status == ChatStatus.streaming);
    _interrupt();
    notifyListeners();
  }

  /// Continues the paused answer in the same message, or writes a new one
  /// when the user added context after it.
  void resume() {
    assert(_status == ChatStatus.paused);
    _startAnswer();
  }

  /// Gives up on the paused answer, keeping what was written of it.
  void cancel() {
    assert(_status == ChatStatus.paused);
    final ChatMessage? answer = _current;
    if (answer != null && answer.text.isEmpty) _messages.remove(answer);
    _current = null;
    _status = ChatStatus.idle;
    _error = null;
    thinking
      ..isPaused = false
      ..isVisible = false;
    notifyListeners();
  }

  void _startAnswer() {
    // An answer paused before any text has nothing to keep once the user adds
    // context after it; the new answer takes its place.
    final ChatMessage? paused = _current;
    if (paused != null &&
        paused.text.isEmpty &&
        !identical(paused, _messages.last)) {
      _messages.remove(paused);
    }

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
    _current = answer;

    _status = ChatStatus.streaming;
    _error = null;
    thinking
      ..clear()
      ..isPaused = false
      ..isVisible = true;
    notifyListeners();

    // Set when this stream continues a paused answer, until its first text.
    bool isContinuation = answer.text.isNotEmpty;

    _answer = assistant
        .answer(history)
        .listen(
          (chunk) {
            if (chunk.isThought) {
              thinking.addChunk(chunk.text);
              return;
            }
            thinking.isVisible = false;
            answer.text = isContinuation
                ? joinContinuation(answer.text, chunk.text)
                : answer.text + chunk.text;
            isContinuation = false;
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
            _current = null;
            thinking.isVisible = false;
            // Context the user sent while this answer was streaming gets an
            // answer of its own.
            if (_messages.last.role == Role.user) {
              _startAnswer();
            } else {
              _status = ChatStatus.idle;
              notifyListeners();
            }
          },
        );
  }

  /// Stops the answer and keeps what has been written of it.
  void _interrupt() {
    _answer?.cancel();
    _answer = null;
    _status = ChatStatus.paused;
    // A thinking box still on screen stays there, with its dots stopped.
    thinking.isPaused = true;
    _current!.interrupted = true;
  }

  @override
  void dispose() {
    _answer?.cancel();
    thinking.dispose();
    super.dispose();
  }
}

/// Ends a word, so a word that follows needs a space.
final RegExp _wordEnd = RegExp(r'[\p{L}\p{N}.,!?;:]$', unicode: true);

/// Starts a word.
final RegExp _wordStart = RegExp(r'^[\p{L}\p{N}]', unicode: true);

/// Appends a resumed answer to the [partial] it continues.
///
/// The continuation is a new model turn, and a turn often starts without the
/// space that would separate it from the last word of [partial], which would
/// run 'dedicated' and 'water' together. A pause in the middle of a word gets
/// a stray space instead, which is the less likely and less harmful mistake.
///
/// Getting both cases right would mean asking the model to start by repeating
/// the last word of [partial], then dropping the overlap from the stream. That
/// needs buffering until the repeated word has fully arrived, and a fallback
/// for when the model does not repeat it, which is more than this app needs.
@visibleForTesting
String joinContinuation(String partial, String next) {
  final bool needsSpace =
      _wordEnd.hasMatch(partial) && _wordStart.hasMatch(next);
  return needsSpace ? '$partial $next' : '$partial$next';
}
