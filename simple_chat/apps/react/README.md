# React apps

React versions of the [Dart apps](../dart), in one npm workspace:

1. [shared_ui](shared_ui): components and chat logic the apps share.
2. [text_only](text_only): the chat that answers in text only.

Run these from this folder:

```bash
npm install         # once, for every package
npm test            # every package
npm run typecheck   # every package
npm run lint
npm run format
```
