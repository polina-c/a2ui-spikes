import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genai_primitives/genai_primitives.dart';

import '../engine/surface_controller.dart';
import '../model/generation_events.dart';
import '../primitives/logging.dart';
import '../transport/a2ui_parser_transformer.dart';

export 'package:genai_primitives/genai_primitives.dart'
    show ChatMessage, ChatMessageRole;

/// A model that answers a conversation with a stream of text.
///
/// This is the whole surface a [Conversation] needs from an inference
/// backend, which is what lets the same conversation run against WebLLM in
/// the browser or against anything else that streams tokens.
abstract interface class TextGenerator {
  /// Streams the answer to [messages], chunk by chunk.
  Stream<String> generate(List<ChatMessage> messages);
}

/// A conversation with a model that answers with UI as well as words.
///
/// This is the piece that makes a generated UI a dialogue rather than a
/// render: it keeps the history, splits each response into the prose the
/// user reads and the A2UI messages that build surfaces, and turns what the
/// user does with those surfaces into the next turn.
class Conversation {
  /// Creates a [Conversation].
  ///
  /// [systemPrompt] usually comes from a `PromptBuilder`. It is recorded as
  /// the first message of [history], so a backend that has no separate
  /// notion of a system prompt still receives it.
  Conversation({
    required this.generator,
    required this.controller,
    required String systemPrompt,
  }) {
    _history.add(ChatMessage.system(systemPrompt));
    _actions = controller.actions.listen(_onUiAction);
  }

  /// The model that answers.
  final TextGenerator generator;

  /// The surfaces the answers build.
  final SurfaceController controller;

  final List<ChatMessage> _history = [];
  late final StreamSubscription<UiActionEvent> _actions;

  final StreamController<String> _text = StreamController<String>.broadcast();
  final StreamController<bool> _busy = StreamController<bool>.broadcast();
  final StreamController<Object> _errors =
      StreamController<Object>.broadcast();

  bool _isGenerating = false;

  /// The prose of the model's answers, as it arrives.
  ///
  /// The A2UI blocks are stripped out; they reach [controller] instead.
  Stream<String> get text => _text.stream;

  /// Whether a response is currently being generated.
  Stream<bool> get isGenerating => _busy.stream;

  /// Errors from generating or from parsing a response.
  Stream<Object> get errors => _errors.stream;

  /// The conversation so far, oldest first.
  List<ChatMessage> get history => List.unmodifiable(_history);

  /// Whether a response is in flight right now.
  bool get busy => _isGenerating;

  /// Sends [text] as the user's turn and streams the answer.
  Future<void> send(String text) {
    if (text.trim().isEmpty) return Future<void>.value();
    return _turn(ChatMessage.user(text));
  }

  Future<void> _turn(ChatMessage message) async {
    // One turn at a time: the history is what the next request is built
    // from, so a second request started mid-answer would be built from a
    // half-written one.
    if (_isGenerating) {
      genUiLogger.warning('Ignoring a turn sent while one is in flight.');
      return;
    }
    _isGenerating = true;
    if (!_busy.isClosed) _busy.add(true);
    _history.add(message);

    final buffer = StringBuffer();
    try {
      final Stream<GenerationEvent> events = generator
          .generate(List.of(_history))
          .transform(const A2uiParserTransformer());

      await for (final GenerationEvent event in events) {
        switch (event) {
          case TextEvent(:final String text):
            buffer.write(text);
            if (!_text.isClosed) _text.add(text);
          case A2uiMessageEvent(:final core.A2uiMessage message):
            // Record what was emitted, not the prose around it, so that a
            // later turn can refer to a surface it already built.
            buffer.write(jsonEncode(message.toJson()));
            controller.handleMessage(message);
        }
      }
    } catch (error, stackTrace) {
      genUiLogger.severe('Generation failed', error, stackTrace);
      if (!_errors.isClosed) _errors.add(error);
    } finally {
      _history.add(ChatMessage.model(buffer.toString()));
      _isGenerating = false;
      if (!_busy.isClosed) _busy.add(false);
    }
  }

  void _onUiAction(UiActionEvent event) {
    // A press on a generated button is a turn like any other. It is sent as
    // JSON rather than prose because the model wrote the component that
    // raised it and named the action itself.
    unawaited(
      _turn(
        ChatMessage.user(
          'The user interacted with the UI you generated:\n'
          '```json\n${jsonEncode(event.toJson())}\n```',
        ),
      ),
    );
  }

  /// Stops listening to [controller] and closes the streams.
  void dispose() {
    _actions.cancel();
    _text.close();
    _busy.close();
    _errors.close();
  }
}
