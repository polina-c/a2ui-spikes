# shared_ui

React components shared by the simple chat experiments, and the chat logic
behind them. Each one matches its namesake in the Flutter
[shared_ui](../../dart/shared_ui).

## Chat logic

1. [joinContinuation](src/join_continuation.ts): appends a resumed answer to
   the text it continues.
2. [loadGeminiApiKey](src/gemini_api_key.ts): reads `GEMINI_API_KEY`, which
   Vite builds into the app when the app's config lists it in `envPrefix`.
3. [ChangeNotifier and useListenable](src/change_notifier.ts): a class that
   tells listeners when it changes, and a hook that renders a component again
   when it does, like Flutter's `ChangeNotifier` and `ListenableBuilder`.

## Components

1. [AnimatedEllipsis](src/animated_ellipsis.tsx): dots that cycle from one to
   three, showing that more is still coming.
2. [ThinkingBox](src/thinking_box.tsx): a card that shows the tail of the
   agent's thinking as it streams in, driven by a `ThinkingBoxController`.
3. [ChatInputPane](src/chat_input_pane.tsx): the text field for the next
   message, with the buttons that send it and pause, resume or cancel the
   answer.
4. [MessageBubble](src/message_bubble.tsx): one message, as typed for the user
   and as Markdown for the model.
5. [MdCarouselView](src/md_carousel_view.tsx): a horizontally scrolling list of
   Markdown cards, each with a 'Select' button.
6. [ChatLayout](src/chat_layout.tsx): the frame of a chat page, with the
   messages pinned to the newest one and the input under them.
7. [Markdown](src/markdown.tsx): the Markdown rendering the components share,
   with links that open in a new tab.

## Use it

The package is TypeScript source with no build step, and the app's Vite
compiles it. Import the components from `shared_ui`, and the colors once, in
the app:

```ts
import 'shared_ui/theme.css';
```

[theme.css](src/theme.css) holds the Material 3 colors that Flutter derives
from `Colors.teal`, so the components look like their Flutter counterparts.

Run the tests from this folder with `npm test`.
