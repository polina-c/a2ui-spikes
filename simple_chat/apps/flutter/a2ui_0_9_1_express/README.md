# A2UI-enhanced chat in Express

The [a2ui_0_9_1](../a2ui_0_9_1) chat, with the model writing its UI in the
[A2UI Express](https://github.com/a2ui-project/a2ui/tree/main/specification/proposals/express)
inference format instead of direct JSON. The UI, the catalog and protocol
v0.9.1 are the same. See
[2-a2ui-enhanced-chat.md](../../../doc/blueprints/2-a2ui-enhanced-chat.md) for
what it does.

[Video](https://polina-c.github.io/a2ui-spikes-binaries/simple_chat/apps/flutter/a2ui_0_9_1_express/videos/chat.webm),
at phone size: the default prompt, three questions, two answered with the
buttons the model generated and one typed next to them, a pause to add context
and a resume, ending on a recommendation with a picture of the product and a
carousel of two dishwashers, each with a list of features and a Select button.
Each set of buttons shows once the model finishes writing it.

## Prompt

Can you generate simple_chat/apps/flutter/a2ui_0_9_1_express?

## How it differs from a2ui_0_9_1

1. The model writes each block in Express, between `<a2ui>` tags, as in
   `root = Button(Text("Under the counter"), _, Event("reply", {text: "..."}))`.
   The UI part of the prompt is about half as long as in direct JSON: 10,333
   characters instead of 20,108.
2. The agent SDK cannot read Express while it streams, so
   [answer_content.dart](lib/answer_content.dart) splits the output into text
   and blocks itself. The text shows as it arrives, and each block shows once
   its `</a2ui>` arrives, checked against the blocks before it. A surface does
   not fill in while its block is written.
3. Express compiles a function call inside a list item, such as
   `action: openUrl("...")` on a carousel card, into an action that does not
   validate. The rules in [generated_ui.dart](lib/generated_ui.dart) ask the
   model to write such an action as a map, which compiles. A button's
   `openUrl(...)` works as it is.
4. Express writes `"version": "v0.9"` on each message, which the v0.9.1
   renderer accepts.

The rest is as in a2ui_0_9_1: a button answers for the user with the `text` in
its action's context, and if a block cannot be read, the answer's UI stops at
that block, and the rest of the answer shows as text.

## Run it

```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

On macOS, `flutter run -d macos` also reads `GEMINI_API_KEY` from the
environment.

```bash
flutter test
```
