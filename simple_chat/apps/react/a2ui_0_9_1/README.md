# Simple chat with A2UI 0.9.1

A React chat where a Gemini model guides the user to a product, as
[text_only](../text_only) does, with UI that the model generates through
[A2UI](https://github.com/a2ui-project/a2ui) protocol v0.9.1: buttons for the
likely answers to a question, a card for a recommendation, and a carousel to
compare options. It is the React version of the
[Flutter A2UI chat](../../flutter/a2ui_0_9_1). See
[2-a2ui-enhanced-chat.md](../../../doc/blueprints/2-a2ui-enhanced-chat.md) for
what it does.

[Video](https://polina-c.github.io/a2ui-spikes-binaries/simple_chat/apps/react/a2ui_0_9_1/videos/chat.webm),
at phone size: the default prompt, three questions, two answered with the
buttons the model generated and one typed next to them, a pause to add context
and a resume, ending on a recommendation with a carousel of two dishwashers,
each with a picture and a button to view it.

## Prompt

Inhance simple_chat/apps/react/text_only with A2UI as specified in
simple_chat/doc/blueprints/2-a2ui-enhanced-chat.md, limiting protocol to v0.9.1.

## How it works

The app calls Gemini itself, so it plays both A2UI roles. It renders the UI
with [@a2ui/react](https://www.npmjs.com/package/@a2ui/react) and the basic
catalog of [@a2ui/web_core](https://www.npmjs.com/package/@a2ui/web_core), and
it uses the agent SDK, [@a2ui/agent](https://www.npmjs.com/package/@a2ui/agent),
to teach the model the catalog and to read the A2UI in its answers.

1. The model writes UI in direct JSON blocks between parts of its text. The
   app reads each answer while it streams, and shows its text and its surfaces
   in the order the model wrote them. A surface fills in as its components
   arrive.
2. A button answers for the user. Its action carries a `text` in its context,
   which the app sends as the user's next message. A button that opens a link
   calls `openUrl` instead.
3. If a block cannot be read, the answer's UI stops at that block, and the
   rest of the answer shows as text.

The catalog, in [catalog.tsx](src/catalog.tsx), keeps Text, Image, Row,
Column, Card, Divider, Button, and the `openUrl` function from the basic
catalog. It adds MdCarousel, which shows
[MdCarouselView](../shared_ui/src/md_carousel_view.tsx) with an action for
each card, run by the card's Select button. The rules for using the catalog in
this chat are in [generated_ui.ts](src/generated_ui.ts), and
[a2ui_theme.css](src/a2ui_theme.css) gives the basic components the colors of
shared_ui.

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
