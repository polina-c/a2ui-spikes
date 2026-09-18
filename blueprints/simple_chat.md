# Simple chat blueprint


A chat where the assistant answers with generated UI, not only with words. 

It uses [a2ui protocol](https://github.com/a2ui-project/a2ui).

## Models used

In the very beginning the app invites the user to choose a model:

- Llama-3.2-3B-Instruct-q4f32_1-MLC, with configurable context window, for local execution.
- Gemini 2.5 flash (user provides API key and chooses context window size).

The UI specifies max for each configuration value.


