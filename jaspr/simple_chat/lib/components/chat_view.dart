import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../chat_session.dart';
import 'turn_view.dart';

/// The chat itself: the transcript and the composer under it.
class ChatView extends StatefulComponent {
  /// Creates a [ChatView].
  const ChatView({required this.session, super.key});

  /// The session to show.
  final ChatSession session;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  String _draft = 'Help me plan a weekend in Lisbon.';

  @override
  Component build(BuildContext context) {
    final ChatSession session = component.session;

    return div(classes: 'chat', [
      div(classes: 'transcript', [
        if (session.turns.isEmpty)
          div(classes: 'empty', [
            Component.text(
              'Ask for something that needs a form, a list or a choice. '
              'The model answers with a working UI, not a picture of one.',
            ),
          ]),
        for (final (int index, Turn turn) in session.turns.indexed)
          // A streaming bubble is rebuilt on every chunk, so the key has to
          // identify the turn by position rather than by content.
          TurnView(
            key: ValueKey<int>(index),
            turn: turn,
            session: session,
          ),
        if (session.isGenerating)
          div(classes: 'turn model', [
            div(classes: 'bubble thinking', [Component.text('…')]),
          ]),
      ]),
      if (session.error != null)
        div(classes: 'error', [
          span([Component.text(session.error!)]),
          button(
            classes: 'dismiss',
            type: ButtonType.button,
            onClick: session.dismissError,
            [Component.text('Dismiss')],
          ),
        ]),
      form(
        classes: 'composer',
        // A form rather than a bare row, so that Enter in the field sends
        // the message the way it does everywhere else on the web.
        events: {
          'submit': (web.Event event) {
            event.preventDefault();
            _send();
          },
        },
        [
          input<String>(
            type: InputType.text,
            value: _draft,
            disabled: !session.canSend,
            attributes: const {
              'placeholder': 'Ask for something…',
              'autocomplete': 'off',
            },
            onInput: (String value) => setState(() => _draft = value),
          ),
          button(
            classes: 'primary',
            type: ButtonType.submit,
            disabled: !session.canSend || _draft.trim().isEmpty,
            [Component.text(session.isGenerating ? 'Thinking…' : 'Send')],
          ),
        ],
      ),
    ]);
  }

  void _send() {
    final String text = _draft;
    if (text.trim().isEmpty) return;
    setState(() => _draft = '');
    component.session.send(text);
  }
}
