# React arm

The simple chat app on [`@a2ui/react`](https://www.npmjs.com/package/@a2ui/react)
0.11.1 with `@a2ui/web_core` 0.11.0, the only official renderer of the three
frameworks in this experiment.

## Run it

```bash
npm install
npm run dev        # http://localhost:5173
```

Or serve the production build, which is what the recorded CUJ ran against:

```bash
npm run build
npm run preview    # http://localhost:4173
```

The app asks for a Gemini API key on the first screen and keeps it in the tab.
A key can also be supplied at build time as `VITE_GEMINI_API_KEY`, but the
recorded run left that unset, so no key is baked into the bundle.

Tests:

```bash
npm test
```

## Layout

* `src/picker.tsx` - the model picker the app opens on
* `src/chat.tsx` - the conversation, the `MessageProcessor` and the `A2uiSurface`
* `src/prompt.ts` - the hand-written system prompt, with the catalog schema
  pulled in at runtime from `getClientCapabilities`
* `src/gemini.ts`, `src/local.ts` - the two model families
* `src/knowledge.ts` - the knowledge base, embedded with Vite's `?raw`
* `src/styles.css` - the app's chrome, and the handful of `--a2ui-*` tokens it
  overrides; the basic catalog ships its own defaults, so generated UI is
  styled without the host doing anything
* `src/__tests__/` - the prompt, the reply parsing and the embedded knowledge
