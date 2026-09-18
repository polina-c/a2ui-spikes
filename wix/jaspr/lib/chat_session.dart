import 'dart:async';

import 'package:genui/web_llm.dart';

import 'config.dart' as site;
import 'grounding.dart';
import 'knowledge.dart';

/// How the model picks its next token.
///
/// The penalties are why an answer is not a reworded copy of the last one.
/// Measured on SmolLM2-360M, Qwen2.5-0.5B and Llama-3.2-1B: without them,
/// asking the same question twice returns character-for-character identical
/// text. These values are the mildest setting that works. Two stronger ones
/// were tried and both made answers worse: Qwen2.5-0.5B moved from correctly
/// answering `wix.com` to consistently answering `wiz.com`, and Llama-3.2-1B
/// started inventing URLs. Turning them up is not the lever it looks like.
const Sampling chatSampling = Sampling(
  temperature: 0.7,
  frequencyPenalty: 0.6,
  presencePenalty: 0.6,
  repetitionPenalty: 1.1,
);

/// Where the session is in getting a model ready to answer.
enum ChatStatus {
  /// Nothing downloaded and nothing downloading.
  idle,

  /// Downloading and compiling the model.
  loading,

  /// Ready to answer.
  ready,

  /// The model cannot be loaded here. See [ChatSession.error].
  failed,
}

/// Why a bubble looks the way it does.
enum TurnTone {
  /// An ordinary message.
  plain,

  /// An answer replaced because it invented a way to contact the business.
  withheld,

  /// A message the model never finished.
  failed,
}

/// One bubble in the transcript.
class Turn {
  /// Creates a [Turn].
  Turn({required this.isUser, this.text = '', this.tone = TurnTone.plain});

  /// Whether the visitor said it.
  final bool isUser;

  /// What was said. Grows while the model streams.
  String text;

  /// Why the bubble looks the way it does.
  TurnTone tone;
}

/// The state behind the chat: the model, the transcript, and the history.
///
/// This is plain Dart rather than a Jaspr component, so the page listens to
/// it and rebuilds. The transcript and the history are deliberately two
/// different lists: the greeting is in the first and not the second, because
/// an assistant turn that arrives before the visitor has said anything reads
/// to a small model as the pattern it should follow, and it will then answer
/// every question with a rewording of the greeting.
class ChatSession {
  /// Creates a [ChatSession] that will run [model] in this tab.
  ChatSession({
    this.entries = knowledge,
    String model = site.modelId,
    this.systemInstruction = site.systemPrompt,
  }) : _client = WebLlmClient(modelId: model, sampling: chatSampling) {
    if (site.greeting.isNotEmpty) {
      _turns.add(Turn(isUser: false, text: site.greeting));
    }
    unawaited(_checkSupport());
  }

  /// What the assistant is allowed to answer from.
  final List<KnowledgeEntry> entries;

  /// How the assistant answers, as opposed to what it knows.
  final String systemInstruction;

  final WebLlmClient _client;
  final List<Turn> _turns = <Turn>[];
  final List<ChatMessage> _history = <ChatMessage>[];
  final List<void Function()> _listeners = <void Function()>[];

  ChatStatus _status = ChatStatus.idle;
  bool _unsupported = false;
  LoadProgress? _progress;
  String? _error;
  bool _generating = false;

  /// The transcript, oldest first.
  List<Turn> get turns => List<Turn>.unmodifiable(_turns);

  /// Where the session is in getting a model ready.
  ChatStatus get status => _status;

  /// How far along the download is, while [status] is [ChatStatus.loading].
  LoadProgress? get progress => _progress;

  /// What went wrong, if anything.
  String? get error => _error;

  /// The model this page runs.
  String get modelId => _client.modelId;

  /// Whether an answer is being generated right now.
  bool get isGenerating => _generating;

  /// Whether the visitor can send a message.
  bool get canSend => _status == ChatStatus.ready && !_generating;

  /// Whether starting the model is worth offering.
  ///
  /// False once something has gone wrong that trying again cannot fix, so
  /// the page can explain instead of showing a button that only fails.
  bool get canStart =>
      !_unsupported &&
      (_status == ChatStatus.idle || _status == ChatStatus.failed);

  /// Registers [listener] to be called whenever anything here changes.
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Unregisters [listener].
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Says so up front when this browser cannot run a model at all.
  ///
  /// Worth knowing before the visitor clicks: a browser without WebGPU
  /// cannot be rescued by waiting, and a start button that only fails is
  /// worse than a sentence explaining why there is none.
  Future<void> _checkSupport() async {
    if (!await _shimLoaded()) return;
    if (await WebLlmClient.hasWebGpuAdapter()) return;
    // A visitor quick enough to click before this answers is already being
    // told what went wrong by loadModel, and has the better error.
    if (_status != ChatStatus.idle) return;
    _unsupported = true;
    _fail(
      WebLlmClient.hasWebGpu
          ? 'This chat needs a GPU that WebGPU can use, and this browser has '
                'none to offer.'
          : 'This chat needs WebGPU, which this browser does not expose. It '
                'works in a recent Chrome or Edge, or in Safari 26 and later.',
    );
  }

  /// Waits for `web_llm.js`, which is a module and so runs after the app.
  ///
  /// Gives up rather than waiting forever: a page that never loads it is a
  /// page with the script tag missing, which is worth reporting as itself.
  Future<bool> _shimLoaded() async {
    for (int attempt = 0; attempt < 40; attempt++) {
      if (WebLlmClient.isAvailable) return true;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _unsupported = true;
    _fail(
      'The chat did not load. Check that web_llm.js is served next to '
      'index.html and that the page can reach the CDN it imports.',
    );
    return false;
  }

  /// Downloads and compiles the model.
  ///
  /// This is the slow part, and the reason there is a button in front of it:
  /// the first visit fetches hundreds of megabytes of weights. The browser
  /// caches them, so later visits start in seconds.
  Future<void> loadModel() async {
    if (!canStart) return;
    if (!await _shimLoaded()) return;

    _status = ChatStatus.loading;
    _error = null;
    _changed();

    try {
      await _client.load(
        onProgress: (LoadProgress progress) {
          _progress = progress;
          _changed();
        },
      );
      _status = ChatStatus.ready;
    } catch (error) {
      _status = ChatStatus.failed;
      _error = 'Could not load the model: ${_reason(error)}';
    }
    _changed();
  }

  /// Asks [question] and streams the answer into a new bubble.
  Future<void> send(String question) async {
    final String text = question.trim();
    if (text.isEmpty || !canSend) return;

    _turns.add(Turn(isUser: true, text: text));
    _history.add(ChatMessage.user(text));

    final Turn reply = Turn(isUser: false);
    _turns.add(reply);
    _generating = true;
    _changed();

    final StringBuffer answer = StringBuffer();
    try {
      await for (final String chunk in _client.generate(_messagesFor(text))) {
        answer.write(chunk);
        reply.text = answer.toString();
        _changed();
      }
    } catch (error) {
      reply.tone = TurnTone.failed;
      if (answer.isEmpty) {
        reply.text = 'Sorry, that response failed: ${_reason(error)}';
      }
    }

    reply.text = reply.text.trim();
    if (reply.tone != TurnTone.failed && _invented(reply.text) != null) {
      reply.text = withheldAnswer;
      reply.tone = TurnTone.withheld;
    }

    // What the visitor was shown is what the model is told it said, so a
    // withheld answer cannot be quoted back as if it had been given.
    _history.add(ChatMessage.model(reply.text));
    _generating = false;
    _changed();
  }

  /// Abandons the answer in flight, if there is one.
  void stop() {
    if (_generating) _client.interrupt();
  }

  /// Empties the transcript and the history, keeping the model loaded.
  void clear() {
    if (_generating) return;
    _turns.clear();
    _history.clear();
    if (site.greeting.isNotEmpty) {
      _turns.add(Turn(isUser: false, text: site.greeting));
    }
    _changed();
  }

  /// The contact detail this answer made up, if it made one up.
  ///
  /// Only meaningful with site content to check against: without it there is
  /// nothing to tell an invented phone number from a real one.
  String? _invented(String answer) {
    if (entries.isEmpty) return null;
    return inventedContactDetail(answer, renderEntries(entries));
  }

  /// The request for [question]: a fresh system message, then the history.
  ///
  /// The system message is rebuilt every time because which site content it
  /// carries depends on what was asked.
  List<ChatMessage> _messagesFor(String question) {
    final List<ChatMessage> recent = _history.length > maxHistory
        ? _history.sublist(_history.length - maxHistory)
        : _history;
    return <ChatMessage>[
      ChatMessage.system(_systemMessage(question)),
      ...recent,
    ];
  }

  String _systemMessage(String question) {
    final String content = contextFor(entries, question);
    if (content.isEmpty) return systemInstruction;
    return '$systemInstruction\n\n$groundingInstruction\n\n$content';
  }

  void _fail(String message) {
    _status = ChatStatus.failed;
    _error = message;
    _changed();
  }

  String _reason(Object error) {
    final String message = '$error';
    return message.length > 220 ? '${message.substring(0, 220)}…' : message;
  }

  void _changed() {
    for (final void Function() listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }

  /// Releases everything this session owns.
  void dispose() {
    stop();
    _listeners.clear();
  }
}
