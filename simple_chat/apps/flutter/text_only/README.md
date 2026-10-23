# Text-only chat

A Flutter chat where a Gemini model guides the user to a product, answering in
Markdown. See [1-text-only-chat.md](../../../doc/blueprints/1-text-only-chat.md)
for what it does, and its
[States](../../../doc/blueprints/1-text-only-chat.md#states) section for the
buttons in each state.

[Video](https://polina-c.github.io/a2ui-spikes-binaries/simple_chat/apps/dart/text_only/videos/chat.webm),
at phone size: the default prompt, two questions, then a pause to add context
and a resume, ending on a recommendation with a picture of the product.

## Prompt

Build the Flutter app in [simple_chat/apps/dart/text_only](.), as described in
[simple_chat/doc/blueprints/1-text-only-chat.md](../../../doc/blueprints/1-text-only-chat.md).

Reuse components from [shared_ui](../shared_ui).

Call the Gemini REST streaming API with the http package.

Write a short README: what the app does, how to run and test it, what prompt was used.

## Run it

```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

On macOS, `flutter run -d macos` also reads `GEMINI_API_KEY` from the
environment.

```bash
flutter test
```
