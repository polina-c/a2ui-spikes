# A2UI in Jaspr

## genui in Jaspr

jaspr/genui contains [genui](https://github.com/flutter/genui/tree/main/packages/genui) ported from Flutter to Dart/Jaspr, that uses WebLLM.

## Simple chat in Jaspr

jaspr/simple_chat contains [Simple Chat](https://github.com/flutter/genui/tree/main/examples/simple_chat) sample implemented in Jaspr that uses jaspr/genui.

Before the model loads, the first screen chooses its context window: the model's
own setting, a fixed size, or a sliding window with a chosen number of tokens
pinned at the start. WebLLM fixes the window when it builds the engine, and the
4096 tokens most models default to leave little room beyond the system prompt,
which is what `ContextWindowSizeExceededError` means when it arrives a few turns
in.

jaspr/simple_chat/README.md contains steps to run it locally.
