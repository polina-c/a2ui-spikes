// The bridge between the Dart app and WebLLM, which runs the model inside this
// browser tab.
//
// The React arm imports @mlc-ai/web-llm through its bundler. A Flutter web app
// has no JavaScript bundler, so the library is loaded from a CDN as an ES
// module and its two useful calls are put on `window` for Dart to reach with
// dart:js_interop. The interop surface is deliberately two functions that take
// and return strings: the conversation crosses as JSON, so nothing has to be
// converted between Dart and JavaScript object graphs.
//
// This is a classic script, not a module, so `window.a2uiWebllm` exists before
// Flutter starts; the dynamic import happens inside the first call.
(() => {
  'use strict';

  // Pinned, so an upgrade upstream cannot change what this app runs.
  const MODULE = 'https://esm.run/@mlc-ai/web-llm@0.2.79';

  let enginePromise = null;

  /** Loads the model into this tab. Safe to call more than once. */
  async function create(modelId, onProgress) {
    // Say plainly when WebGPU is missing. Without this the failure arrives
    // from inside WebLLM, much later and much less clearly.
    //
    // Both halves matter, and they fail differently: navigator.gpu is absent
    // in an older browser and on a page that is not a secure context, while a
    // machine with no usable GPU has navigator.gpu and hands back a null
    // adapter. A headless container is the second kind.
    if (!navigator.gpu) {
      throw new Error(
        'This browser has no WebGPU (navigator.gpu is undefined), which the ' +
          'in-browser model needs. Chrome or Edge 113+ over https or ' +
          'localhost can run it; otherwise pick a Gemini model.',
      );
    }
    const adapter = await navigator.gpu.requestAdapter().catch(() => null);
    if (!adapter) {
      throw new Error(
        'WebGPU is present but no GPU adapter is available, so the model ' +
          'cannot run in this browser. This is what a machine with no GPU, ' +
          'or a headless one, reports. Pick a Gemini model instead.',
      );
    }
    if (!enginePromise) {
      enginePromise = (async () => {
        const webllm = await import(MODULE);
        return webllm.CreateMLCEngine(modelId, {
          initProgressCallback: (report) => onProgress(report.text || ''),
        });
      })().catch((error) => {
        // A failed load must not be cached, or every later try reports the
        // first failure.
        enginePromise = null;
        throw error;
      });
    }
    await enginePromise;
  }

  /**
   * Sends one turn. `messagesJson` is [{role, content}, ...] and the reply
   * comes back as the model's text.
   */
  async function chat(messagesJson, temperature, maxTokens) {
    if (!enginePromise) throw new Error('The model has not been loaded yet.');
    const engine = await enginePromise;
    const reply = await engine.chat.completions.create({
      messages: JSON.parse(messagesJson),
      temperature: temperature,
      max_tokens: maxTokens,
    });
    return reply.choices?.[0]?.message?.content ?? '';
  }

  window.a2uiWebllm = { create, chat };
})();
