# React apps

React versions of the [Dart apps](../dart), in one npm workspace:

1. [shared_ui](shared_ui): components and chat logic the apps share.
2. [text_only](text_only): the chat that answers in text only.
3. [a2ui_0_9_1](a2ui_0_9_1): the chat with UI that the model generates
   through A2UI v0.9.1.
4. [a2ui_1_0](a2ui_1_0): the same chat through A2UI v1.0, with the features
   it adds.

Run these from this folder:

```bash
npm install         # once, for every package
npm test            # every package
npm run typecheck   # every package
npm run lint
npm run format
```
