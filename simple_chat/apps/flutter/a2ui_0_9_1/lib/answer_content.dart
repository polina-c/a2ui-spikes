import 'dart:math';

import 'package:a2ui_agent/a2ui_agent.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';

/// A piece of an answer, as the user sees it.
sealed class AnswerPart {}

/// Text of an answer, in Markdown.
final class MarkdownPart extends AnswerPart {
  MarkdownPart(this.markdown);

  /// Grows while the answer streams in.
  String markdown;
}

/// UI the model generated for an answer.
final class SurfacePart extends AnswerPart {
  SurfacePart(this.surface);

  final SurfaceModel<ComponentImplementation> surface;
}

/// What an answer shows: its text, and the surfaces its A2UI blocks build,
/// read from the model's output as it streams.
///
/// Each answer renders its own surfaces, so answers never clash over a
/// surface id.
class AnswerContent {
  AnswerContent({
    required this._stream,
    required CatalogImplementation catalog,
    required void Function(A2uiRendererAction action) onAction,
  }) : _renderer = MessageProcessor<ComponentImplementation>(
         catalogs: [catalog],
         defaultVersion: catalog.protocolVersion,
       ) {
    _renderer.model.onAction.subscribe(onAction);
    _renderer.model.onSurfaceCreated.subscribe(
      (surface) => _parts.add(SurfacePart(surface)),
    );
    _renderer.model.onSurfaceDeleted.subscribe(
      (id) => _parts.removeWhere(
        (part) => part is SurfacePart && part.surface.id == id,
      ),
    );
  }

  static const String _openTag = '<a2ui-json>';
  static const String _closeTag = '</a2ui-json>';

  /// Reads the model's output into text and A2UI messages.
  final ResponseStream _stream;

  /// Turns the A2UI messages into surfaces.
  final MessageProcessor<ComponentImplementation> _renderer;

  final List<AnswerPart> _parts = [];
  List<AnswerPart> get parts => List.unmodifiable(_parts);

  /// The model's output so far, as it wrote it.
  final StringBuffer _output = StringBuffer();

  /// Why the UI stopped rendering, if the model wrote A2UI that does not
  /// read or that the renderer rejects.
  A2uiError? _error;
  A2uiError? get error => _error;

  /// Where the output stops being read as A2UI, once there is an [error].
  int _failedAt = 0;

  /// The text after [_failedAt], once there is an [error].
  MarkdownPart? _rest;

  /// Whether the output so far ends inside an A2UI block.
  bool get isInBlock {
    final String output = '$_output';
    return output.lastIndexOf(_openTag) > output.lastIndexOf(_closeTag);
  }

  /// Reads the next [chunk] of the model's output.
  void add(String chunk) {
    int from = _output.length;
    _output.write(chunk);
    if (_error != null) return _showRest();

    // A read that fails loses the parts it would have returned, so the chunk
    // is read in pieces that end after each open tag. The text before a block
    // then shows even when the block fails in the same chunk.
    final String output = '$_output';
    final List<int> ends = [
      for (final Match tag in _openTag.allMatches(
        output,
        max(0, from - _openTag.length + 1),
      ))
        tag.end,
      output.length,
    ];
    for (final int end in ends) {
      if (!_read(() => _stream.feed(output.substring(from, end)), from)) {
        return;
      }
      from = end;
    }
  }

  /// Ends the answer, showing the text held back in case it started a tag.
  void close() {
    if (_error == null) _read(_stream.close, _output.length);
  }

  /// Shows the parts that [read] returns for the output from [from] on, and
  /// whether it succeeded.
  ///
  /// The stream cannot go on after a failure, so from the block that failed
  /// onward, the answer shows its text, with the A2UI left out.
  bool _read(List<ResponsePart> Function() read, int from) {
    try {
      _show(read());
      return true;
    } on A2uiError catch (error) {
      _error = error;
      final int block = '$_output'.lastIndexOf(_openTag, from);
      _failedAt = block >= 0 ? block : from;
      _showRest();
      return false;
    }
  }

  void _show(List<ResponsePart> parts) {
    for (final ResponsePart part in parts) {
      switch (part) {
        case TextPart(:final String text):
          if (_parts.lastOrNull case final MarkdownPart last) {
            last.markdown += text;
          } else {
            _parts.add(MarkdownPart(text));
          }
        case A2uiPart(:final List<AgentToRendererMessage> a2ui):
          _renderer.processMessages(AgentToRendererMessagePayload(a2ui));
      }
    }
  }

  /// Shows the text from where the output stopped being read as A2UI.
  void _showRest() {
    final String rest = '$_output'
        .substring(_failedAt)
        .replaceAll(_blocks, '')
        .trim();
    if (rest.isEmpty) return;
    _rest ??= MarkdownPart('');
    _rest!.markdown = rest;
    if (!_parts.contains(_rest)) _parts.add(_rest!);
  }

  /// A2UI blocks, including one still open at the end.
  static final RegExp _blocks = RegExp('$_openTag[\\s\\S]*?($_closeTag|\$)');

  void dispose() => _renderer.dispose();
}
