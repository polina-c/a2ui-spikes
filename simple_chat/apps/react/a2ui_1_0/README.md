# Simple chat with A2UI 1.0

A React chat where a Gemini model guides the user to a product, as
[text_only](../text_only) does, with UI that the model generates through
[A2UI](https://github.com/a2ui-project/a2ui) protocol v1.0: buttons for the
likely answers to a question, a card for a recommendation, and a carousel to
compare options. It does what [a2ui_0_9_1](../a2ui_0_9_1) does, with the
features v1.0 adds where they help. See
[2-a2ui-enhanced-chat.md](../../../doc/blueprints/2-a2ui-enhanced-chat.md) for
what it does.

## Prompt

Inhance simple_chat/apps/react/text_only with A2UI as specified in
simple_chat/doc/blueprints/2-a2ui-enhanced-chat.md, employing all
helpful features of the protocol.

## How it works

The app calls Gemini itself, so it plays both A2UI roles. It renders the UI
with [@a2ui/react](https://www.npmjs.com/package/@a2ui/react) and the v1 basic
catalog of [@a2ui/web_core](https://www.npmjs.com/package/@a2ui/web_core), and
it uses the agent SDK, [@a2ui/agent](https://www.npmjs.com/package/@a2ui/agent),
to teach the model the catalog and to read the A2UI in its answers.

1. The model writes UI in direct JSON blocks between parts of its text. The
   app reads each answer while it streams, and shows its text and its surfaces
   in the order the model wrote them. A surface fills in as its components
   arrive.
2. A button answers for the user with the `userMessage` of its action, which
   the app sends as the user's next message. A button that opens a link calls
   `openUrl` instead.
3. If a block cannot be read, the answer's UI stops at that block, and the
   rest of the answer shows as text.

The catalog, in [catalog.tsx](src/catalog.tsx), keeps Text, Image, Row,
Column, Card, Divider, Button, and the `openUrl` function from the basic
catalog. It adds MdCarousel, which shows
[MdCarouselView](../shared_ui/src/md_carousel_view.tsx) with an action for
each card, run by the card's Select button.

## What it uses from v1.0

1. Each block is one `createSurface` message that holds the surface's
   components, instead of a `createSurface` followed by `updateComponents`.
2. A button's reply is the `userMessage` of its `event` action, which the
   renderer resolves and passes on with the action. In v0.9.1 the reply needs
   a key in the action's context that the app and the prompt agree on.
3. The rules for using the catalog in this chat are the catalog's own
   `instructions`, which the model reads with the catalog's schema.
4. MdCarousel declares `allowedParents`, so the model learns to put a carousel
   at the top of a surface or in a column, where it has the full width to
   scroll in, and the renderer rejects one anywhere else.
5. `openUrl` comes from the v1 basic catalog, which marks it as requiring user
   activation, so only a click opens a page.

It leaves out the v1.0 features that do not help this chat:

1. Data binding, since the model writes every value where it shows, and
   nothing on a surface changes after the answer is written.
2. Mixing catalogs on one surface, since one catalog holds every component
   the chat needs.
3. Function calls between the agent and the renderer (`callRendererFunction`
   and `callAgentFunction`), since the app is both, and the model's answers
   are the only messages.
4. The Express inference format, which is shorter than direct JSON, but which
   the agent SDK cannot read while it streams.

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
