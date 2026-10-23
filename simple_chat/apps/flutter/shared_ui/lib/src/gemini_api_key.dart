import 'dart:io';

import 'package:flutter/foundation.dart';

/// Takes the key from `--dart-define=GEMINI_API_KEY=...`, or, outside the
/// browser, from the environment.
///
/// Returns an empty string when neither has it.
String loadGeminiApiKey() {
  const String defined = String.fromEnvironment('GEMINI_API_KEY');
  if (defined.isNotEmpty || kIsWeb) return defined;
  return Platform.environment['GEMINI_API_KEY'] ?? '';
}
