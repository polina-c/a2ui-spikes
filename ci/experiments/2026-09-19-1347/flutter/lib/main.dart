import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:genui/genui.dart';

import 'chat_page.dart';
import 'models.dart';
import 'picker_page.dart';

void main() {
  // Flutter web paints into a canvas, so without the semantics tree there is
  // no DOM for a screen reader, or for the CUJ driver, to read. Turning it on
  // for good costs little and makes the app both testable and accessible.
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();

  configureLogging(
    logCallback: (level, msg) => debugPrint('GenUI $level: $msg'),
  );
  runApp(const SimpleChatApp());
}

class SimpleChatApp extends StatefulWidget {
  const SimpleChatApp({super.key});

  @override
  State<SimpleChatApp> createState() => _SimpleChatAppState();
}

class _SimpleChatAppState extends State<SimpleChatApp> {
  ModelChoice? _choice;

  @override
  Widget build(BuildContext context) {
    final choice = _choice;
    return MaterialApp(
      title: 'Just Shining',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A6ACB),
        useMaterial3: true,
      ),
      // Keying the chat on the model throws away the old conversation when the
      // model changes, which is what changing the model should do.
      home: choice == null
          ? PickerPage(onStart: (c) => setState(() => _choice = c))
          : ChatPage(
              key: ValueKey(choice.modelId),
              choice: choice,
              onRestart: () => setState(() => _choice = null),
            ),
    );
  }
}
