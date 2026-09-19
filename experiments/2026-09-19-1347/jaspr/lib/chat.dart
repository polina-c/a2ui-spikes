import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import 'a2ui/renderer.dart';
import 'domain.dart';
import 'gemini.dart';
import 'models.dart';
import 'prompt.dart';

const String defaultPrompt =
    'Hi, I am looking for a dishwasher. I am overwhelmed with choices and '
    "don't know where to start.";

/// One thing in the transcript: something said, or a surface the model drew.
class Entry {
  const Entry.said(this.text, {required this.fromUser, this.failed = false})
    : surface = null;
  const Entry.surface(this.surface)
    : text = '',
      fromUser = false,
      failed = false;

  final String text;
  final bool fromUser;
  final bool failed;
  final SurfaceModel<ComponentApi>? surface;
}

class Chat extends StatefulComponent {
  const Chat({required this.choice, required this.onRestart, super.key});

  final ModelChoice choice;
  final void Function() onRestart;

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  late final Catalog<ComponentApi> _catalog = MinimalCatalog();
  late final MessageProcessor<ComponentApi> _processor = MessageProcessor(
    catalogs: [_catalog],
    onAction: _onAction,
  );
  late final GeminiClient _gemini = GeminiClient(
    modelId: component.choice.modelId,
    apiKey: component.choice.apiKey ?? '',
    temperature: component.choice.temperature,
    maxOutputTokens: component.choice.maxOutputTokens,
  );

  final List<Entry> _entries = [];
  String _draft = defaultPrompt;
  bool _busy = false;
  bool _ready = false;
  int _nextSurface = 0;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final corpus = await loadDomainCorpus();
      _gemini.setSystemPrompt(buildSystemPrompt(_catalog, corpus));
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _entries.add(
            Entry.said('Could not load the knowledge base: $e',
                fromUser: false, failed: true),
          );
        });
      }
    }
  }

  /// A press on a generated button. The catalog cannot express a hyperlink, so
  /// opening one is the app's job; everything else goes back to the model.
  void _onAction(A2uiClientAction action) {
    final url = action.context['url'];
    if (action.name == 'openLandingPage' && url is String) {
      web.window.open(url, '_blank');
      return;
    }
    _send(
      'The user pressed "${action.sourceComponentId}" in the UI you drew. '
      'The action was "${action.name}" with context '
      '${jsonEncode(action.context)}. Answer as if they had told you this.',
      hidden: true,
    );
  }

  Future<void> _send(String text, {bool hidden = false}) async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      if (!hidden) _entries.add(Entry.said(text, fromUser: true));
    });

    final surfaceId = 'turn-${_nextSurface++}';
    try {
      final raw = await _gemini.send(
        '$text\n\n(Draw your answer on surfaceId "$surfaceId".)',
      );
      final parsed = _parseReply(raw);

      final messages = parsed.a2ui;
      if (messages.isNotEmpty) {
        _processor.processMessages(
          messages.map(A2uiMessage.fromJson).toList(),
        );
      }
      final surface = _processor.groupModel.getSurface(surfaceId);

      setState(() {
        _entries.add(
          Entry.said(
            parsed.say.isEmpty ? '(no words with this one)' : parsed.say,
            fromUser: false,
          ),
        );
        if (surface != null) _entries.add(Entry.surface(surface));
      });
    } catch (e) {
      setState(
        () => _entries.add(
          Entry.said('That did not work: $e', fromUser: false, failed: true),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
              '${component.choice.modelId} - temperature '
              '${component.choice.temperature.toStringAsFixed(1)}, max '
              '${component.choice.maxOutputTokens} tokens',
            ),
          ]),
        ]),
        button(
          classes: 'restart',
          events: {'click': (_) => component.onRestart()},
          [Component.text('Change model')],
        ),
      ]),

      div(classes: 'log', [
        if (_entries.isEmpty)
          p(classes: 'lead', [
            Component.text(
              'The first message is already written for you. Press send when '
              'you are ready.',
            ),
          ]),
        for (final entry in _entries)
          if (entry.surface != null)
            div(classes: 'surface', [A2uiSurface(surface: entry.surface!)])
          else
            div(classes: 'entry ${entry.fromUser ? 'user' : 'assistant'}', [
              div(
                classes: entry.failed ? 'bubble failed' : 'bubble',
                [Component.text(entry.text)],
              ),
            ]),
        if (_busy)
          div(classes: 'entry assistant', [
            div(classes: 'bubble pending', [Component.text('Thinking...')]),
          ]),
      ]),

      form(
        classes: 'composer',
        events: {
          'submit': (event) {
            event.preventDefault();
            final text = _draft.trim();
            if (text.isEmpty) return;
            setState(() => _draft = '');
            _send(text);
          },
        },
        [
          input(
            type: InputType.text,
            value: _draft,
            attributes: {
              'placeholder': 'Type a message',
              if (_busy || !_ready) 'disabled': '',
            },
            events: {
              'input': (event) =>
                  _draft = (event.target as web.HTMLInputElement).value,
            },
          ),
          button(
            attributes: {
              'type': 'submit',
              if (_busy || !_ready) 'disabled': '',
            },
            [Component.text('Send')],
          ),
        ],
      ),
    ]);
  }
}

/// Pulls the JSON object out of a reply, tolerating a stray markdown fence.
({String say, List<Map<String, dynamic>> a2ui}) _parseReply(String raw) {
  var text = raw.trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    text = text.replaceFirst(RegExp(r'```\s*$'), '');
  }
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start == -1 || end == -1) {
    throw Exception('the reply had no JSON object in it');
  }

  final parsed =
      jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
  final messages = parsed['a2ui'];
  return (
    say: parsed['say'] is String ? parsed['say'] as String : '',
    a2ui: messages is List
        ? messages.cast<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[],
  );
}
