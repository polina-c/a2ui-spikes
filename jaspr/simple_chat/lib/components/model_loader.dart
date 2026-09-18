import 'package:genui/web_llm.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../chat_session.dart';

/// Which of WebLLM's two ways of sizing the context window is in use.
enum _WindowMode {
  /// Whatever the model's own configuration asks for.
  modelDefault,

  /// A window of a chosen size that fills up and then refuses more.
  fixed,

  /// A window of a chosen size that drops its oldest tokens.
  sliding,
}

/// The screen shown until a model is ready to answer.
///
/// It does two jobs. It takes the settings that have to be chosen before the
/// model is loaded, because the context window is fixed when the engine is
/// built and cannot be changed afterwards; and once loading starts it
/// reports progress, since the first load downloads a few gigabytes of
/// weights and would otherwise leave the page looking broken for minutes.
class ModelLoader extends StatefulComponent {
  /// Creates a [ModelLoader].
  const ModelLoader({required this.session, required this.onLoad, super.key});

  /// The session being loaded, or null before the user has asked for one.
  final ChatSession? session;

  /// Called when the user asks to load the model with [ContextWindow].
  final void Function(ContextWindow window) onLoad;

  @override
  State<ModelLoader> createState() => _ModelLoaderState();
}

class _ModelLoaderState extends State<ModelLoader> {
  /// A window large enough that the system prompt leaves room for a
  /// conversation, and small enough to stay well inside a laptop GPU.
  static const int _defaultTokens = 8192;

  /// The step the size fields move in, and the smallest window offered.
  ///
  /// The key-value cache is allocated from the window, so the sizes that
  /// matter are far apart; stepping by one token would only make the field
  /// tedious.
  static const int _step = 256;

  _WindowMode _mode = _WindowMode.fixed;
  int? _tokens = _defaultTokens;
  int? _sinkTokens = 0;

  @override
  void initState() {
    super.initState();
    // A sliding window that cuts into the system prompt takes the catalog
    // with it and the model stops answering in A2UI, so the sink starts at
    // the size of the prompt rounded up to a whole step.
    _sinkTokens = (systemPromptTokens / _step).ceil() * _step;
  }

  /// The window the fields describe, or null if they do not describe one.
  ContextWindow? get _window {
    final int? tokens = _tokens;
    final int sink = _sinkTokens ?? -1;
    return switch (_mode) {
      _WindowMode.modelDefault => const ContextWindow.modelDefault(),
      _WindowMode.fixed when tokens != null && tokens > 0 =>
        ContextWindow.fixed(tokens),
      // The sink is held out of the sliding part of the window, so a sink as
      // large as the window leaves nothing to slide.
      _WindowMode.sliding when tokens != null && sink >= 0 && tokens > sink =>
        ContextWindow.sliding(tokens, attentionSinkTokens: sink),
      _ => null,
    };
  }

  @override
  Component build(BuildContext context) {
    final ChatSession? session = component.session;
    final bool isLoading = session?.status == SessionStatus.loading;

    return div(classes: 'loader', [
      h1([Component.text('Chat with generated UI')]),
      p([
        Component.text(
          'The model runs in this tab, so the conversation never leaves '
          'your machine. Loading it the first time downloads a few '
          'gigabytes; after that the browser has it cached.',
        ),
      ]),
      p(classes: 'model-id', [
        Component.text('Model: '),
        // The ID stays in monospace on its own, so the label does not read
        // as part of it.
        Component.element(
          tag: 'code',
          children: [
            Component.text(session?.modelId ?? WebLlmClient.defaultModelId),
          ],
        ),
      ]),
      if (isLoading) _progress(session!) else ..._setup(session),
    ]);
  }

  /// The settings and the button that starts the load.
  List<Component> _setup(ChatSession? session) {
    final ContextWindow? window = _window;
    return [
      if (session?.status == SessionStatus.failed) _failure(session!),
      _settings(),
      button(
        classes: 'primary',
        type: ButtonType.button,
        disabled: window == null,
        onClick: window == null ? null : () => component.onLoad(window),
        [
          Component.text(
            session?.status == SessionStatus.failed
                ? 'Try again'
                : 'Load the model',
          ),
        ],
      ),
    ];
  }

  Component _settings() {
    final int? modelDefault = WebLlmClient.defaultContextWindowSize(
      WebLlmClient.defaultModelId,
    );
    return div(classes: 'settings', [
      p(classes: 'settings-title', [Component.text('Context window')]),
      p(classes: 'hint', [
        Component.text(
          'The model re-reads the whole conversation on every turn, and the '
          'prompt that teaches it the catalog is about $systemPromptTokens '
          'tokens of that before you have asked anything. When the window '
          'fills, the next message is refused however short it is. A larger '
          'window holds more turns but needs more GPU memory; a sliding one '
          'runs forever but forgets what falls out of it.',
        ),
      ]),
      _option(
        _WindowMode.modelDefault,
        modelDefault == null
            ? "The model's own setting"
            : "The model's own setting, $modelDefault tokens",
        const [],
      ),
      _option(_WindowMode.fixed, 'A fixed window of', [
        _number(
          value: _tokens,
          enabled: _mode == _WindowMode.fixed,
          onChanged: (int? tokens) => setState(() => _tokens = tokens),
        ),
        span([Component.text('tokens')]),
      ]),
      _option(_WindowMode.sliding, 'A sliding window of', [
        _number(
          value: _tokens,
          enabled: _mode == _WindowMode.sliding,
          onChanged: (int? tokens) => setState(() => _tokens = tokens),
        ),
        span([Component.text('tokens, keeping the first')]),
        _number(
          value: _sinkTokens,
          enabled: _mode == _WindowMode.sliding,
          onChanged: (int? sink) => setState(() => _sinkTokens = sink),
        ),
        span([Component.text('of them')]),
      ]),
      if (_window == null)
        p(classes: 'hint invalid', [
          Component.text(
            _mode == _WindowMode.sliding
                ? 'The window has to be a positive number of tokens, and '
                      'larger than the part of it that is kept.'
                : 'The window has to be a positive number of tokens.',
          ),
        ]),
    ]);
  }

  /// One radio button, with the fields that belong to it beside it.
  Component _option(_WindowMode mode, String text, List<Component> fields) {
    return div(classes: 'option', [
      label([
        input<bool>(
          type: InputType.radio,
          name: 'context-window',
          checked: _mode == mode,
          // Radios also fire this for the one being turned off, and acting
          // on that would set the mode back to whatever the user just left.
          onChange: (bool selected) {
            if (selected) setState(() => _mode = mode);
          },
        ),
        span([Component.text(text)]),
        ...fields,
      ]),
    ]);
  }

  /// A token count field. Empty reads as null, which disables the button.
  Component _number({
    required int? value,
    required bool enabled,
    required void Function(int?) onChanged,
  }) {
    return input<num>(
      type: InputType.number,
      classes: 'tokens',
      value: value?.toString() ?? '',
      disabled: !enabled,
      attributes: const {
        'min': '$_step',
        'step': '$_step',
        'inputmode': 'numeric',
      },
      // An empty field has no number in it, which arrives here as NaN.
      onInput: (num tokens) => onChanged(tokens.isNaN ? null : tokens.round()),
    );
  }

  Component _progress(ChatSession session) {
    final LoadProgress? progress = session.progress;
    final int percent = ((progress?.fraction ?? 0) * 100).round();
    return div(classes: 'progress', [
      div(classes: 'bar', [
        div(
          classes: 'fill',
          styles: Styles(raw: {'width': '$percent%'}),
          const [],
        ),
      ]),
      p(classes: 'progress-text', [
        Component.text(progress?.message ?? 'Starting…'),
      ]),
    ]);
  }

  Component _failure(ChatSession session) => div(classes: 'failure', [
    p([Component.text(session.error ?? 'The model could not be loaded.')]),
  ]);
}
