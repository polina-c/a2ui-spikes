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
/// The agent SDK cannot read Express while it streams, so the text shows as
/// it arrives, and each block shows once it is complete.
///
/// Each answer renders its own surfaces, so answers never clash over a
/// surface id.
class AnswerContent {
  AnswerContent({
    required this._agent,
    required CatalogImplementation catalog,
    required void Function(A2uiRendererAction action) onAction,
  }) : _state = _agent.createState(),
       _renderer = MessageProcessor<ComponentImplementation>(
         catalogs: [catalog],
         defaultVersion: catalog.protocolVersion,
       ) {
    _renderer.model.onAction.subscribe(onAction);
    _renderer.model.onSurfaceCreated.subscribe(
      (surface) => _created.add(SurfacePart(surface)),
    );
    _renderer.model.onSurfaceDeleted.subscribe((id) {
      for (final List<SurfacePart> surfaces in _blocks) {
        surfaces.removeWhere((part) => part.surface.id == id);
      }
    });
  }

  static const String _openTag = '<a2ui>';

  /// Splits the model's output into text and blocks, and checks each block.
  final A2uiRequestProcessor _agent;

  /// The surfaces of the answer as the agent SDK checks them, so a block is
  /// checked against the blocks before it.
  final RendererState _state;

  /// Turns the A2UI messages into surfaces.
  final MessageProcessor<ComponentImplementation> _renderer;

  List<AnswerPart> _parts = [];
  List<AnswerPart> get parts => List.unmodifiable(_parts);

  /// The model's output so far, as it wrote it.
  final StringBuffer _output = StringBuffer();

  /// The surfaces each block that rendered created, in the order of the
  /// blocks.
  final List<List<SurfacePart>> _blocks = [];

  /// The surfaces created by the block being rendered.
  List<SurfacePart> _created = [];

  /// Why the UI stopped rendering, if the model wrote A2UI that does not
  /// read or that the renderer rejects.
  ///
  /// From the block that failed on, the answer shows its text, with the A2UI
  /// left out.
  A2uiError? _error;
  A2uiError? get error => _error;

  bool _isClosed = false;

  /// Whether the output so far ends inside an A2UI block.
  bool get isInBlock => _isInBlock;
  bool _isInBlock = false;

  /// Reads the next [chunk] of the model's output.
  void add(String chunk) {
    _output.write(chunk);
    _update();
  }

  /// Ends the answer, showing the text held back in case it started a tag,
  /// and reading a block that the answer left open.
  void close() {
    _isClosed = true;
    _update();
  }

  /// Shows the output so far, rendering each block that is complete the
  /// first time it is.
  void _update() {
    final List<RawResponsePart> raw = _agent.parser.unwrap(_withoutTagStart());
    final parts = <AnswerPart>[];
    var block = 0;
    _isInBlock = false;
    for (final RawResponsePart part in raw) {
      switch (part) {
        case TextPart(:final String text):
          if (parts.lastOrNull case final MarkdownPart last) {
            last.markdown += '\n\n$text';
          } else {
            parts.add(MarkdownPart(text));
          }
        case RawA2uiPart(:final String a2uiRaw, :final bool isFinal):
          if (!isFinal && !_isClosed) {
            _isInBlock = true;
            continue;
          }
          if (block == _blocks.length && _error == null) _render(a2uiRaw);
          if (block < _blocks.length) parts.addAll(_blocks[block]);
          block++;
      }
    }
    _parts = parts;
  }

  /// Checks one complete block, and renders the surfaces it builds.
  void _render(String block) {
    _created = [];
    try {
      for (final ResponsePart part in _agent.parseResponse(
        block,
        wrapped: false,
        state: _state,
      )) {
        if (part is A2uiPart) {
          _renderer.processMessages(AgentToRendererMessagePayload(part.a2ui));
        }
      }
      _blocks.add(_created);
    } on A2uiError catch (error) {
      _error = error;
    }
  }

  /// The output, without the start of an open tag at its end, which shows
  /// as text only once the answer ends without finishing it.
  String _withoutTagStart() {
    final output = '$_output';
    if (_isClosed) return output;
    for (var length = _openTag.length - 1; length > 0; length--) {
      if (output.endsWith(_openTag.substring(0, length))) {
        return output.substring(0, output.length - length);
      }
    }
    return output;
  }

  void dispose() => _renderer.dispose();
}
