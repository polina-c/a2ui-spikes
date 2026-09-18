import 'dart:async';

import 'package:genui/web_llm.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'chat_session.dart';
import 'components/chat_view.dart';
import 'components/model_loader.dart';

/// The whole app: load a model, then chat with it.
class App extends StatefulComponent {
  /// Creates an [App].
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  // There is no session until the user has chosen a context window, because
  // the window is fixed when the model is loaded and a session is built
  // around one model.
  ChatSession? _session;

  void _onSessionChanged() => setState(() {});

  /// Starts a session with [window] and loads its model.
  ///
  /// A retry after a failed load comes back through here too, so a window
  /// that was too large for the GPU can be made smaller and tried again.
  void _load(ContextWindow window) {
    _disposeSession();
    final ChatSession session = ChatSession(contextWindow: window)
      ..addListener(_onSessionChanged);
    setState(() => _session = session);
    unawaited(session.loadModel());
  }

  void _disposeSession() {
    final ChatSession? session = _session;
    if (session == null) return;
    session.removeListener(_onSessionChanged);
    session.dispose();
    _session = null;
  }

  @override
  void dispose() {
    _disposeSession();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final ChatSession? session = _session;
    return main_(classes: 'app', [
      if (session != null && session.status == SessionStatus.ready)
        ChatView(session: session)
      else
        ModelLoader(session: session, onLoad: _load),
    ]);
  }
}
