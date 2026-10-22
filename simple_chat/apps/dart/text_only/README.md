# Text-only chat

A Flutter chat where a Gemini model guides the user to a product, answering in
Markdown. See [blueprint.md](blueprint.md) for what it does, and
[states.md](states.md) for the buttons in each state.

[Video](https://polina-c.github.io/a2ui-spikes-binaries/simple_chat/apps/text_only/videos/chat.webm):
the default prompt, two questions, then a pause to add context and a resume,
ending on a recommendation.

## Run it

```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

On macOS, `flutter run -d macos` also reads `GEMINI_API_KEY` from the
environment.

```bash
flutter test
```

## Layout

1. `lib/chat_controller.dart`: the conversation, and pausing and resuming an
   answer.
2. `lib/gemini.dart`: the streaming call to Gemini, and the notes that tell
   the model about a pause.
3. `lib/chat_page.dart`: the message list and the input row.
4. `lib/prompt.dart`: the system prompt, read from the bundled documents.

`assets/doc` is a link to [simple_chat/doc](../../doc), so the chat blueprint
and the domain knowledge are bundled from where they are written.
