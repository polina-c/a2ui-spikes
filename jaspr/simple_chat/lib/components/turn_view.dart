import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../chat_session.dart';

/// Renders one entry of the transcript.
class TurnView extends StatelessComponent {
  /// Creates a [TurnView].
  const TurnView({required this.turn, required this.session, super.key});

  /// The entry to render.
  final Turn turn;

  /// The session it belongs to.
  final ChatSession session;

  @override
  Component build(BuildContext context) {
    return switch (turn) {
      TextTurn(:final bool isUser, :final String text) => div(
        classes: isUser ? 'turn user' : 'turn model',
        [
          div(classes: 'bubble', [
            // The model's prose is Markdown, and it is untrusted input, so
            // it is rendered as nodes rather than injected as HTML. This is
            // the same renderer the Text component uses.
            if (isUser)
              Component.text(text)
            else
              Component.fragment(renderInlineMarkdown(text)),
          ]),
        ],
      ),
      SurfaceTurn(:final String surfaceId) => div(
        classes: 'turn model',
        [_surface(surfaceId)],
      ),
    };
  }

  Component _surface(String surfaceId) {
    final core.SurfaceModel<CatalogItem>? surface = session.surface(surfaceId);
    if (surface == null) return Component.empty();
    return div(classes: 'surface', [
      SurfaceView(
        surface: surface,
        // A surface is created empty and filled by the message after it, so
        // this is what the user sees for the moment in between.
        placeholder: div(classes: 'surface-pending', [
          Component.text('Building the UI…'),
        ]),
      ),
    ]);
  }
}
