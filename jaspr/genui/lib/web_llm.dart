/// Runs a language model in the browser tab, for `package:genui`.
///
/// This is a separate entry point from `package:genui/genui.dart` because it
/// only compiles for the web: it is JavaScript interop around
/// [WebLLM](https://github.com/mlc-ai/web-llm), which needs WebGPU.
///
/// Using it takes two pieces. This library is the Dart half; the other half
/// is `web_llm.js`, a small module that imports WebLLM and installs the shim
/// this talks to, which the page must load:
///
/// ```html
/// <script type="module" src="web_llm.js"></script>
/// ```
///
/// A copy of that module is in this package under `lib/assets/web_llm.js`.
library;

export 'src/facade/conversation.dart' show ChatMessage, ChatMessageRole;
export 'src/inference/web_llm_client.dart';
export 'src/inference/web_llm_interop.dart' show isWebLlmLoaded;
