# A2UI-enhanced chat

A Flutter chat where a Gemini model guides the user to a product, as
[text_only](../text_only) does, with UI that the model generates through
[A2UI](https://github.com/a2ui-project/a2ui) protocol v0.9.1: buttons for the
likely answers to a question, a card for a recommendation, and a carousel to
compare options. See
[2-a2ui-enhanced-chat.md](../../../doc/blueprints/2-a2ui-enhanced-chat.md) for
what it does.

[Video](https://polina-c.github.io/a2ui-spikes-binaries/simple_chat/apps/dart/a2ui_9_1/videos/chat.webm),
at phone size: the default prompt, three questions answered with the buttons
the model generated, a pause to add context and a resume, ending on a
recommendation and its alternative as two cards side by side.

## Prompt

Inhance simple_chat/apps/dart/text_only with A2UI as specified in
simple_chat/doc/blueprints/2-a2ui-enhanced-chat.md, limiting protocol to v0.91.

## How it works

The app calls Gemini itself, so it plays both A2UI roles. It renders the UI
with [a2ui_flutter](https://github.com/a2ui-project/a2ui/tree/main/dart/a2ui_flutter),
and it uses the agent SDK,
[a2ui_agent](https://github.com/a2ui-project/a2ui/tree/main/dart/a2ui_agent),
to teach the model the catalog and to read the A2UI in its answers.

1. The model writes UI in direct JSON blocks between parts of its text. The
   app reads each answer while it streams, and shows its text and its surfaces
   in the order the model wrote them.
2. A button answers for the user. Its action carries a `text` in its context,
   which the app sends as the user's next message. A button that opens a link
   calls `openUrl` instead.
3. If a block cannot be read, the answer's UI stops at that block, and the
   rest of the answer shows as text.

The catalog, in [catalog.dart](lib/catalog.dart), keeps Text, Image, Row,
Column, Card, Divider, Button, and the `openUrl` function from the basic
catalog. It adds MdCarousel, which shows
[MdCarouselView](../shared_ui/lib/src/md_carousel_view.dart) with an action for
each card, run by the card's Select button. The rules for using the catalog in
this chat are in [generated_ui.dart](lib/generated_ui.dart).

`a2ui_flutter` is not on pub.dev yet, so the A2UI packages come from git at
one commit, and the [root pubspec](../../../../pubspec.yaml) overrides
`a2ui_core` to the same commit.

## Run it

```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

On macOS, `flutter run -d macos` also reads `GEMINI_API_KEY` from the
environment.

```bash
flutter test
```
