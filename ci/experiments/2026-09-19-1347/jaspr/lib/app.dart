import 'package:jaspr/jaspr.dart';

import 'chat.dart';
import 'models.dart';
import 'picker.dart';

class App extends StatefulComponent {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  ModelChoice? _choice;

  @override
  Component build(BuildContext context) {
    final choice = _choice;
    // Keying the chat on the model throws away the old processor and the old
    // conversation, which is what changing the model should do.
    return choice == null
        ? Picker(onStart: (c) => setState(() => _choice = c))
        : Chat(
            key: ValueKey(choice.modelId),
            choice: choice,
            onRestart: () => setState(() => _choice = null),
          );
  }
}
