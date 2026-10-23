import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_ui/shared_ui.dart';

import 'answer_content.dart';
import 'generated_ui.dart';

export 'package:shared_ui/shared_ui.dart' show ChatStatus;

enum Role { user, model }

class ChatMessage {
  ChatMessage.user(this.text) : role = Role.user;

  ChatMessage.model() : role = Role.model, text = '';

  final Role role;

  /// Grows while a model answer streams in.
  ///
  /// An answer holds its A2UI blocks as the model wrote them, so that the
  /// model sees its earlier UI in the conversation.
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
  ChatController({required this.assistant, required this.ui});

  final Assistant assistant;

  /// Reads the text and the UI of each answer.
  final GeneratedUi ui;

  /// Shows the model's thinking while the user waits for an answer.
  final ThinkingBoxController thinking = ThinkingBoxController();

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  final Map<ChatMessage, AnswerContent> _contents = {};

  /// What [answer] shows: its text and its UI.
  AnswerContent contentOf(ChatMessage answer) => _contents[answer]!;

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
  ///
  /// Pressing a button in an answer's UI sends a message too.
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
    if (answer != null && answer.text.isEmpty) _remove(answer);
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
      _remove(paused);
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
      _contents[answer] = ui.read(onReply: send);
    }
    _current = answer;
    final AnswerContent content = contentOf(answer);

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
            // Inside an A2UI block, the model goes on exactly where it
            // stopped, and a space could break the JSON.
            final String text = isContinuation && !content.isInBlock
                ? joinContinuation(answer.text, chunk.text)
                : answer.text + chunk.text;
            content.add(text.substring(answer.text.length));
            answer.text = text;
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
            content.close();
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

  void _remove(ChatMessage answer) {
    _messages.remove(answer);
    _contents.remove(answer)!.dispose();
  }

  @override
  void dispose() {
    _answer?.cancel();
    thinking.dispose();
    for (final AnswerContent content in _contents.values) {
      content.dispose();
    }
    super.dispose();
  }
}
