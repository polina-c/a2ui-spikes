// Ported from https://github.com/flutter/genui (packages/genui), which is
// Copyright 2025 The Flutter Authors and licensed BSD-3-Clause.

import 'package:a2ui_core/a2ui_core.dart' as core;

/// A base class for events produced while reading a model's response.
sealed class GenerationEvent {
  /// Creates a [GenerationEvent].
  const GenerationEvent();
}

/// An event containing a text chunk from the model.
class TextEvent extends GenerationEvent {
  /// Creates a [TextEvent] with the given [text].
  const TextEvent(this.text);

  /// The text content.
  final String text;
}

/// An event containing a parsed [core.A2uiMessage].
class A2uiMessageEvent extends GenerationEvent {
  /// Creates an [A2uiMessageEvent] with the given [message].
  const A2uiMessageEvent(this.message);

  /// The parsed message.
  final core.A2uiMessage message;
}
