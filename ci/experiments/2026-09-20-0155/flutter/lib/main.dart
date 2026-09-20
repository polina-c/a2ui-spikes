import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'chat_page.dart';
import 'knowledge.dart';
import 'models.dart';
import 'picker_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter web paints into a canvas, so without this there is no DOM for a
  // screen reader - or for the test driver that records the CUJ.
  SemanticsBinding.instance.ensureSemantics();
  runApp(const SimpleChatApp());
}

class SimpleChatApp extends StatefulWidget {
  const SimpleChatApp({super.key});

  @override
  State<SimpleChatApp> createState() => _SimpleChatAppState();
}

class _SimpleChatAppState extends State<SimpleChatApp> {
  ModelChoice? _choice;
  Knowledge? _knowledge;

  @override
  void initState() {
    super.initState();
    Knowledge.load().then((loaded) {
      if (mounted) setState(() => _knowledge = loaded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final knowledge = _knowledge;
    final choice = _choice;
    return MaterialApp(
      title: 'Just Shining',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF14676B),
        useMaterial3: true,
      ),
      home: knowledge == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : choice == null
          ? PickerPage(onStart: (c) => setState(() => _choice = c))
          : ChatPage(
              choice: choice,
              knowledge: knowledge,
              onBack: () => setState(() => _choice = null),
            ),
    );
  }
}
