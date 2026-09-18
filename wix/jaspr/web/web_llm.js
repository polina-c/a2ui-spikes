// The JavaScript half of package:genui's WebLLM support.
//
// WebLLM is an ES module that spawns its own WebGPU workers, so it is
// imported here rather than bound from Dart directly. Everything this file
// exposes is what `lib/src/inference/web_llm_interop.dart` declares.
//
// Copy this file next to your app's index.html and load it with:
//   <script type="module" src="web_llm.js"></script>

import * as webllm from 'https://esm.run/@mlc-ai/web-llm@0.2.85';

let engine = null;
let loadedModelId = null;
let loadedOptions = null;

globalThis.a2uiWebLlm = {
  /** The model IDs WebLLM has prebuilt configurations for. */
  models() {
    return webllm.prebuiltAppConfig.model_list.map((m) => m.model_id);
  },

  /**
   * The context window, in tokens, that WebLLM gives `modelId` unless it is
   * told otherwise, or null if its configuration does not say.
   *
   * Most prebuilt models are set to 4096, which a long system prompt eats a
   * good part of, so it is worth showing before offering to load one.
   */
  defaultContextWindowSize(modelId) {
    const record = webllm.prebuiltAppConfig.model_list.find(
      (m) => m.model_id === modelId,
    );
    const size = record?.overrides?.context_window_size;
    return typeof size === 'number' && size > 0 ? size : null;
  },

  /**
   * Whether this browser exposes the WebGPU API at all.
   *
   * Cheap and synchronous, so it is worth asking before offering to load a
   * model. It is necessary but not sufficient: see `hasWebGpuAdapter`.
   */
  hasWebGpu() {
    return typeof navigator !== 'undefined' && !!navigator.gpu;
  },

  /**
   * Whether WebGPU can actually give out an adapter to run on.
   *
   * A browser can expose `navigator.gpu` and still have no GPU behind it,
   * which is what a headless or software-rendered session looks like.
   */
  async hasWebGpuAdapter() {
    if (!this.hasWebGpu()) return false;
    try {
      return (await navigator.gpu.requestAdapter()) !== null;
    } catch (_) {
      return false;
    }
  },

  /**
   * Downloads and compiles a model. Resolves once it can answer.
   *
   * Reloading the same model with the same options is a no-op, so a caller
   * that is unsure whether the model is up can call this again cheaply.
   *
   * `optionsJson`, when given, is a JSON object of WebLLM `ChatOptions` —
   * the context window settings, which are fixed when the engine is built
   * rather than per request. Different options mean a different engine, so
   * they are what decides whether the loaded one can be reused.
   */
  async init(modelId, onProgress, optionsJson) {
    const options = optionsJson ?? null;
    if (engine && loadedModelId === modelId && loadedOptions === options) {
      return;
    }
    // Checked here rather than left to WebLLM: with no GPU behind
    // navigator.gpu it can sit waiting instead of failing, which on the
    // page looks like a download that never starts.
    if (!(await this.hasWebGpuAdapter())) {
      throw new Error(
        'WebGPU is not available in this browser, or there is no GPU it can '
        + 'use. The model needs it to run.',
      );
    }
    engine = await webllm.CreateMLCEngine(
      modelId,
      {
        initProgressCallback: (report) => {
          onProgress({
            progress: report.progress ?? 0,
            text: report.text ?? '',
          });
        },
      },
      options ? JSON.parse(options) : undefined,
    );
    loadedModelId = modelId;
    loadedOptions = options;
  },

  /**
   * Streams an answer, calling onDelta with each chunk of text.
   *
   * `samplingJson`, when given, is a JSON object of sampling parameters
   * WebLLM accepts on `chat.completions.create` — temperature and the
   * penalties. Left out, the temperature is low, because generated UI has
   * to be valid A2UI JSON far more often than it has to be interesting.
   */
  async stream(messagesJson, onDelta, samplingJson) {
    if (!engine) throw new Error('WebLLM: init() has not been called.');
    const sampling = samplingJson ? JSON.parse(samplingJson) : { temperature: 0.2 };
    const chunks = await engine.chat.completions.create({
      ...sampling,
      messages: JSON.parse(messagesJson),
      stream: true,
    });
    for await (const chunk of chunks) {
      const delta = chunk.choices?.[0]?.delta?.content;
      if (delta) onDelta(delta);
    }
  },

  /** Abandons the answer in flight, if there is one. */
  interrupt() {
    if (engine) engine.interruptGenerate();
  },
};
