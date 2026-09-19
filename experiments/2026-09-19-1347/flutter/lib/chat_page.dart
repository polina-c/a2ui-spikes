import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart' hide TextPart;
import 'package:genui/genui.dart' as genui;

import 'domain.dart';
import 'gemini.dart';
import 'models.dart';

const String defaultPrompt =
    'Hi, I am looking for a dishwasher. I am overwhelmed with choices and '
    "don't know where to start.";

/// One thing in the transcript: something said, or a surface the model drew.
sealed class Entry {
  const Entry();
}

class SaidEntry extends Entry {
  const SaidEntry(this.text, {required this.fromUser, this.failed = false});
  final String text;
  final bool fromUser;
  final bool failed;
}

class SurfaceEntry extends Entry {
  const SurfaceEntry(this.surfaceId);
  final String surfaceId;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.choice, required this.onRestart});

  final ModelChoice choice;
  final VoidCallback onRestart;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final Catalog _catalog = BasicCatalogItems.asCatalog();
  late final SurfaceController _controller = SurfaceController(
    catalogs: [_catalog],
  );
  late final A2uiTransportAdapter _transport = A2uiTransportAdapter(
    onSend: _sendAndReceive,
  );
  late final Conversation _conversation = Conversation(
    controller: _controller,
    transport: _transport,
  );
  late final GeminiClient _gemini = GeminiClient(
    modelId: widget.choice.modelId,
    apiKey: widget.choice.apiKey ?? '',
    temperature: widget.choice.temperature,
    maxOutputTokens: widget.choice.maxOutputTokens,
  );

  final List<Entry> _entries = [];
  final TextEditingController _draft = TextEditingController(
    text: defaultPrompt,
  );
  final ScrollController _scroll = ScrollController();

  StreamSubscription<ConversationEvent>? _events;
  bool _busy = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _events = _conversation.events.listen(_onEvent);
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    final corpus = await loadDomainCorpus();
    // genui builds the protocol half of the prompt from the catalog itself,
    // so only the selling instructions and the knowledge base are ours.
    final builder = PromptBuilder.chat(
      catalog: _catalog,
      systemPromptFragments: [_instructions, corpus],
    );
    _gemini.setSystemPrompt(builder.systemPromptJoined());
    if (mounted) setState(() => _ready = true);
  }

  void _onEvent(ConversationEvent event) {
    switch (event) {
      case ConversationSurfaceAdded(:final surfaceId):
        setState(() => _entries.add(SurfaceEntry(surfaceId)));
        _scrollToEnd();
      case ConversationContentReceived(:final text):
        final trimmed = text.trim();
        if (trimmed.isEmpty) return;
        setState(() => _entries.add(SaidEntry(trimmed, fromUser: false)));
        _scrollToEnd();
      case ConversationError(:final error):
        setState(() {
          _busy = false;
          _entries.add(
            SaidEntry('That did not work: $error', fromUser: false, failed: true),
          );
        });
      default:
    }
  }

  /// Takes a turn from genui, asks Gemini, and feeds the reply back in.
  Future<void> _sendAndReceive(ChatMessage message) async {
    final buffer = StringBuffer();
    for (final part in message.parts) {
      if (part.isUiInteractionPart) {
        buffer.write(part.asUiInteractionPart!.interaction);
      } else if (part is genui.TextPart) {
        buffer.write(part.text);
      }
    }
    if (buffer.isEmpty) return;

    if (mounted) setState(() => _busy = true);
    try {
      final reply = await _gemini.send(buffer.toString());
      _transport.addChunk(reply);
    } catch (e) {
      if (mounted) {
        setState(
          () => _entries.add(
            SaidEntry('That did not work: $e', fromUser: false, failed: true),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _send() {
    final text = _draft.text.trim();
    if (text.isEmpty || _busy || !_ready) return;
    setState(() {
      _entries.add(SaidEntry(text, fromUser: true));
      _draft.clear();
    });
    _scrollToEnd();
    unawaited(_conversation.sendRequest(ChatMessage.user(text)));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _conversation.dispose();
    _transport.dispose();
    _controller.dispose();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Just Shining'),
            Text(
              '${widget.choice.modelId} - temperature '
              '${widget.choice.temperature.toStringAsFixed(1)}, max '
              '${widget.choice.maxOutputTokens} tokens',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton(
              onPressed: widget.onRestart,
              child: const Text('Change model'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(20),
                  itemCount: _entries.length + (_busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _entries.length) return const _Pending();
                    final entry = _entries[i];
                    return switch (entry) {
                      SaidEntry e => _Bubble(
                        text: e.text,
                        fromUser: e.fromUser,
                        failed: e.failed,
                      ),
                      SurfaceEntry e => Container(
                        key: const ValueKey('a2ui-surface'),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Surface(
                          surfaceContext: _controller.contextFor(e.surfaceId),
                        ),
                      ),
                    };
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _draft,
                        enabled: _ready && !_busy,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Type a message',
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _ready && !_busy ? _send : null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Send'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text('Thinking...', style: TextStyle(color: Colors.black54)),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.fromUser,
    required this.failed,
  });

  final String text;
  final bool fromUser;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: failed
              ? const Color(0xFFFDECEC)
              : fromUser
              ? accent
              : const Color(0xFFEEF1F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: failed
                ? const Color(0xFF8C1D1D)
                : fromUser
                ? Colors.white
                : Colors.black87,
          ),
        ),
      ),
    );
  }
}

const String _instructions = '''
You are the sales assistant for Just Shining, a shop that sells six dishwashers.
You answer in generated UI, not only in words.

Follow the guidance in the knowledge base below: ask before recommending, work
through the questions in the order given, recommend one model, and give the link
to its landing page. Ask one question per turn, and offer the answers as buttons
so the user picks instead of typing. Do not list all six machines. Do not invent
specifications, prices, delivery dates or URLs.

When you recommend a machine, end the turn with a button that opens its landing
page, using the openUrl function with the exact URL from the knowledge base.
''';
