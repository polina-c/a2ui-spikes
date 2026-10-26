# A2UI apps analysis

## Overview

This document summarises a2ui enhanced applications
in this directory, highlighting the following details:

1. Are there issues in SDKs implementation?
2. How much code is added to app code (not tests) comparing to the text_only app?
3. What features of protocol were used and what were skipped?
4. What format was used (JSON or express)?
5. What components were used for catalog (agent was asked to select only needed ones)?

## Issues

1. Thinking is about A2UI: https://github.com/a2ui-project/a2ui/issues/3576 
2. API gaps for all-in-one: https://github.com/a2ui-project/a2ui/issues/3597 
3. Express is not working in both Dart and TS: https://github.com/a2ui-project/a2ui/issues/3598
4. Lack of guidance for choosing format: https://github.com/a2ui-project/a2ui/issues/3599

## Analysis

The three A2UI apps are [flutter/a2ui_0_9_1](flutter/a2ui_0_9_1),
[react/a2ui_0_9_1](react/a2ui_0_9_1) and [react/a2ui_1_0](react/a2ui_1_0).
Each one is the text_only app of its platform with generated UI added, as the
[A2UI blueprint](../doc/blueprints/2-a2ui-enhanced-chat.md) describes. The two
React apps differ only in the protocol version: a2ui_1_0 changes 4 source files
and 3 test files of a2ui_0_9_1, adding 67 lines of app code and removing 55.

### Videos

Each video is at phone size and starts with the default prompt.

1. [Flutter text_only](https://polina-c.github.io/a2ui-spikes-binaries/simple_chat/apps/dart/text_only/videos/chat.webm):
   two questions, a pause to add context and a resume, and a recommendation
   with a picture of the product.
2. [Flutter a2ui_0_9_1](https://polina-c.github.io/a2ui-spikes-binaries/simple_chat/apps/dart/a2ui_9_1/videos/chat.webm):
   three questions, two of them answered with the buttons the model generated,
   a pause to add context and a resume, and a recommendation card with a
   picture of the product and a button that opens its page.
3. [React text_only](https://polina-c.github.io/a2ui-spikes-binaries/simple_chat/apps/react/text_only/videos/chat.webm):
   the same steps as the Flutter text_only video.
4. [React a2ui_0_9_1](https://polina-c.github.io/a2ui-spikes-binaries/simple_chat/apps/react/a2ui_0_9_1/videos/chat.webm):
   three questions, two of them answered with the buttons the model generated,
   a pause to add context and a resume, and a carousel of two dishwashers,
   each with a picture and a button to view it.
5. [React a2ui_1_0](https://polina-c.github.io/a2ui-spikes-binaries/simple_chat/apps/react/a2ui_1_0/videos/chat.webm):
   the same steps as the React a2ui_0_9_1 video, with a list of features on
   each card of the carousel.

### Code added

The counts are non-blank lines, comments included, compared with the text_only
app of the same platform. Added and removed lines come from a line diff of each
file with its text_only counterpart, so a changed line counts as one removed
and one added.

| App                | text_only | A2UI app | Added | Removed |
| ------------------ | --------: | -------: | ----: | ------: |
| Flutter a2ui_0_9_1 |       416 |      863 |   464 |      17 |
| React a2ui_0_9_1   |       426 |      910 |   531 |      47 |
| React a2ui_1_0     |       426 |      922 |   543 |      47 |

The Flutter apps have no CSS, and the HTML changes are the page's title and
description. Without comment lines, the added app code is 389 lines of Dart,
415 lines of TypeScript in React a2ui_0_9_1, and 417 in React a2ui_1_0. These
counts include the rules that teach the model to write UI in this chat, about
20 lines of text in the code.

Most of the added app code is in three new files, which each app has:

1. `answer_content` reads an answer as it streams, into its text and the
   surfaces its A2UI blocks build: 138 lines in Dart, and 168 in TypeScript.
2. `catalog` builds the catalog from the basic components the chat keeps and
   MdCarousel: 114 lines in Dart, and 110 and 142 in TypeScript. The v1.0
   catalog also holds the rules for using it in the chat.
3. `generated_ui` sets up the agent SDK, writes the part of the system prompt
   about UI, and turns a button press into the user's reply: 79 lines in Dart,
   and 90 and 70 in TypeScript.

The rest goes into the chat page, which shows an answer's text and surfaces in
the order the model wrote them (88 lines added in Dart, 106 in TypeScript), and
into the controller, which feeds each answer to `answer_content` as it streams
(30 and 39 lines). The React apps also add `a2ui_theme.css`, 30 lines that give
the basic components the colors of shared_ui's theme.

The A2UI packages are new dependencies. The Flutter app takes a2ui_agent,
a2ui_core and a2ui_flutter from git at one commit, and adds
flutter_markdown_plus, json_schema_builder and url_launcher. The React apps
take @a2ui/agent, @a2ui/react and @a2ui/web_core from npm, and add zod.

### Protocol features

All three apps use these features:

1. The model creates surfaces inside its answers, in blocks between parts of
   the text. In v0.9.1 a block is a `createSurface` message followed by
   `updateComponents`. In v1.0 it is one `createSurface` message that holds the
   components.
2. Event actions on buttons and on carousel cards. The app sends the action's
   reply as the user's next message.
3. A function call action, `openUrl` from the basic catalog, on the buttons
   that open a landing page.
4. A custom component, MdCarousel, with an action on each card.
5. Markdown in `Text`, rendered the way the chat renders messages.
6. Progressive rendering: the agent SDK passes on a surface while its block is
   still arriving, and the strings under the keys `text` and `markdown` grow
   as they are written.
7. Renderer capabilities (`supportedCatalogIds`), which the app hands to the
   agent SDK in-process, to choose the catalog the model learns.
8. Validation of each message against the protocol and the catalog. A block
   that fails stops the UI of that answer, and the rest of the answer shows as
   text.

React a2ui_1_0 also uses these v1.0 features:

1. A button's reply is the `userMessage` of its action, which the renderer
   resolves. The v0.9.1 apps put the reply under a `text` key in the action's
   context, a convention that the prompt sets up.
2. The catalog's `instructions` hold the rules for using it in the chat, in
   place of a section of the system prompt.
3. `allowedParents` keeps MdCarousel at the top of a surface or in a column,
   and the renderer rejects it anywhere else.
4. `openUrl` requires user activation, so only a click opens a page.
5. Function calls name the function with the `@call` key.

All three skip these features:

1. The data model: `updateDataModel`, data bindings, list templates and
   `sendDataModel`. The model writes each value where it shows, and nothing on
   a surface changes after the answer.
2. Changes to the UI of an earlier answer, with `updateComponents` or
   `deleteSurface`. Each answer has its own renderer (a `MessageProcessor`), so
   answers never clash over a surface id, and a later answer cannot reach the
   surfaces of an earlier one.
3. Renderer-to-agent messages. A button press reaches the model as the user's
   text, not as an `action` message, and the model is not told about UI that
   failed to render. The user sees the error instead.
4. Input components and their checks, such as TextField and ChoicePicker. The
   chat's own text field takes any answer.
5. The formatting and logic functions of the basic catalog, such as
   `formatCurrency` and `and`. The model writes text as it should read.
6. The `theme` of a v0.9.1 surface. The catalog accepts one, but the prompt
   does not ask for it, and the app's own theme styles the UI. v1.0 removed it.

React a2ui_1_0 also skips mixing catalogs on one surface, since one catalog
holds every component the chat needs, and the function calls between agent and
renderer (`callRendererFunction` and `callAgentFunction`), since the app is
both.

### Format

All three apps use direct JSON: each block is a JSON list of A2UI messages
inside `<a2ui-json>` tags, and the app reads it while it streams. None of them
uses Express. The Dart agent SDK makes Express the default, and the Flutter app
chooses direct JSON because direct JSON can be read while it streams. The
TypeScript agent SDK cannot stream Express (its Express format sets
`supportsStreaming` to false), so the React apps use direct JSON, which is also
the default there.

### Catalog components

The three catalogs have the same components:

1. From the basic catalog: Text, Image, Row, Column, Card, Divider and Button,
   and the function `openUrl`.
2. Added: MdCarousel, cards in a row that scrolls sideways, each with a name,
   Markdown, and a Select button that runs the card's action. It shows
   MdCarouselView from shared_ui.

They leave out the other basic components (Icon, Video, AudioPlayer, List,
Tabs, Modal, TextField, CheckBox, ChoicePicker, Slider and DateTimeInput) and
the other basic functions, which validate, format and combine values.

The catalogs differ in these ways:

1. The Flutter app renders the basic components as Flutter widgets from
   a2ui_flutter. The React apps render them as web components from
   @a2ui/web_core, which @a2ui/react hosts, and style them through CSS
   variables.
2. React a2ui_1_0 uses the v1.0 basic catalog, where Text has no heading
   variants, so headings are Markdown.
3. In the Flutter app, MdCarousel requires the name and the Markdown of each
   card, and at least one card. The React catalogs show the model the same
   required fields, but accept a card without them and an empty list, because
   the TypeScript agent SDK passes the carousel on while its cards are still
   arriving.
4. In React a2ui_1_0, MdCarousel declares `allowedParents`.
