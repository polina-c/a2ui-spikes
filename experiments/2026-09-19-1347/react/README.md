# Simple chat, React

The [simple chat blueprint](../../../blueprints/simple_chat.md) built on the
official a2ui React renderer, `@a2ui/react`.

There is no backend. The browser calls Gemini (or a local WebLLM model)
directly, and the model replies with A2UI messages that `@a2ui/react` renders.

## Running it

```bash
npm install
npm run dev
```

Then open the address Vite prints. The app asks which model to use. If
`GEMINI_API_KEY` is not baked into the build it asks for a key, which stays in
the browser tab.

To bake a key in instead, build with `VITE_GEMINI_API_KEY` set. Do not commit
the result; the key ends up in the bundle.

## Driving the CUJ

`cuj.mjs` runs the primary CUJ against a built copy and records it.

```bash
npm run build
npx vite preview --port 4173 &
node cuj.mjs http://localhost:4173/ ../videos react
```

It reads the Gemini key from `GEMINI_API_KEY`, types it into the app the way a
user would, and picks the answers that match Jane's profile by reading the
buttons on screen. It writes `react.webm`, a screenshot of the landing page, and
a log of every option it saw.

## How it is put together

`src/models.ts` is the list of families, models and parameter ranges shown on
the opening screen. `src/domain.ts` embeds the knowledge base and the six
landing pages with Vite `?raw` imports. `src/prompt.ts` builds the system
prompt: the component schemas in it come from `getClientCapabilities`, so they
stay in step with the catalog rather than being copied by hand.

`src/llm/` holds the two model clients behind one interface. `src/components/`
holds the picker and the chat. The chat owns the `MessageProcessor`, gives each
assistant turn its own surface, and handles actions: a press on a generated
button is fed back to the model as a turn, except for `openLandingPage`, which
the app handles itself by opening the URL.

## Things worth knowing

The catalog has no link component and `Text` does not render markdown links, so
the landing page link is a `Button` with an `openLandingPage` action that the
app turns into `window.open`. Without that the CUJ cannot finish.

`Text` renders markdown only when a renderer is supplied through
`MarkdownContext`. `@a2ui/markdown-it` is already a dependency of `@a2ui/react`,
but nothing is wired up by default.

`@a2ui/react` advertises `./styles/structural.css` in its export map and does
not ship the file. The CSS it does ship, `v0_9/index.css`, is not exported.
`injectStyles()` from `@a2ui/react/styles` is the path that works.
