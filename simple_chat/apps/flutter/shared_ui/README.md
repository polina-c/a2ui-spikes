# shared_ui

Flutter UI components shared by the simple chat experiments, and the chat
logic behind them.

## Chat logic

- `joinContinuation`: appends a resumed answer to the text it continues.
- `loadGeminiApiKey`: reads `GEMINI_API_KEY` from `--dart-define`, or from the
  environment outside the browser.

## Components

- `AnimatedEllipsis`: dots that cycle from one to three, showing that more is
  still coming.
- `ThinkingBox`: a card that shows the tail of the agent's thinking as it
  streams in, driven by a `ThinkingBoxController`.
- `ChatInputPane`: the text field for the next message, with the buttons that
  send it and pause, resume or cancel the answer.
- `MessageBubble`: one message, as typed for the user and as Markdown for the
  model.
- `MdCarouselView`: a horizontally scrolling list of Markdown cards, each with
  a 'Select' button.
- `ChatLayout`: the frame of a chat page, with the messages pinned to the
  newest one and the input under them.
