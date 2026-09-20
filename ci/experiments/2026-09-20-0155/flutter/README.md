# Flutter arm

The simple chat app on the [Flutter GenUI SDK](https://github.com/flutter/genui),
`genui` 0.10.3. a2ui has no Flutter package: `dart/a2ui_flutter` in the a2ui
repo is a README that points here.

## Run it

```bash
flutter pub get
flutter run -d chrome --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

Without the define, the app asks for the key on the first screen and keeps it
behind dots. The recorded CUJ ran against the release build, which was built
with no key in it:

```bash
flutter build web --release
python3 -m http.server 4174 --directory build/web
```

Tests:

```bash
flutter test
```

## Layout

* `lib/picker_page.dart` - the model picker the app opens on
* `lib/chat_page.dart` - the transcript, genui's `Conversation`, `SurfaceController`
  and `Surface`
* `lib/prompt.dart` - the selling half of the system prompt; genui writes the
  protocol half from the catalog with `PromptBuilder.chat`
* `lib/landing.dart` - a client function that opens a landing page by the name
  of the machine, rather than genui's built-in `openUrl`, which takes an
  address from the model
* `lib/gemini.dart` - the Gemini call, with a retry for the 503s
* `lib/knowledge.dart` - the knowledge base, read from the bundled assets
* `web/flutter_bootstrap.js` - loads CanvasKit from this app instead of
  gstatic.com, so the app starts with no third-party request
* `lib/model_client.dart` - the interface the chat talks to, so Gemini and the
  in-browser model are the same thing to it
* `lib/local.dart` and `web/webllm_bridge.js` - the in-browser model: a Flutter
  web app has no JavaScript bundler, so WebLLM is loaded as an ES module and
  reached through `dart:js_interop`, with the conversation crossing as JSON

## Notes

The knowledge base is embedded rather than fetched: Flutter bundles assets only
from inside the package, so `tools/sync-domain.sh` copies `ci/domain` into
`assets/domain` and the app reads it from the bundle.

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

**This path has never been run.** The container these apps were built in has no
GPU adapter and blocks both hosts, so it was verified only as far as it can be:
the picker starts without a key, the chat header names the in-browser model, and
the call reaches WebLLM and comes back with the GPU diagnostic. What happens
after the weights load is untested.
