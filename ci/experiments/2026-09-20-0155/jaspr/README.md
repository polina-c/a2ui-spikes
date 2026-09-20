# Jaspr arm

The simple chat app on [Jaspr](https://jaspr.site) 0.23.4 and
[`a2ui_core`](https://pub.dev/packages/a2ui_core) 0.1.1, with an A2UI renderer
written for this experiment. a2ui has no Jaspr renderer, and no web renderer in
Dart at all.

## Run it

```bash
dart pub get
jaspr serve                    # http://localhost:8080
```

The recorded CUJ ran against the production build:

```bash
jaspr build
python3 -m http.server 4175 --directory build/jaspr
```

Tests:

```bash
dart test
```

The app asks for a Gemini API key on the first screen and keeps it in the tab.
A key can also be compiled in with `--define=GEMINI_API_KEY=...`; the recorded
run left that unset, so no key is in the built JavaScript.

## Layout

* `lib/a2ui/renderer.dart` - the A2UI renderer: the piece that does not exist
  upstream. It turns an `a2ui_core` component tree into Jaspr components.
* `lib/a2ui/catalog.dart` - the catalog this app offers the model: a2ui_core's
  minimal catalog plus a Card.
* `lib/picker.dart` - the model picker the app opens on
* `lib/chat.dart` - the conversation, the `MessageProcessor` and the surfaces
* `lib/prompt.dart` - the hand-written system prompt, with the catalog schema
  pulled in at runtime from `getClientCapabilities`
* `lib/gemini.dart` - the Gemini call, with a retry for the 503s
* `lib/model_client.dart` - the interface the chat talks to, so Gemini and the
  in-browser model are the same thing to it
* `lib/local.dart` and `web/webllm_bridge.js` - the in-browser model: Jaspr has
  no JavaScript bundler, so WebLLM is loaded as an ES module and reached
  through `dart:js_interop`, with the conversation crossing as JSON
* `lib/knowledge.dart` - the knowledge base, fetched over HTTP from `web/domain`
* `web/styles.css` - the app's chrome *and* the generated components, whose
  class names are this renderer's own invention

## Notes

The knowledge base is fetched rather than embedded: Jaspr builds to static
files, so `tools/sync-domain.sh` copies `ci/domain` into `web/domain` and the
app reads it from its own origin at start-up. That keeps it out of the compiled
JavaScript and lets it change without a rebuild.

Two pieces of Jaspr friction, both of which the previous run hit and both of
which are still there. A freshly generated project does not resolve, because
`jaspr_builder` wants `analyzer ^12.1.0` while the `build_web_compilers` it
pins wants `>=13.3.0`; holding the compilers at `^4.8.5` fixes it. And a
project generated into a directory called `jaspr` is named `jaspr`, which
cannot depend on the package of the same name, so the package is renamed by
hand afterwards.

The in-browser model is described below.

## The in-browser model

The picker's second family runs the model on this machine with
[WebLLM](https://github.com/mlc-ai/web-llm) instead of calling Gemini: no key,
nothing leaves the browser, and a download of a gigabyte or more before the
first answer. It needs two things this repo cannot give it:

* **A browser with a usable GPU.** WebLLM runs on WebGPU. `navigator.gpu` has
  to exist (Chrome or Edge 113+, over https or localhost) *and*
  `requestAdapter()` has to return an adapter, which a machine with no GPU - a
  headless CI container, for instance - does not. Both cases are checked up
  front and reported in the chat, because the failure from inside WebLLM
  otherwise arrives much later and reads like a hang.
* **Two reachable hosts.** The library itself, and the weights from
  `huggingface.co`.

**This path has never been run.** The container these apps were built in
refuses `huggingface.co`, where the weights come from, so there is nothing to
load. Its WebGPU is a red herring worth knowing about: with default flags
`requestAdapter()` returns null, but started with `--enable-unsafe-webgpu
--enable-features=WebGPU,WebGPUService,Vulkan --enable-unsafe-swiftshader`
Chromium hands back a SwiftShader software adapter that creates a device and
runs a compute shader. It reports no `shader-f16`, which the `q4f16_1` models
listed here need, and it runs on the CPU. So the path was verified only as far
as it can be: the picker starts without a key, the chat header names the
in-browser model, and the call reaches WebLLM and comes back with the GPU
diagnostic. What happens after the weights load is untested.
