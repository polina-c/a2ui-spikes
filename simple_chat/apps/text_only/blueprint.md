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

While an answer is streaming, the send button turns into a pause button.
Pausing stops the stream, keeps the partial answer in the list marked as
paused, and shows a resume button. While the answer is paused, the user can
send messages to add context. These messages appear in the list but do not
start a new answer. Resuming sends the conversation, including the partial
answer and any added messages, and asks the model to continue. If the user
added nothing, the answer continues in the same message. If the user added
context, the model writes a new answer that takes it into account. Sending a
message while the answer is streaming, without pausing first, is not possible.

## Code quality

The code should be easy to read, nice and simple, because it will be used
as boilerplaite for enhancements.
