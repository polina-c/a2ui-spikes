import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';


import '../facade/conversation.dart';
import '../primitives/logging.dart';
import 'web_llm_interop.dart';

/// How far along loading a model is.
final class LoadProgress {
  /// Creates a [LoadProgress].
  const LoadProgress({required this.fraction, required this.message});

  /// A fraction between 0 and 1, or 0 for a step with no measurable size.
  final double fraction;

  /// What is happening, in words.
  final String message;

  /// Whether the model is ready to answer.
  bool get isDone => fraction >= 1;
}

/// A [TextGenerator] backed by a model running in this browser tab.
///
/// [WebLLM](https://github.com/mlc-ai/web-llm) compiles the model to WebGPU
/// and runs it on the page, so the conversation and everything the user
/// types into a generated form stay on the machine: there is no API key and
/// no server. The cost is the first load, which downloads a few gigabytes of
/// weights, and the requirement that the browser support WebGPU.
class WebLlmClient implements TextGenerator {
  /// Creates a [WebLlmClient] for [modelId].
  ///
  /// The model is not loaded until [load] is called.
  WebLlmClient({this.modelId = defaultModelId});

  /// A small instruction-tuned model, chosen so the first load is minutes
  /// rather than tens of minutes.
  ///
  /// Generated UI asks a lot of a model this size. [models] lists the rest;
  /// a larger one follows the A2UI schema more reliably if the download is
  /// acceptable.
  static const String defaultModelId = 'Llama-3.2-3B-Instruct-q4f32_1-MLC';

  /// The model this client runs.
  final String modelId;

  /// Whether the page has loaded the WebLLM shim at all.
  static bool get isAvailable => isWebLlmLoaded;

  /// The model IDs WebLLM can load.
  static List<String> models() =>
      webLlm.models().toDart.map((JSString id) => id.toDart).toList();

  /// Whether this browser exposes the WebGPU API at all.
  ///
  /// Necessary but not sufficient; see [hasWebGpuAdapter].
  static bool get hasWebGpu => isWebLlmLoaded && webLlm.hasWebGpu();

  /// Whether WebGPU can actually give out a GPU to run on.
  ///
  /// Worth awaiting before [load]. A browser can expose the API and still
  /// have nothing behind it, and saying so beats starting a download that
  /// cannot finish.
  static Future<bool> hasWebGpuAdapter() async {
    if (!isWebLlmLoaded) return false;
    return (await webLlm.hasWebGpuAdapter().toDart).toDart;
  }

  bool _isLoaded = false;

  /// Whether the model is loaded and ready to answer.
  bool get isLoaded => _isLoaded;

  /// Downloads and compiles the model, reporting progress as it goes.
  ///
  /// The first call for a given model fetches its weights; later calls are
  /// served from the browser's cache and are much faster.
  Future<void> load({void Function(LoadProgress progress)? onProgress}) async {
    if (_isLoaded) return;
    genUiLogger.info('Loading WebLLM model $modelId');

    void report(JSObject raw) {
      final progress = raw as JSProgress;
      onProgress?.call(
        LoadProgress(fraction: progress.progress, message: progress.text),
      );
    }

    await webLlm.init(modelId, report.toJS).toDart;
    _isLoaded = true;
    genUiLogger.info('WebLLM model $modelId ready');
  }

  @override
  Stream<String> generate(List<ChatMessage> messages) {
    final controller = StreamController<String>();

    void deliver(JSString chunk) {
      if (!controller.isClosed) controller.add(chunk.toDart);
    }

    controller.onListen = () async {
      try {
        if (!_isLoaded) await load();
        await webLlm
            .stream(jsonEncode(_toWebLlmMessages(messages)), deliver.toJS)
            .toDart;
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      } finally {
        await controller.close();
      }
    };
    // Navigating away mid-answer should stop the model, not leave it
    // generating into a stream nobody reads.
    controller.onCancel = () {
      if (_isLoaded) webLlm.interrupt();
    };

    return controller.stream;
  }

  /// Stops the answer in flight, if there is one.
  void interrupt() {
    if (_isLoaded) webLlm.interrupt();
  }
}

/// Converts the conversation to the `{role, content}` shape WebLLM takes.
///
/// WebLLM follows the OpenAI chat format, whose roles are `system`, `user`
/// and `assistant`, so the `model` role is renamed on the way out.
List<Map<String, String>> _toWebLlmMessages(List<ChatMessage> messages) {
  return [
    for (final ChatMessage message in messages)
      if (message.text.isNotEmpty)
        {
          'role': switch (message.role) {
            ChatMessageRole.system => 'system',
            ChatMessageRole.model => 'assistant',
            _ => 'user',
          },
          'content': message.text,
        },
  ];
}
