# Minimal WordPress AI site

A WordPress site whose front page is a chat with an AI, built from
[AI Engine](https://wordpress.org/plugins/ai-engine/).

There is no server to install. WordPress runs as WebAssembly under
[WordPress Playground](https://wordpress.github.io/wordpress-playground/), with PHP
compiled to WASM and SQLite standing in for MySQL, so the only prerequisite is Node.
The site is rebuilt from `blueprint.json` on every boot and thrown away when you stop
it; nothing is installed on your machine and nothing persists between runs.

## Requirements

* Node 20 or newer (tested on Node 25).
* An API key for an AI provider, or a local model. See below.

You do not need PHP, Docker, MySQL, or a WordPress install.

## Run it

```sh
cd worldpress/minimal
cp .env.example .env    # then put your API key in it
npm start
```

Open http://127.0.0.1:9400. The front page is the chat.

The first run downloads WordPress and the AI Engine plugin, which takes a minute or
two; later runs boot in a few seconds from cache. You arrive already signed in as an
administrator, so wp-admin is at http://127.0.0.1:9400/wp-admin/ (`admin` / `password`
if you are ever asked). AI Engine's own settings are under Meow Apps > AI Engine.

To use a different port, pass CLI flags through npm:

```sh
npm start -- --port 9500
```

## Choosing a provider

`npm start` reads `.env` (and the shell, which wins over the file) and passes the
values to PHP as constants. They are never written to the database or to any file in
this directory, so a key cannot leak into a commit, and a restart with a different key
needs no cleanup. `.env` is gitignored.

For a hosted provider, name the provider and give it a key:

```sh
A2UI_AI_TYPE=openai
A2UI_AI_API_KEY=sk-...
```

`A2UI_AI_TYPE` accepts any environment type AI Engine knows: `openai`, `anthropic`,
`google`, `openrouter`, `mistral`, `perplexity`, `xai`, `azure`, or `custom`. Leave
`A2UI_AI_MODEL` unset to take AI Engine's default model, or set it to any model AI
Engine lists for that provider.

For a local model instead, point `custom` at anything that speaks the OpenAI API
(Ollama, LM Studio, llama.cpp, vLLM) and name the model yourself:

```sh
A2UI_AI_TYPE=custom
A2UI_AI_ENDPOINT=http://127.0.0.1:11434/v1
A2UI_AI_MODEL=llama3.2
```

The model has to be named here because AI Engine will not run a model it has no
record of, and a custom endpoint has no model list until someone asks the server for
one. Most local servers want no key at all, so `A2UI_AI_API_KEY` can stay unset.

You can also skip `.env` and paste a key into Meow Apps > AI Engine > Settings after
the site is up. That works, but only until you stop the server, because the database
goes with it.

If no provider is configured the site still boots and the chat still renders; it says
so on the page and in wp-admin rather than failing once you send a message.

## What the blueprint does

`blueprint.json` is a Playground blueprint, the declarative format Playground uses to
describe a site. This one sets the site title, installs AI Engine from the plugin
directory, installs `a2ui-minimal-chat.php`, and logs you in.

`a2ui-minimal-chat.php` is a single-file WordPress plugin doing the two things a
blueprint cannot:

* It publishes a page holding the `[mwai_chatbot]` shortcode and makes it the front
  page.
* It reads the provider constants as AI Engine reads its own settings, and fills in
  the API key, the endpoint, the model, and the environment the chatbot answers from.

That last piece is what makes the chat work without a visit to wp-admin. AI Engine
creates a default chatbot on demand but leaves its environment field empty, since that
field is normally filled in by hand on the settings screen, and an empty one turns
every message into "The environment is required."

## Files

```
blueprint.json           Playground blueprint: the site, declaratively
a2ui-minimal-chat.php    Single-file plugin: the chat page, and the provider wiring
start.mjs                Collects credentials from .env or the shell, starts Playground
.env.example             Copy to .env
```

`start.mjs` only exists to keep credentials out of `blueprint.json`. Everything else it
does is flags you could type yourself:

```sh
npx @wp-playground/cli@3.1.54 server \
  --blueprint=blueprint.json \
  --blueprint-may-read-adjacent-files \
  --login \
  --define A2UI_AI_API_KEY sk-...
```
