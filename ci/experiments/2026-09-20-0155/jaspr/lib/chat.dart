import 'package:a2ui_core/a2ui_core.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'a2ui/catalog.dart';
import 'a2ui/renderer.dart';
import 'gemini.dart';
import 'knowledge.dart';
import 'local.dart';
import 'model_client.dart';
import 'models.dart';
import 'prompt.dart';

/// Step 4 of the CUJ: the first message is already written.
const _opening =
    'Hi, I am looking for a dishwasher. I am overwhelmed with choices and '
    "don't know where to start.";

/// One thing in the transcript.
class _Entry {
  _Entry({
    required this.text,
    required this.fromUser,
    this.surfaceId,
    this.failed = false,
  });

  final String text;
  final bool fromUser;
  final String? surfaceId;
  final bool failed;
}

class Chat extends StatefulComponent {
  const Chat({
    required this.choice,
    required this.knowledge,
    required this.onBack,
    super.key,
  });

  final ModelChoice choice;
  final Knowledge knowledge;
  final void Function() onBack;

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  late final MessageProcessor<ComponentApi> _processor;
  late final ModelClient _client;
  late final String _system;

  final _entries = <_Entry>[];
  final _turns = <Turn>[];
  String _draft = _opening;
  bool _busy = false;
  int _surfaceCount = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();

    final catalog = appCatalog();
    _processor = MessageProcessor<ComponentApi>(
      catalogs: [catalog],
      onAction: _onAction,
    );
    // The cloud model and the in-browser one are the same thing to the chat.
    _client = component.choice.familyId == 'gemini'
        ? GeminiClient(component.choice)
        : WebllmClient(component.choice, onStatus: _setStatus);

    final capabilities = _processor.getClientCapabilities(
      includeInlineCatalogs: true,
    );
    final inline =
        ((capabilities['v0.9'] as Map<String, dynamic>?)?['inlineCatalogs']
            as List?)
            ?.first;

    _system = systemPrompt(
      inlineCatalog: inline,
      catalogId: catalog.id,
      corpus: component.knowledge.corpus,
      modelIds: Knowledge.models,
    );
  }

  /// Progress from a model that is loading itself into this browser.
  void _setStatus(String message) {
    if (mounted) setState(() => _status = message);
  }

  /// A press on a generated button. Either it opens a landing page, or it
  /// becomes the next turn of the conversation.
  void _onAction(A2uiClientAction action) {
    if (action.name == 'openLandingPage') {
      final url =
          component.knowledge.landingUrls[(action.context['model'] ?? '')
              .toString()
              .toLowerCase()];
      if (url != null) {
        web.window.open(url, '_blank');
        return;
      }
    }
    _send(
      'The user pressed "${action.sourceComponentId}" in the UI you drew. The '
      'action was "${action.name}" with context ${action.context}. Answer as '
      'if they had told you that.',
      silent: true,
    );
  }

  /// Applies the messages of one reply, one at a time.
  ///
  /// a2ui_core parses into typed messages and throws on a shape it does not
  /// recognise. Handing it the whole list at once means one malformed message
  /// loses the entire turn, and the model does produce one occasionally, so
  /// each is applied on its own and a bad one is reported and stepped over.
  void _apply(List<Object?> messages) {
    for (final message in messages) {
      try {
        _processor.processMessages([
          A2uiMessage.fromJson(message as Map<String, dynamic>),
        ]);
      } catch (error) {
        web.console.warn('A2UI message skipped: $error'.toJS);
      }
    }
  }

  Future<void> _send(String text, {bool silent = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      if (!silent) _entries.add(_Entry(text: text, fromUser: true));
    });

    final surfaceId = 'turn-${_surfaceCount++}';
    _turns.add(
      Turn('user', '$text\n\n(Draw this answer on surfaceId "$surfaceId".)'),
    );

    try {
      final raw = await _client.send(_system, _turns);
      _turns.add(Turn('model', raw));
      final reply = parseReply(raw);

      var drew = false;
      if (reply.a2ui.isNotEmpty) {
        _apply(reply.a2ui);
        drew = _processor.groupModel.getSurface(surfaceId) != null;
      }

      setState(() {
        _entries.add(
          _Entry(
            text: reply.say.isEmpty ? '(no words with this one)' : reply.say,
            fromUser: false,
            surfaceId: drew ? surfaceId : null,
          ),
        );
      });
    } catch (error) {
      setState(() {
        _entries.add(
          _Entry(
            text: 'That did not work: $error',
            fromUser: false,
            failed: true,
          ),
        );
      });
    } finally {
      setState(() {
        _busy = false;
        _status = '';
      });
    }
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'chat', [
      header(classes: 'chat-head', [
        div([
          strong([Component.text('Just Shining')]),
          span(classes: 'sub', [
            Component.text(
              '${_client.label} - temperature '
              '${component.choice.temperature}, max '
              '${component.choice.maxOutputTokens} tokens',
            ),
          ]),
        ]),
        button(
          classes: 'restart',
          events: {'click': (_) => component.onBack()},
          [Component.text('Change model')],
        ),
      ]),
      div(classes: 'log', [
        if (_entries.isEmpty)
          p(classes: 'lead', [
            Component.text(
              'The first message is written for you. Press send when ready.',
            ),
          ]),
        for (final entry in _entries)
          div(classes: 'entry ${entry.fromUser ? 'user' : 'assistant'}', [
            div(classes: entry.failed ? 'bubble failed' : 'bubble', [
              Component.text(entry.text),
            ]),
            if (entry.surfaceId != null &&
                _processor.groupModel.getSurface(entry.surfaceId!) != null)
              div(classes: 'surface', [
                A2uiSurface(
                  surface: _processor.groupModel.getSurface(entry.surfaceId!)!,
                ),
              ]),
          ]),
        if (_busy)
          div(classes: 'entry assistant', [
            div(classes: 'bubble pending', [
              Component.text(_status.isEmpty ? 'Thinking...' : _status),
            ]),
          ]),
      ]),
      div(classes: 'composer', [
        input(
          type: InputType.text,
          value: _draft,
          attributes: {
            'placeholder': 'Type a message',
            if (_busy) 'disabled': '',
          },
          events: {
            'input': (event) =>
                _draft = (event.target as web.HTMLInputElement).value,
          },
        ),
        button(
          attributes: _busy ? const {'disabled': ''} : const {},
          events: {
            'click': (_) {
              final text = _draft.trim();
              if (text.isEmpty) return;
              setState(() => _draft = '');
              _send(text);
            },
          },
          [Component.text('Send')],
        ),
      ]),
    ]);
  }
}
