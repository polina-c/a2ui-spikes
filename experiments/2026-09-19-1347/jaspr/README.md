# Simple chat, Jaspr

The [simple chat blueprint](../../../blueprints/simple_chat.md) built in
[Jaspr](https://jaspr.site), on `a2ui_core` and a renderer written for this
experiment.

There is no backend. The browser calls Gemini directly, and the A2UI messages in
the reply are turned into DOM by `lib/a2ui/renderer.dart`.

## The renderer

a2ui has no Jaspr renderer, and nobody else ships one, so this arm had to write
it. `a2ui_core` does more of the work than that makes it sound: it parses the
messages, keeps the component tree and the data model, resolves paths, and
dispatches actions. What was missing was the last step, turning a component tree
into a framework's views.

`lib/a2ui/renderer.dart` is that step, in about 180 lines. It covers the minimal
catalog that ships with `a2ui_core` (Text, Row, Column, Button, TextField) plus
Card, and it redraws on two signals: components arriving, and the data model
changing. A component it does not know is drawn as a visible placeholder rather
than skipped, so a model reaching past the catalog shows up on screen instead of
rendering nothing.

The catalog is the minimal one, which is smaller than the basic catalog the
React and Flutter arms use. It is enough for this app and no more.

## Running it

```bash
dart pub get
jaspr serve
```

The app asks which model to use, and asks for a Gemini API key if none was
compiled in. To compile one in, pass
`--dart-define=GEMINI_API_KEY=your_key`, and do not commit the result.

## Driving the CUJ

```bash
jaspr build
(cd build/jaspr && python3 -m http.server 4175) &
node ../tools/cuj.mjs dom http://localhost:4175/ "$PWD/../videos" jaspr
```

Jaspr renders real elements, so the driver runs in `dom` mode, the same as the
React arm.

## How it is put together

`lib/models.dart` is the list of families, models and parameter ranges shown on
the opening screen. `lib/domain.dart` fetches the knowledge base and the six
landing pages over HTTP at startup; `web/domain` is a symlink to the repo's
`domain` folder, so the files are served next to the app. Of the two options the
blueprint allows, this arm fetches rather than embeds, which keeps the knowledge
out of the compiled bundle and lets it change without a rebuild.

`lib/prompt.dart` builds the system prompt, taking the component schemas from
the catalog rather than repeating them by hand. `lib/chat.dart` owns the
`MessageProcessor`, gives each assistant turn its own surface, and handles
actions: a press on a generated button goes back to the model as a turn, except
`openLandingPage`, which the app handles by opening the URL.

## Things worth knowing

`jaspr create` produces a project that does not resolve. `jaspr_builder` wants
`analyzer ^12.1.0` and the `build_web_compilers` it pins wants `>=13.3.0`.
Holding `build_web_compilers` below 4.8.6 fixes it, which is what `pubspec.yaml`
does.

The generated project is named after its directory, so a directory called
`jaspr` produces a package called `jaspr`, and a package may not depend on
itself. This one is `simple_chat_jaspr`.

Reading a value out of an input event needs typed interop
(`event.target as web.HTMLInputElement`). Going through `dynamic` analyzes
cleanly and then silently does nothing once compiled to JavaScript, which
showed up as a button that never became enabled.

## Tests

```bash
dart test
```

Three tests pin the message shape the prompt promises the model: that the three
messages produce a surface with a root component, that a bound property reads
through to the data model, and that pressing a button reports the action with
its context.
