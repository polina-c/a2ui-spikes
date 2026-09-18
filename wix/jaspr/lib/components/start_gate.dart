import 'package:genui/web_llm.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../chat_session.dart';
import '../config.dart' as site;

/// What stands between the visitor and a few hundred megabytes.
///
/// The download does not start until it is asked for, and the size is said
/// before it is asked for, which is the whole reason this is a button rather
/// than something the page does on load.
class StartGate extends StatelessComponent {
  /// Creates a [StartGate].
  const StartGate({required this.session, required this.onStart, super.key});

  /// The session whose model is being loaded.
  final ChatSession session;

  /// Called when the visitor asks to start the download.
  final void Function() onStart;

  @override
  Component build(BuildContext context) {
    final String? error = session.error;

    return div(classes: 'gate', [
      p(classes: error != null ? 'err' : null, [
        Component.text(error ?? _invitation()),
      ]),
      if (session.status == ChatStatus.loading) _progress(),
      if (session.canStart)
        button(
          classes: 'primary',
          type: ButtonType.button,
          onClick: onStart,
          [Component.text(error != null ? 'Try again' : 'Start the chat')],
        ),
    ]);
  }

  String _invitation() {
    final int? mb = site.downloadMb[session.modelId];
    final String size = mb == null
        ? 'the model'
        : mb >= 1000
        ? 'about ${(mb / 1000).toStringAsFixed(1)} GB'
        : 'about $mb MB';
    return 'The assistant runs entirely in your browser. The first start '
        'downloads $size of model weights, which your browser then caches. '
        'Nothing you type leaves this device.';
  }

  Component _progress() {
    final LoadProgress? progress = session.progress;
    final int percent = ((progress?.fraction ?? 0) * 100).round();
    return div(classes: 'progress', [
      div(classes: 'track', [
        div(
          classes: 'fill',
          styles: Styles(raw: <String, String>{'width': '$percent%'}),
          const [],
        ),
      ]),
      p(classes: 'progress-text', [
        Component.text(progress?.message ?? 'Starting…'),
      ]),
    ]);
  }
}
