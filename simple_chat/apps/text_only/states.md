# Chat states

The chat is always in one of three states: idle, streaming, or paused. The
state decides which buttons sit next to the text field, is thinking box shown, are dots in it moving and what the hint in the
field says. The behavior behind each button is specified in
[blueprint.md](blueprint.md).

1. Idle (first launch or after answer): 
   - buttons: Send
   - hint: "Message"
   - thinking box: hidden 
2. Streaming (thinking box): 
   - buttons: Pause, Send
   - hint: "Add context, or pause"
   - thinking box: shown, dots are animated
3. Paused: 
   - buttons: Cancel, Resume or Send and resume
   - hint: "Add context and resume, just resume, or cancel".
   - thinking box: shown, dots are stopped

The button "Send" is disabled when the message text is whitespace only.

## What each button does

### Idle

1. Send: adds the message and starts an answer. Does nothing when the field is
   empty.

### Streaming

1. Pause: stops the answer. A partial answer is marked "Paused". A thinking box
   on screen stays, with its dots stopped.
2. Send: adds the message as context. The current answer keeps streaming, and
   when it finishes, the model writes a new answer that takes the message into
   account. Does nothing when the field is empty.

### Paused

1. Cancel: gives up on the answer. A partial answer stays, marked "Stopped",
   and the thinking box goes away.
2. Send with text: adds the message as context and starts a new answer.
3. Send with the field empty: resumes. The model continues the same answer, or
   writes a new one if context was added before the pause.

A failed answer is treated as paused, with the error shown under it, so Send
tries again and Cancel gives up.

## Transitions

1. Idle to streaming: Send.
2. Streaming to idle: the answer finishes, with no context added meanwhile.
3. Streaming to streaming: the answer finishes, and context was added
   meanwhile, so the next answer starts.
4. Streaming to paused: Pause, or the answer fails.
5. Paused to streaming: Send, with or without text.
6. Paused to idle: Cancel.

If `GEMINI_API_KEY` is not set, the app shows a message asking for it instead
of the chat, with no buttons.
