import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../chat_session.dart';

/// The transcript and the box you type into.
class ChatView extends StatefulComponent {
  /// Creates a [ChatView].
  const ChatView({required this.session, super.key});

  /// The session to show.
  final ChatSession session;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  static const String _logId = 'ai-chat-log';

  String _draft = '';

  @override
  Component build(BuildContext context) {
    final ChatSession session = component.session;

    // A streamed answer grows the last bubble, which would otherwise scroll
    // out of sight as it is written.
    context.binding.addPostFrameCallback(_scrollToLatest);

    return Component.fragment([
      div(id: _logId, classes: 'log', attributes: const {
        'role': 'log',
        'aria-live': 'polite',
      }, [
        for (final (int index, Turn turn) in session.turns.indexed)
          // The last bubble is rebuilt on every chunk, so the key has to
          // identify a turn by its position rather than by what it says.
          div(
            key: ValueKey<int>(index),
            classes: _bubbleClasses(turn, isLast: index == session.turns.length - 1),
            [Component.text(turn.text)],
          ),
      ]),
      if (session.status == ChatStatus.ready)
        form(
          classes: 'composer',
          // A form rather than a bare row, so Enter sends the message the
          // way it does everywhere else on the web.
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
              disabled: session.isGenerating,
              attributes: const {
                'placeholder': 'Ask a question…',
                'aria-label': 'Message',
                'autocomplete': 'off',
              },
              onInput: (String value) => setState(() => _draft = value),
            ),
            if (session.isGenerating)
              button(
                classes: 'primary',
                type: ButtonType.button,
                onClick: session.stop,
                [Component.text('Stop')],
              )
            else
              button(
                classes: 'primary',
                type: ButtonType.submit,
                disabled: !session.canSend || _draft.trim().isEmpty,
                [Component.text('Send')],
              ),
          ],
        ),
    ]);
  }

  String _bubbleClasses(Turn turn, {required bool isLast}) {
    return <String>[
      'msg',
      if (turn.isUser) 'user' else 'bot',
      if (turn.tone == TurnTone.withheld) 'withheld',
      if (turn.tone == TurnTone.failed) 'err',
      // The caret is what says an empty bubble is about to fill rather than
      // broken.
      if (isLast && !turn.isUser && component.session.isGenerating) 'pending',
    ].join(' ');
  }

  void _scrollToLatest() {
    final web.Element? log = web.document.getElementById(_logId);
    if (log != null) log.scrollTop = log.scrollHeight;
  }

  void _send() {
    final String text = _draft;
    if (text.trim().isEmpty) return;
    setState(() => _draft = '');
    component.session.send(text);
  }
}
