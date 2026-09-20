# Simple chat blueprint

[a2ui]: https://github.com/a2ui-project/a2ui
[domain]: ../domain/knowledge.md
[web-llm]: https://github.com/mlc-ai/web-llm

## Overview

A chat where the assistant answers with generated UI, not only with words. 

It uses [a2ui protocol and SDK][a2ui] to enable generated UI.

This blueprint is very simple, because it assumes all needed technical knowledge is provided by the [a2ui] documentation.

## Domain knowledge

The application uses knowledge from [domain].

## Technical requirements

- Domain knowledge can be either embedded into application statically or read via HTTP dynamically, depending on technical capabilities and limitations.
- The application may use code or knowledge from [web-llm] when needed.
- While building the application, you can use env variable GEMINI_API_KEY to run experiments. The final application also takes Gemini API key from environment or, if not provided, from user input.
- Application should use 'gemini-flash-latest'.

## CUJ

### User profile

Jane want to choose a dishwasher. She is overwhelmed with choices and doesn't know where to start. She wants the application to guide her. She has subscription to Gemini and she is happy to provide API key to the app if it will help. However she does not always have it nearby and in this case she wants to use local model.

### Steps

1. Jane opens an app. 
2. The app asks her to choose model, providing good defaults.
3. She either accepts the defaults and continues or picks a different model and parameters. 
4. Application invites her to a chat with a default prompt: "Hi, I am looking for a dishwasher. I am overwhelmed with choices and don't know where to start."
5. Jane accepts the default prompt and continues.
6. Assistant chats with Jane, preferably using generated UI to present her with options. In this conversation the assistant uses the provided prompt and domain knowledge to answer, guiding the user to choose a product and inviting to clink link for the landing page of the selected product.
7. Jane clicks the link and is taken to the product page, where she can buy the product.
