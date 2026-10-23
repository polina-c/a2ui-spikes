# Text-only chat

A React chat where a Gemini model guides the user to a product, answering in
Markdown. It is the React version of the
[Flutter text-only chat](../../dart/text_only). See
[1-text-only-chat.md](../../../doc/blueprints/1-text-only-chat.md) for what it
does, and its [States](../../../doc/blueprints/1-text-only-chat.md#states)
section for the buttons in each state.

## Prompt

Implement a React analog of Dart's [text_only](../../dart/text_only) and
[shared_ui](../../dart/shared_ui), in [simple_chat/apps/react](..).

## Run it

Install the packages once, from [simple_chat/apps/react](..):

```bash
npm install
```

Then, from this folder, with `GEMINI_API_KEY` set in the environment:

```bash
npm run dev
```

The app is at http://localhost:5173. Vite builds the key into the page, as
`--dart-define` does for the Flutter app, so do not publish a build made with
your key.

```bash
npm test
```
