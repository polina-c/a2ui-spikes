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

## Notes

The knowledge base is embedded rather than fetched: Flutter bundles assets only
from inside the package, so `tools/sync-domain.sh` copies `ci/domain` into
`assets/domain` and the app reads it from the bundle.

The local model family is listed in the picker for completeness. This build
only speaks to Gemini; WebLLM is a JavaScript library and wiring it into a
Flutter web app through interop was out of scope for this run.
