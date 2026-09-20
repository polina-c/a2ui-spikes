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

The local model family is listed in the picker for completeness. This build
only speaks to Gemini.
