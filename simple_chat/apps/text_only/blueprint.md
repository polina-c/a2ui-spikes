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

The system prompt is the content of [chat_blueprint.md](../../doc/chat_blueprint.md),
followed by the domain knowledge in
[knowledge.md](../../doc/domain/just_shining/knowledge.md) and the landing pages
in [landing_pages](../../doc/domain/just_shining/landing_pages/). These files are
bundled with the app as assets.

## Conversation

The app sends the whole conversation with every request and keeps it in memory
only. While it waits for the first part of an answer, it shows thinking with 
ThinkingBox from simple_chat/shared_ui.

## Interruption

While an answer is streaming, there are two buttons, pause and send, and the
hint in the text field says the user can add context or pause.

1. Add context without pausing: the user types a message and sends it. The
   message appears in the list, the current answer finishes, and then the
   model writes a new answer that takes the message into account.
2. Pause: the stream stops and the partial answer stays in the list marked as
   paused. If the thinking box is showing, it stays on screen with its
   thoughts, and its dots stop moving until the answer resumes.

While the answer is paused, there are two buttons, send and cancel, with some
space between them. The hint in the text field explains the three options:

1. Add context and resume: the user types a message and sends it. The model
   writes a new answer that takes the message into account.
2. Just resume: the user sends with the text field empty. The model continues
   the answer in the same message, or, if the user added context before
   pausing, writes a new answer that takes it into account.
3. Cancel: the partial answer stays in the list marked as stopped, and the
   chat waits for the user's next message.

When resuming, the app sends the whole conversation, including the partial
answer, and tells the model that the answer was paused.

If an answer fails, the chat shows the error and treats the answer as paused,
so the user can resume to try again, or cancel.

## Code quality

The code should be easy to read, nice and simple, because it will be used
as boilerplaite for enhancements.
