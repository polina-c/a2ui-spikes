# Text-only chat blueprint

## Overview

Build a Flutter app where the user chats with an assistant that answers in
text only, with no generated UI.

## Screen

The app has a single screen: a scrolling list of messages and a text field with
a send button below it. The text field starts filled with "Hi, I am looking for
a dishwasher. I am overwhelmed with choices and don't know where to start." so
the user can send it as is.

The model answers in Markdown, and the app renders it as formatted text:
headings, bold and italic text, lists, tables, code blocks, and links that
open in the browser. The user never sees raw Markdown syntax. An answer is
rendered while it streams, so an unfinished list or code block at the end of
a partial answer still looks right.

## Model

The assistant is a Gemini model, `gemini-flash-latest`. The app reads the API
key from the `GEMINI_API_KEY` environment variable, and streams each answer
into the message list as it arrives.

## Prompt

The system prompt is the content of
[0-chat-specifications.md](0-chat-specifications.md), followed by the domain
knowledge in [knowledge.md](../domain/just_shining/knowledge.md) and the
landing pages in [landing_pages](../domain/just_shining/landing_pages/). These
files are bundled with the app as assets.

## Conversation

The app sends the whole conversation with every request and keeps it in memory
only. While it waits for the first part of an answer, it shows thinking with
`ThinkingBox` from [shared_ui](../../apps/flutter/shared_ui).

## States

The chat is always in one of three states: idle, streaming, or paused. The
state decides which buttons sit next to the text field, what the hint in the
field says, and whether the thinking box and its dots show.

- **Idle**, at first launch or after an answer:
  - buttons: Send
  - hint: "Message"
  - thinking box: hidden
- **Streaming**:
  - buttons: Pause, Send
  - hint: "Add context, or pause"
  - thinking box: shown, with animated dots
- **Paused**:
  - buttons: Cancel, then Resume or "Send and resume", when there is prompt text
  - hint: "Add context and resume, just resume, or cancel"
  - thinking box: shown, without dots

The send button is disabled while the text field is empty or holds only
whitespace.

### Idle

1. Send: adds the message and starts an answer.

### Streaming

1. Send: adds the message as context. The message appears in the list, the
   current answer keeps streaming, and when it finishes, the model writes a
   new answer that takes the message into account.
2. Pause: stops the stream. A partial answer stays in the list, marked
   "Paused". If the thinking box is showing, it stays on screen with its
   thoughts, without its dots, until the answer resumes.

### Paused

1. Send and resume: adds the message as context, and the model writes a new
   answer that takes it into account.
2. Resume: the model continues the answer in the same message, or, if the
   user added context before pausing, writes a new answer that takes it into
   account.
3. Cancel: gives up on the answer. A partial answer stays in the list, marked
   "Stopped", the thinking box goes away, and the chat waits for the user's
   next message.

When resuming, the app sends the whole conversation, including the partial
answer, and tells the model that the answer was paused.

### Transitions

1. Idle to streaming: Send.
2. Streaming to idle: the answer finishes, with no context added meanwhile.
3. Streaming to streaming: the answer finishes, and context was added
   meanwhile, so the next answer starts.
4. Streaming to paused: Pause, or the answer fails.
5. Paused to streaming: Resume, or Send and resume.
6. Paused to idle: Cancel.

## Failures

1. If an answer fails, the chat shows the error under it and treats the
   answer as paused, so Resume tries again and Cancel gives up.
2. If `GEMINI_API_KEY` is not set, the app shows a message asking for it
   instead of the chat, with no buttons.

## Code quality

The code should be easy to read, nice and simple, because it will be used
as boilerplate for enhancements.
