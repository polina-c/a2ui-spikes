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

/// How the model picks its next token.
///
/// These are the sampling parameters WebLLM accepts on
/// `chat.completions.create`, and only the ones that are set are sent, so a
/// [Sampling] with one field set leaves the rest at WebLLM's defaults.
///
/// The penalties are worth setting for a chat. A small model falls into a
/// loop and answers every question with the same sentence unless new tokens
/// are rewarded: measured on SmolLM2-360M, Qwen2.5-0.5B and Llama-3.2-1B,
/// without them, asking the same question twice returned character-for-
/// character identical text.
final class Sampling {
  /// Creates a [Sampling].
  const Sampling({
    this.temperature,
    this.frequencyPenalty,
    this.presencePenalty,
    this.repetitionPenalty,
  });

  /// How much randomness to allow, from 0 up.
  ///
  /// Low for generated UI, which has to parse as A2UI JSON; higher for prose.
  final double? temperature;

  /// Penalty on a token in proportion to how often it has been used.
  final double? frequencyPenalty;

  /// Penalty on a token that has been used at all.
  final double? presencePenalty;

  /// Penalty applied to tokens already in the context.
  final double? repetitionPenalty;

  /// The parameters that are set, under the names WebLLM gives them.
  Map<String, Object?> toJson() => <String, Object?>{
    if (temperature != null) 'temperature': temperature,
    if (frequencyPenalty != null) 'frequency_penalty': frequencyPenalty,
    if (presencePenalty != null) 'presence_penalty': presencePenalty,
    if (repetitionPenalty != null) 'repetition_penalty': repetitionPenalty,
  };
}

/// How much of the conversation the model keeps in view, in tokens.
///
/// A prebuilt WebLLM model comes configured for a small window, 4096 tokens
/// on most of them, and the system prompt that teaches a catalog takes a
/// good part of it before the first question is asked. When what is
/// cached plus the next message no longer fits, WebLLM throws
/// `ContextWindowSizeExceededError`, and it throws it on a message of any
/// length: a twenty-token follow-up overflows a window the prompt has
/// already filled.
///
/// There are two ways out, and this is the choice between them. A
/// [ContextWindow.fixed] window is larger, so more of the conversation fits;
/// it is still finite, and it costs GPU memory, because the key-value cache
/// is sized from it. A [ContextWindow.sliding] window never overflows,
/// because the oldest tokens are dropped to make room, at the cost of the
/// model forgetting them, the system prompt included, unless
/// [attentionSinkTokens] is large enough to pin it.
///
/// The window is fixed when the engine is built, so changing it means
/// loading the model again.
final class ContextWindow {
  /// The window the model's own configuration asks for.
  const ContextWindow.modelDefault()
    : tokens = null,
      slides = false,
      attentionSinkTokens = 0;

  /// A window [tokens] long that holds the whole conversation until it is
  /// full, and then refuses the next message.
  const ContextWindow.fixed(this.tokens)
    : slides = false,
      attentionSinkTokens = 0;

  /// A window [tokens] long that drops the oldest tokens to make room.
  ///
  /// [attentionSinkTokens] is how many tokens at the very start are kept
  /// however far the window slides. WebLLM's own default is a handful, which
  /// is the StreamingLLM setting; a system prompt that has to survive the
  /// whole conversation needs a sink about as long as the prompt.
  const ContextWindow.sliding(this.tokens, {this.attentionSinkTokens = 4})
    : slides = true;

  /// How long the window is, or null for the model's own setting.
  final int? tokens;

  /// Whether the window slides over the conversation rather than filling up.
  final bool slides;

  /// How many tokens at the start are kept while the window slides.
  final int attentionSinkTokens;

  /// This window as WebLLM's `ChatOptions` fields, empty for the model's own
  /// setting.
  ///
  /// WebLLM takes exactly one of the two sizes as positive and wants the
  /// other set to -1, so the one that is not in use is turned off here
  /// rather than left to the model's configuration, which would otherwise
  /// leave both set and be rejected.
  Map<String, Object?> toJson() {
    final int? tokens = this.tokens;
    if (tokens == null) return const <String, Object?>{};
    return slides
        ? <String, Object?>{
            'context_window_size': -1,
            'sliding_window_size': tokens,
            'attention_sink_size': attentionSinkTokens,
          }
        : <String, Object?>{
            'context_window_size': tokens,
            'sliding_window_size': -1,
          };
  }
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
  /// The model is not loaded until [load] is called. [sampling] left out
  /// means WebLLM's defaults with a low temperature, which is the setting
  /// for generated UI; a chat that answers in prose should set it.
  ///
  /// [contextWindow] left out means the window the model is configured for,
  /// which on most prebuilt models is 4096 tokens. A chat that runs for more
  /// than a few turns wants more than that; see [ContextWindow].
  WebLlmClient({
    this.modelId = defaultModelId,
    this.sampling,
    this.contextWindow = const ContextWindow.modelDefault(),
  });

  /// A small instruction-tuned model, chosen so the first load is minutes
  /// rather than tens of minutes.
  ///
  /// Generated UI asks a lot of a model this size. [models] lists the rest;
  /// a larger one follows the A2UI schema more reliably if the download is
  /// acceptable.
  static const String defaultModelId = 'Llama-3.2-3B-Instruct-q4f32_1-MLC';

  /// The model this client runs.
  final String modelId;

  /// How the model picks its next token, or null for WebLLM's defaults.
  final Sampling? sampling;

  /// How much of the conversation the model keeps in view.
  final ContextWindow contextWindow;

  /// Whether the page has loaded the WebLLM shim at all.
  static bool get isAvailable => isWebLlmLoaded;

  /// The model IDs WebLLM can load.
  static List<String> models() =>
      webLlm.models().toDart.map((JSString id) => id.toDart).toList();

  /// The context window [modelId] runs with unless it is given another, in
  /// tokens, or null when WebLLM does not say or is not loaded.
  ///
  /// Worth showing next to a choice of [ContextWindow]: it is the size the
  /// conversation has to fit in by default, and it is usually 4096.
  static int? defaultContextWindowSize(String modelId) {
    if (!isWebLlmLoaded) return null;
    return webLlm.defaultContextWindowSize(modelId)?.toDartInt;
  }

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

    final Map<String, Object?> options = contextWindow.toJson();
    await webLlm
        .init(
          modelId,
          report.toJS,
          options.isEmpty ? null : jsonEncode(options).toJS,
        )
        .toDart;
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
        final Sampling? sampling = this.sampling;
        await webLlm
            .stream(
              jsonEncode(_toWebLlmMessages(messages)),
              deliver.toJS,
              sampling == null ? null : jsonEncode(sampling.toJson()).toJS,
            )
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
