import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';
import 'package:genui/web_llm.dart';

/// One entry in the transcript.
///
/// A turn is either words or a surface, never both: the model's prose and
/// the UI it generates arrive interleaved in one response, and showing them
/// in the order they arrived is what makes a reply read as a single answer.
sealed class Turn {
  const Turn();
}

/// Something the user or the model said.
class TextTurn extends Turn {
  /// Creates a [TextTurn].
  TextTurn({required this.isUser, String text = ''}) : _text = text;

  /// Whether the user said it.
  final bool isUser;

  String _text;

  /// What was said. Grows as the model streams.
  String get text => _text;

  /// Appends a streamed chunk.
  void append(String chunk) => _text += chunk;

  /// Whether there is nothing to show yet.
  bool get isEmpty => _text.trim().isEmpty;
}

/// A surface the model generated.
class SurfaceTurn extends Turn {
  /// Creates a [SurfaceTurn].
  const SurfaceTurn(this.surfaceId);

  /// The surface to render.
  final String surfaceId;
}

// Images need URLs this app has none of, so offering the model an Image
// component would only produce broken ones.
final WebCatalog _catalog = basicCatalogWithoutAssets();

/// The prompt that teaches the model the catalog and the A2UI protocol.
///
/// It is the same for every session and it is sent on every turn, so it is
/// the floor under how large a context window has to be: whatever is left
/// after it is what the conversation has to fit in.
final String systemPrompt = PromptBuilder.chat(
  catalog: _catalog,
  systemPromptFragments: [
    'You are a helpful assistant. Keep your prose short: a sentence or '
        'two alongside the UI, not a summary of it.',
    PromptFragments.acknowledgeUser(),
    PromptFragments.requireAtLeastOneSubmitElement(
      prefix: PromptBuilder.defaultImportancePrefix,
    ),
  ],
).systemPromptJoined();

/// Roughly how many tokens [systemPrompt] takes.
///
/// Four characters to the token is the usual rule of thumb for English, and
/// this is only used to tell the user how much of the window is spoken for
/// before they have asked anything, so being off by a tenth does not matter.
final int systemPromptTokens = (systemPrompt.length / 4).round();

/// Where the session is in getting a model ready to answer.
enum SessionStatus {
  /// No model loaded and none loading.
  idle,

  /// Downloading and compiling the model.
  loading,

  /// Ready to answer.
  ready,

  /// The model could not be loaded. See [ChatSession.error].
  failed,
}

/// The state behind the chat screen.
///
/// It owns the three pieces that make a generated UI a conversation: the
/// [SurfaceController] that holds the surfaces, the [Conversation] that
/// talks to the model, and the transcript that puts them in order.
class ChatSession {
  /// Creates a [ChatSession] that will run [modelId] in this tab.
  ///
  /// [contextWindow] is how much of the conversation the model keeps in
  /// view. It is fixed when the model is loaded, so a session is made once
  /// the user has chosen it rather than before.
  ChatSession({
    String modelId = WebLlmClient.defaultModelId,
    ContextWindow contextWindow = const ContextWindow.modelDefault(),
  }) : _client = WebLlmClient(modelId: modelId, contextWindow: contextWindow) {
    _controller = SurfaceController(catalogs: [_catalog]);
    _conversation = Conversation(
      generator: _client,
      controller: _controller,
      systemPrompt: systemPrompt,
    );

    _subscriptions = [
      _controller.surfaceUpdates.listen(_onSurfaceUpdate),
      _controller.errors.listen((error) => _report('$error')),
      _conversation.text.listen(_onText),
      _conversation.errors.listen((error) => _report('$error')),
      _conversation.isGenerating.listen((_) => _changed()),
    ];
  }

  final WebLlmClient _client;
  late final SurfaceController _controller;
  late final Conversation _conversation;
  late final List<StreamSubscription<Object?>> _subscriptions;

  final List<Turn> _turns = [];
  final List<void Function()> _listeners = [];

  SessionStatus _status = SessionStatus.idle;
  LoadProgress? _progress;
  String? _error;
  TextTurn? _openReply;

  /// The transcript, oldest first.
  List<Turn> get turns => List.unmodifiable(_turns);

  /// Where the session is in getting a model ready.
  SessionStatus get status => _status;

  /// How far along loading the model is, while [status] is
  /// [SessionStatus.loading].
  LoadProgress? get progress => _progress;

  /// What went wrong, if anything.
  String? get error => _error;

  /// The model being run.
  String get modelId => _client.modelId;

  /// How much of the conversation the model keeps in view.
  ContextWindow get contextWindow => _client.contextWindow;

  /// Whether a response is being generated right now.
  bool get isGenerating => _conversation.busy;

  /// Whether the user can send a message.
  bool get canSend => _status == SessionStatus.ready && !isGenerating;

  /// The surface with this ID, for rendering.
  core.SurfaceModel<CatalogItem>? surface(String surfaceId) =>
      _controller.surface(surfaceId);

  /// Registers [listener] to be called whenever anything here changes.
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Unregisters [listener].
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Downloads and compiles the model.
  ///
  /// This is the slow part: the weights are a few gigabytes on the first
  /// run. The browser caches them, so later runs start in seconds.
  Future<void> loadModel() async {
    if (_status == SessionStatus.loading || _status == SessionStatus.ready) {
      return;
    }
    if (!WebLlmClient.isAvailable) {
      _fail(
        'WebLLM did not load. Check that web_llm.js is served next to '
        'index.html, that the page can reach the CDN it imports, and that '
        'the page is served over http rather than opened as a file.',
      );
      return;
    }
    // Asked before starting, because a browser that cannot run a model at
    // all should say so rather than show a progress bar that never moves.
    if (!await WebLlmClient.hasWebGpuAdapter()) {
      _fail(
        WebLlmClient.hasWebGpu
            ? 'WebGPU is here but has no GPU to offer, which is what a '
                  'headless or software-rendered browser looks like. The '
                  'model needs a real one.'
            : 'This browser does not have WebGPU, which the model runs on. '
                  'Chrome and Edge 113 and later have it; Safari 18 has it; '
                  'in Firefox it is behind dom.webgpu.enabled.',
      );
      return;
    }

    _status = SessionStatus.loading;
    _error = null;
    _changed();

    try {
      await _client.load(
        onProgress: (LoadProgress progress) {
          _progress = progress;
          _changed();
        },
      );
      _status = SessionStatus.ready;
    } catch (error) {
      _status = SessionStatus.failed;
      _error = '$error';
    }
    _changed();
  }

  void _fail(String message) {
    _status = SessionStatus.failed;
    _error = message;
    _changed();
  }

  /// Sends [text] as the user's turn.
  Future<void> send(String text) async {
    if (text.trim().isEmpty || !canSend) return;
    _turns.add(TextTurn(isUser: true, text: text));
    // The next response gets a bubble of its own rather than being appended
    // to the last one.
    _openReply = null;
    _changed();
    await _conversation.send(text);
  }

  void _onText(String chunk) {
    // A surface arriving mid-response closes the open bubble, so prose
    // after a UI starts a new one below it rather than jumping above.
    final TextTurn reply = _openReply ??= () {
      final turn = TextTurn(isUser: false);
      _turns.add(turn);
      return turn;
    }();
    reply.append(chunk);
    _changed();
  }

  void _onSurfaceUpdate(SurfaceUpdate update) {
    switch (update) {
      case SurfaceAdded(:final String surfaceId):
        _openReply = null;
        _turns.add(SurfaceTurn(surfaceId));
      case SurfaceRemoved(:final String surfaceId):
        _turns.removeWhere(
          (turn) => turn is SurfaceTurn && turn.surfaceId == surfaceId,
        );
    }
    _changed();
  }

  void _report(String message) {
    _error = message;
    _changed();
  }

  /// Clears the last reported error.
  void dismissError() {
    _error = null;
    _changed();
  }

  void _changed() {
    for (final void Function() listener in List.of(_listeners)) {
      listener();
    }
  }

  /// Releases everything this session owns.
  void dispose() {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      subscription.cancel();
    }
    _conversation.dispose();
    _controller.dispose();
    _listeners.clear();
  }
}
