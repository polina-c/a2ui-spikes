# Simple chat blueprint

A chat where the assistant answers with generated UI, not only with words. 

It uses [a2ui protocol and SDK][a2ui] to enable generated UI.

This blueprint is very simple, because it assumes all needed technical knowledge is provided by the [a2ui] documentation.

## Domain knowledge



## Technical requirements





## Models used

In the very beginning the app invites the user to choose a model:

- Llama-3.2-3B-Instruct-q4f32_1-MLC, with configurable context window, for local execution.
- Gemini 2.5 flash (user provides API key and chooses context window size).

The UI specifies allowed range for each configuration value.
The entered API key is hidden behind dots in UI.

[a2ui]: https://github.com/a2ui-project/a2ui




## CUJ

