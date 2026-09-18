# Simple Chat

A chat where the assistant answers with working UI, not only with words. Ask it
to plan a trip and it sends back a form with date pickers and a list of options;
fill the form in and press the button, and what you entered goes back to the
model as the next turn.

This is the [Simple Chat][upstream] sample from Flutter GenUI, rebuilt in
[Jaspr][jaspr] on top of [`jaspr/genui`](../genui). The model runs in the browser
tab through [WebLLM][webllm], so there is no API key and no server: the
conversation, the form you fill in, and the model itself all stay on your
machine.

[upstream]: https://github.com/flutter/genui/tree/main/examples/simple_chat
[jaspr]: https://jaspr.site
[webllm]: https://github.com/mlc-ai/web-llm

## Requirements

* The Dart SDK, 3.10 or newer.
* The Jaspr CLI: `dart pub global activate jaspr_cli`.
* A browser with WebGPU. Chrome and Edge 113 and later have it on by default.
  Safari 18 has it; in Firefox it is behind `dom.webgpu.enabled`.
* A few gigabytes of disk for the model weights, and the patience to download
  them once.

You do not need a GPU in the usual sense. WebGPU runs on integrated graphics,
but a machine with a discrete GPU answers noticeably faster.

## Run it

```sh
cd jaspr/simple_chat
dart pub get
jaspr serve
```

Open http://localhost:8080 and press "Load the model".

The first load downloads the model, which takes a few minutes on a fast
connection and is reported on the page as it goes. The browser caches the
weights, so later runs start in seconds. Nothing is downloaded until you press
the button.

To build a static copy you can serve from anywhere:

```sh
jaspr build           # writes build/jaspr
```

The output is HTML, CSS, JavaScript and nothing else. Any static file server
will do, but it has to be a server: `file://` will not work, because the page
loads WebLLM as a module.

## Choosing a model

The default is `Llama-3.2-3B-Instruct-q4f32_1-MLC`, picked so the first load is
minutes rather than an hour. Generating valid A2UI asks a lot of a model this
size, and a 3B model will sometimes send a component that is not in the catalog
or forget the `root` component. The app renders what it can and shows an error
in place of what it cannot, so a bad message costs one component rather than the
page.

A larger model follows the schema more closely. To try one, pass its ID when the
session is created in [lib/app.dart](lib/app.dart):

```dart
final ChatSession _session = ChatSession(
  modelId: 'Llama-3.1-8B-Instruct-q4f32_1-MLC',
);
```

`WebLlmClient.models()` returns every ID WebLLM has a prebuilt configuration
for.

## What to ask it

The model answers with UI when the answer has shape to it. Questions that want a
choice, a form or a list work best:

* "Help me plan a weekend in Lisbon."
* "I want to book a table. Ask me for what you need."
* "Give me three beginner climbing spots near Las Vegas and let me pick one."

A question with a one-line answer gets a one-line answer, which is the correct
behavior.

## How it works

`lib/chat_session.dart` holds the whole thing. It owns three objects from
`package:genui`:

A `SurfaceController` holds the surfaces. A2UI messages go into it and surfaces
come out, and it reports what the user does with them.

A `Conversation` talks to the model. It keeps the history, splits each response
into the prose you read and the A2UI messages that build surfaces, and turns a
button press on a generated surface into the next turn of the conversation.

A `PromptBuilder` writes the system prompt that teaches the model the catalog:
which components exist, what properties they take, and what an A2UI message
looks like. It is built in compact mode, which is the setting that fits a
browser-sized context window. See the [package README](../genui/README.md#the-system-prompt).

The transcript is a list of turns, each either text or a surface, in the order
they arrived. That ordering is what makes a reply with a sentence, a form and a
closing sentence read as one answer.

Rendering is `SurfaceView`, which takes a surface and renders it. The app does
not know what is in a surface and does not need to: the catalog decides the
markup, and [web/styles.css](web/styles.css) styles the `a2ui-` classes it
produces so a generated form looks like it belongs on the page.

## Files

```
lib/main.client.dart        Browser entry point; turns on logging
lib/app.dart                Loads a model, then shows the chat
lib/chat_session.dart       Controller, conversation, and the transcript
lib/components/             The chat screen, a turn, and the loading screen
web/index.html              The page
web/styles.css              App chrome, and styles for the a2ui- classes
web/web_llm.js              The WebLLM module, copied from package:genui
```

`web/web_llm.js` is a copy of `genui/lib/assets/web_llm.js`. It is the
JavaScript half of the package's WebLLM support, and the page has to load it for
the Dart half to find anything.

## Logging

`main.client.dart` sets `Logger.root.level` to `Level.INFO`. Set it to
`Level.ALL` to see every A2UI message as it is applied, which is the fastest way
to find out why a generated surface looks wrong.
