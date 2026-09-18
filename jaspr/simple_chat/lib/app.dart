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
    return main_(classes: 'app', [
      if (_session.status == SessionStatus.ready)
        ChatView(session: _session)
      else
        ModelLoader(session: _session, onLoad: _session.loadModel),
    ]);
  }
}
