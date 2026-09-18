import 'package:genui/web_llm.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../chat_session.dart';

/// The screen shown until a model is ready to answer.
///
/// The first load downloads a few gigabytes of weights, so this reports
/// progress rather than leaving the page looking broken for several minutes.
class ModelLoader extends StatelessComponent {
  /// Creates a [ModelLoader].
  const ModelLoader({required this.session, required this.onLoad, super.key});

  /// The session whose model is being loaded.
  final ChatSession session;

  /// Called when the user asks to start loading.
  final void Function() onLoad;

  @override
  Component build(BuildContext context) {
    return div(classes: 'loader', [
      h1([Component.text('Chat with generated UI')]),
      p([
        Component.text(
          'The model runs in this tab, so the conversation never leaves '
          'your machine. Loading it the first time downloads a few '
          'gigabytes; after that the browser has it cached.',
        ),
      ]),
      p(classes: 'model-id', [Component.text(session.modelId)]),
      switch (session.status) {
        SessionStatus.loading => _progress(),
        SessionStatus.failed => _failure(),
        _ => button(
          classes: 'primary',
          type: ButtonType.button,
          onClick: onLoad,
          [Component.text('Load the model')],
        ),
      },
    ]);
  }

  Component _progress() {
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

  Component _failure() => div(classes: 'failure', [
    p([Component.text(session.error ?? 'The model could not be loaded.')]),
    button(
      classes: 'primary',
      type: ButtonType.button,
      onClick: onLoad,
      [Component.text('Try again')],
    ),
  ]);
}
