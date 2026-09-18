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

globalThis.a2uiWebLlm = {
  /** The model IDs WebLLM has prebuilt configurations for. */
  models() {
    return webllm.prebuiltAppConfig.model_list.map((m) => m.model_id);
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
   * Reloading the same model is a no-op, so a caller that is unsure whether
   * the model is up can call this again cheaply.
   */
  async init(modelId, onProgress) {
    if (engine && loadedModelId === modelId) return;
    // Checked here rather than left to WebLLM: with no GPU behind
    // navigator.gpu it can sit waiting instead of failing, which on the
    // page looks like a download that never starts.
    if (!(await this.hasWebGpuAdapter())) {
      throw new Error(
        'WebGPU is not available in this browser, or there is no GPU it can '
        + 'use. The model needs it to run.',
      );
    }
    engine = await webllm.CreateMLCEngine(modelId, {
      initProgressCallback: (report) => {
        onProgress({ progress: report.progress ?? 0, text: report.text ?? '' });
      },
    });
    loadedModelId = modelId;
  },

  /**
   * Streams an answer, calling onDelta with each chunk of text.
   *
   * Temperature is low because the output has to be valid A2UI JSON far
   * more often than it has to be interesting.
   */
  async stream(messagesJson, onDelta) {
    if (!engine) throw new Error('WebLLM: init() has not been called.');
    const chunks = await engine.chat.completions.create({
      messages: JSON.parse(messagesJson),
      stream: true,
      temperature: 0.2,
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
