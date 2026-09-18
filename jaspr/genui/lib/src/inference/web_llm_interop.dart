import 'dart:js_interop';

/// The JavaScript shim this package talks to, installed on `globalThis` by
/// `web_llm.js`.
///
/// WebLLM ships as an ES module and loads its own WebGPU workers, so it is
/// imported by a small JavaScript module rather than bound directly here.
/// That module is the only JavaScript in the package, and its whole job is
/// to present promises and callbacks that Dart can hold.
@JS('a2uiWebLlm')
external JSObject? get _shim;

/// Whether `web_llm.js` has finished loading.
///
/// It is a module script, so it runs after the page's Dart entry point does.
bool get isWebLlmLoaded => _shim != null;

/// The shim, or an error explaining that the page did not include it.
JSWebLlm get webLlm {
  final JSObject? shim = _shim;
  if (shim == null) {
    throw StateError(
      'WebLLM is not loaded. Add web_llm.js to the page as '
      '<script type="module" src="web_llm.js"></script>.',
    );
  }
  return shim as JSWebLlm;
}

/// The shim's interface.
extension type JSWebLlm._(JSObject _) implements JSObject {
  /// The model IDs WebLLM has prebuilt configurations for.
  external JSArray<JSString> models();

  /// The context window [modelId] is configured for, in tokens, or null
  /// when WebLLM's prebuilt configuration does not say.
  external JSNumber? defaultContextWindowSize(String modelId);

  /// Whether this browser exposes the WebGPU API at all.
  external bool hasWebGpu();

  /// Whether WebGPU can give out an adapter to run on.
  external JSPromise<JSBoolean> hasWebGpuAdapter();

  /// Loads [modelId], reporting progress as it downloads and compiles.
  ///
  /// [optionsJson], when it is not null, is a JSON object of WebLLM
  /// `ChatOptions`: the settings that are fixed when the engine is built,
  /// which is where the context window is chosen. Resolves once the model
  /// is ready to answer.
  external JSPromise<JSAny?> init(
    String modelId,
    JSFunction onProgress,
    JSString? optionsJson,
  );

  /// Streams an answer to [messagesJson], a JSON array of `{role, content}`.
  ///
  /// [samplingJson], when it is not null, is a JSON object of sampling
  /// parameters to pass to the model. Calls [onDelta] with each chunk of
  /// text. Resolves when the answer ends.
  external JSPromise<JSAny?> stream(
    String messagesJson,
    JSFunction onDelta,
    JSString? samplingJson,
  );

  /// Abandons the answer in flight, if there is one.
  external void interrupt();
}

/// A step in loading a model.
extension type JSProgress._(JSObject _) implements JSObject {
  /// A fraction between 0 and 1, or 0 when the step has no measurable size.
  external double get progress;

  /// What is happening, in words, e.g. how much of the weights have loaded.
  external String get text;
}
