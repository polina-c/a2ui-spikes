import 'dart:js_interop';

import 'package:genui/genui.dart';

import 'model_client.dart';
import 'models.dart';

// The two calls `web/webllm_bridge.js` puts on `window`. Everything crosses as
// a string, so there is no object graph to convert.
@JS('a2uiWebllm.create')
external JSPromise<JSAny?> _create(String modelId, JSFunction onProgress);

@JS('a2uiWebllm.chat')
external JSPromise<JSString> _chat(
  String messagesJson,
  double temperature,
  int maxTokens,
);

/// Runs the model inside this browser tab through WebLLM.
///
/// Nothing leaves the machine and no API key is needed, which is what Jane
/// wants when her key is not to hand. The costs are a download of a gigabyte or
/// more on the first run, and a browser with WebGPU.
class WebllmClient implements ModelClient {
  WebllmClient({required this.choice, required this.onStatus});

  final ModelChoice choice;
  final StatusCallback onStatus;

  bool _loaded = false;

  @override
  String get label => '${choice.modelId} (in this browser)';

  @override
  Future<String> send(String system, List<ChatMessage> history) async {
    if (!_loaded) {
      onStatus('Loading the model into this browser. The first run downloads '
          'it, which takes a while.');
      await _create(
        choice.modelId,
        ((JSString text) => onStatus(text.toDart)).toJS,
      ).toDart;
      _loaded = true;
    }

    onStatus('Thinking...');
    final reply = await _chat(
      webllmMessagesJson(system, history),
      choice.temperature,
      choice.maxOutputTokens,
    ).toDart;

    final text = reply.toDart;
    if (text.isEmpty) {
      throw StateError('The in-browser model returned nothing.');
    }
    return text;
  }
}
