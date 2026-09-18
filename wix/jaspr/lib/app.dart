import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'chat_session.dart';
import 'components/chat_view.dart';
import 'components/start_gate.dart';
import 'config.dart' as site;

/// The whole widget: a header, the transcript, and either the start button
/// or the box you type into.
class App extends StatefulComponent {
  /// Creates an [App].
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final ChatSession _session = ChatSession();

  @override
  void initState() {
    super.initState();
    // The session is plain Dart rather than a Jaspr component, so this is
    // what turns a change in it into a rebuild.
    _session.addListener(_onSessionChanged);
  }

  void _onSessionChanged() => setState(() {});

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'ai-chat', [
      div(classes: 'bar', [
        span(classes: 'dot', attributes: {'data-state': _state}, const []),
        span(classes: 'heading', [Component.text(site.heading)]),
        span(classes: 'spacer', const []),
        if (_session.status == ChatStatus.ready)
          button(
            classes: 'ghost',
            type: ButtonType.button,
            disabled: _session.isGenerating,
            onClick: _session.clear,
            [Component.text('Clear')],
          ),
      ]),
      ChatView(session: _session),
      if (_session.status != ChatStatus.ready)
        StartGate(session: _session, onStart: _session.loadModel),
      p(classes: 'foot', [Component.text(_footer)]),
    ]);
  }

  String get _state => switch (_session.status) {
    ChatStatus.idle => 'idle',
    ChatStatus.loading => 'loading',
    ChatStatus.ready => 'ready',
    ChatStatus.failed => 'error',
  };

  String get _footer => _session.status == ChatStatus.ready
      ? '${_session.modelId} · running locally · answers can be wrong'
      : 'Runs in your browser. Nothing you type leaves this device.';
}
