# Simple chat, Flutter

The [simple chat blueprint](../../../blueprints/simple_chat.md) built with the
[Flutter GenUI SDK](https://github.com/flutter/genui), `genui` and its A2UI
support.

There is no backend. The browser calls Gemini directly and pipes the reply into
genui's transport, which parses the A2UI messages out of the stream and renders
them as Flutter widgets.

## Why genui and not a2ui

The a2ui repo has no Flutter package. `dart/a2ui_flutter` is a README saying one
is coming and pointing at flutter/genui, which is what this arm uses. genui
depends on `a2ui_core`, so the protocol underneath is the same.

## Running it

```bash
flutter pub get
flutter run -d chrome
```

The app asks which model to use, and asks for a Gemini API key if none was
compiled in. To compile one in:

```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=your_key
```

Do not commit a build made that way; the key ends up in the output.

## Driving the CUJ

```bash
flutter build web --release
(cd build/web && python3 -m http.server 4174) &
node ../tools/cuj.mjs flutter http://localhost:4174/ "$PWD/../videos" flutter
```

The driver works through the semantics tree, not the canvas. See the note on
semantics below.

## How it is put together

`lib/models.dart` is the list of families, models and parameter ranges shown on
the opening screen. `lib/domain.dart` loads the knowledge base and the six
landing pages from assets; `assets/domain` is a symlink to the repo's `domain`
folder, so there is no second copy of the text in the tree.

`lib/gemini.dart` is a plain HTTP client with a retry for the 503s Gemini
returns when it is busy. `lib/chat_page.dart` wires up genui: a
`SurfaceController` over the basic catalog, an `A2uiTransportAdapter` whose
`onSend` calls Gemini, and a `Conversation` that ties them together and loops
user interactions back to the model on its own.

The system prompt is built by genui's own `PromptBuilder.chat`, which writes the
protocol and catalog half from the catalog object. Only the selling instructions
and the knowledge base are supplied by this app.

## Things worth knowing

The landing page link needs no special handling. genui's basic catalog ships an
`openUrl` client function, so the model asks for the page and the framework
opens it. The a2ui web catalog has no equivalent, and the React arm has to
implement it in the app.

Flutter web paints into a canvas, so there is no DOM for a screen reader or a
test driver to read. `main.dart` calls `SemanticsBinding.instance.ensureSemantics()`
to turn the semantics tree on for good. Even then a real pointer click is lost,
because the semantics nodes overlap and the click lands on whichever is on top;
the CUJ driver dispatches the click on the node itself, which is the path a
screen reader takes.

`genui`'s own integration skill is out of date with its API. It shows
`PromptBuilder.chat(catalog:, instructions:)` and a `systemPrompt` property; the
package takes `systemPromptFragments` and exposes `systemPrompt()` and
`systemPromptJoined()`.

## Tests

```bash
flutter test
```

Two widget tests cover the opening screen: that it starts on a default model and
cannot continue without a key, and that each parameter shows the range the UI
allows.
