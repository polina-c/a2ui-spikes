import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'chat.dart';
import 'knowledge.dart';
import 'models.dart';
import 'picker.dart';

/// The app: the picker until a model is chosen, then the chat.
class App extends StatefulComponent {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  ModelChoice? _choice;
  Knowledge? _knowledge;
  String? _error;

  @override
  void initState() {
    super.initState();
    Knowledge.load()
        .then((loaded) {
          if (mounted) setState(() => _knowledge = loaded);
        })
        .catchError((Object error) {
          if (mounted) setState(() => _error = '$error');
        });
  }

  @override
  Component build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return div(classes: 'picker', [
        p(classes: 'lead', [
          Component.text('The knowledge base did not load: $error'),
        ]),
      ]);
    }

    final knowledge = _knowledge;
    if (knowledge == null) {
      return div(classes: 'picker', [
        p(classes: 'lead', [Component.text('Loading...')]),
      ]);
    }

    final choice = _choice;
    return choice == null
        ? Picker(onStart: (c) => setState(() => _choice = c))
        : Chat(
            choice: choice,
            knowledge: knowledge,
            onBack: () => setState(() => _choice = null),
          );
  }
}
