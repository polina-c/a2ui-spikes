import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'gemini.dart';
import 'knowledge.dart';
import 'landing.dart';
import 'models.dart';
import 'prompt.dart';

/// Step 4 of the CUJ: the first message is already written.
const _opening =
    'Hi, I am looking for a dishwasher. I am overwhelmed with choices and '
    "don't know where to start.";

/// One thing in the transcript: words from either side, or a generated surface.
sealed class _Item {
  const _Item();
}

class _Said extends _Item {
  const _Said(this.text, {required this.fromUser, this.failed = false});
  final String text;
  final bool fromUser;
  final bool failed;
}

class _Drawn extends _Item {
  const _Drawn(this.surfaceId);
  final String surfaceId;
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.choice,
    required this.knowledge,
    required this.onBack,
  });

  final ModelChoice choice;
  final Knowledge knowledge;
  final VoidCallback onBack;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final SurfaceController _controller;
  late final A2uiTransportAdapter _transport;
  late final Conversation _conversation;
  late final GeminiClient _client;
  late final String _systemPrompt;

  final _items = <_Item>[];
  final _history = <ChatMessage>[];
  final _draft = TextEditingController(text: _opening);
  final _scroll = ScrollController();
  StreamSubscription<ConversationEvent>? _events;
  bool _busy = false;

  @override
  void initState() {
    super.initState();

    // The catalog without the asset components, since this app shows no
    // images or video, plus the one function that opens a landing page.
    final catalog = BasicCatalogItems.asNoAssetCatalog().copyWith(
      newFunctions: [OpenLandingPage(widget.knowledge.landingUrls)],
    );

    _controller = SurfaceController(catalogs: [catalog]);
    _client = GeminiClient(choice: widget.choice);
    _transport = A2uiTransportAdapter(onSend: _send);
    _conversation = Conversation(controller: _controller, transport: _transport);

    // genui writes the protocol half of the prompt from the catalog itself.
    _systemPrompt = PromptBuilder.chat(
      catalog: catalog,
      systemPromptFragments: [
        sellingInstructions(widget.knowledge.corpus),
        PromptFragments.uiGenerationRestriction(),
      ],
    ).systemPromptJoined();

    _events = _conversation.events.listen(_onEvent);
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

  void _onEvent(ConversationEvent event) {
    setState(() {
      switch (event) {
        case ConversationSurfaceAdded(:final surfaceId):
          _items.add(_Drawn(surfaceId));
        case ConversationContentReceived(:final text):
          if (text.trim().isNotEmpty) {
            _items.add(_Said(text.trim(), fromUser: false));
          }
        case ConversationWaiting():
          _busy = true;
        case ConversationError(:final error):
          _items.add(_Said('That did not work: $error', fromUser: false, failed: true));
          _busy = false;
        case ConversationSurfaceRemoved(:final surfaceId):
          _items.removeWhere((i) => i is _Drawn && i.surfaceId == surfaceId);
        case ConversationComponentsUpdated():
          break;
      }
    });
    _scrollToEnd();
  }

  /// Called by genui when it has a turn to send: both a typed message and a
  /// press on a generated button arrive here.
  Future<void> _send(ChatMessage message) async {
    _history.add(message);
    setState(() => _busy = true);
    try {
      final reply = await _client.send(_systemPrompt, _history);
      _history.add(ChatMessage.model(reply));
      _transport.addChunk(reply);
    } catch (error) {
      setState(() {
        _items.add(_Said('That did not work: $error', fromUser: false, failed: true));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  void _sendTyped() {
    final text = _draft.text.trim();
    if (text.isEmpty || _busy) return;
    _draft.clear();
    setState(() => _items.add(_Said(text, fromUser: true)));
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Just Shining'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(18),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${widget.choice.modelId} - temperature '
              '${widget.choice.temperature}, max '
              '${widget.choice.maxOutputTokens} tokens',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: widget.onBack, child: const Text('Change model')),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length + (_busy ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Thinking...'),
                      );
                    }
                    return switch (_items[index]) {
                      _Said(:final text, :final fromUser, :final failed) =>
                        ChatMessageView(
                          text: text,
                          icon: fromUser
                              ? Icons.person
                              : failed
                              ? Icons.error_outline
                              : Icons.storefront,
                          alignment: fromUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                        ),
                      _Drawn(:final surfaceId) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Surface(
                            surfaceContext: _controller.contextFor(surfaceId),
                          ),
                        ),
                      ),
                    };
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _draft,
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendTyped(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _busy ? null : _sendTyped,
                      child: const Text('Send'),
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
