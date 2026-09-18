# Wix AI site, in Jaspr

The same site as [`wix/minimal`](../minimal/README.md): a Wix page with a chat
widget, where the language model runs inside the visitor's browser. There is no
backend, no API key, and no per-message cost. The difference is that this one is
written in Dart with [Jaspr](https://jaspr.site) and compiled to a static page,
rather than hand-written as a JavaScript custom element.

[WebLLM](https://github.com/mlc-ai/web-llm) loads a quantized open-weights model
into the browser and runs it on the GPU through WebGPU. The weights come from
the Hugging Face CDN on first use and stay in the browser cache afterwards, so
the only hosting Wix has to do is serve a static page. Nothing a visitor types
leaves their device.

The assistant answers from a file of facts about your business that ships with
the page, so it can answer "what do you sell?" and "are you open on Monday?"
without a server or a search API. Read [what it gets wrong](#what-it-gets-wrong)
before putting it in front of customers.

## What Jaspr changes

The answers are the same and the model is the same. What moves is where the
logic lives.

The rules that decide what the model is told and what the visitor is shown are
ordinary Dart in [lib/grounding.dart](lib/grounding.dart), with no browser in
them, so `dart test` checks them in under a second: the contact-detail guard,
which entry gets sent when the content outgrows one request, and the ordering
around both. Twenty-one tests, listed under [Verified](#verified). The vanilla
widget states the same rules in prose and has nothing that runs them, which is
how a phone number it should have caught stayed uncaught; see
[Verified](#verified).

Inference is [`package:genui`](../../jaspr/genui)'s `WebLlmClient`, the same
client [`jaspr/simple_chat`](../../jaspr/simple_chat) uses, rather than a second
copy of the WebLLM plumbing. What the two apps ask it for is where they differ:
this one asks for prose, and Simple Chat asks for generated UI.

What it costs is page weight. The file you paste into Wix is 23 KB for the
vanilla widget and 190 KB here, most of the difference being the Jaspr runtime.
On a page that then fetches 700 MB of model weights, that is not the number
that decides anything.

## What's here

    lib/knowledge.dart          what the assistant knows about you; the file you edit
    lib/config.dart             model, heading, greeting, system prompt
    lib/grounding.dart          what gets sent, and what gets withheld; all of it tested
    lib/chat_session.dart       loading the model, the transcript, and the history
    lib/app.dart                the widget: header, transcript, start button or composer
    lib/components/             the transcript and composer, and the start gate
    web/index.html              the page
    web/styles.css              the chat's styles
    web/web_llm.js              the WebLLM module, copied from package:genui
    test/grounding_test.dart    the rules above, checked without a browser
    build.sh                    compiles, then folds the output into embed/
    embed/chat.html             generated: one file for the Embed HTML element
    embed/site/                 generated: four files for any static host

Everything under `embed/` is generated. Edit the Dart and run `./build.sh`.

`web/web_llm.js` is a copy of `genui/lib/assets/web_llm.js`, the JavaScript half
of that package's WebLLM support, which the page has to load for the Dart half
to find anything. Copy it again when the package's version changes.

## Requirements

* The Dart SDK, 3.10 or newer.
* The Jaspr CLI: `dart pub global activate jaspr_cli`.
* A browser with WebGPU, to see it run. Recent Chrome and Edge have it, and
  Safari has shipped it since Safari 26.

## Try it locally first

```sh
cd wix/jaspr
dart pub get
jaspr serve
```

Open http://localhost:8080 and click "Start the chat".

If that stops with `Address already in use`, something else is on 8080, quite
possibly [`jaspr/simple_chat`](../../jaspr/simple_chat), which serves there too.
Look at what is holding it (`lsof -i :8080`) before killing anything, or leave
it alone and use `jaspr serve --port 8081`.

The local page uses the same model and the same content as the page you paste
into Wix, so what you test is what visitors get. Ask it about prices or opening
hours: those answers come from `lib/knowledge.dart`.

To check the rules without loading a model at all:

```sh
dart test
```

## Telling the assistant about your business

Edit [lib/knowledge.dart](lib/knowledge.dart) and run `./build.sh`. It holds a
list of entries with a title and some text:

```dart
const List<KnowledgeEntry> knowledge = <KnowledgeEntry>[
  KnowledgeEntry(
    title: 'Opening hours',
    text: 'The studio is open Tuesday to Saturday, 9am to 6pm.',
  ),
];
```

Write plain sentences, the way you would answer a customer. Give each entry one
subject and a title that names it, because when there is more content than fits
in one request, the title is what gets matched against the question.

Entries that say what you do not do are worth as much as the ones that say what
you do. The model invents an answer when the content is silent, so "we do not
shoot weddings" and "we do not take phone bookings" stop questions before they
turn into guesses. The same goes for a contact entry: if people ask how to reach
you, put the real answer in the file.

Content under 6000 characters is sent with every question. Above that, the chat
sends the entries whose titles and text best match the question.

## Getting a Wix site open in the editor

Both options below start inside the Wix Editor, so you need an account and a
site first. If you already have one, open its dashboard and click Edit Site, or
Design Site if this is the first time you are opening that site.

For a throwaway site to test this on, the shortest route is a blank template:

1. Create a free account at https://www.wix.com.
2. Go to https://www.wix.com/website/templates and open Blank Templates.
3. Hover over a template and click Edit. That creates the site and opens it in
   the Wix Editor, skipping the guided AI setup flow.

Wix has two editors with different menus. The template route above gives you
the Wix Editor; Wix Studio is the separate editor aimed at agencies, and where
the menus differ the steps below give both.

Nothing you do in either editor is visible on the web until you click Publish,
so you can paste the chat in and try it in preview without touching a live
page.

## Option A: paste the built page into an Embed HTML element

This works on a free Wix site and needs no Velo code. Everything the chat needs
is in one file, which runs in the sandboxed iframe Wix uses for embedded code.

1. Edit `lib/knowledge.dart`, run `./build.sh`, and open `embed/chat.html`.
2. In the Wix Editor, click Add Elements, then Embed Code, then Popular Embeds,
   then Embed HTML. In Wix Studio, click Add Elements, then Embed & Social,
   then Embed Code.
3. Click Enter Code on the element, paste the entire contents of
   `embed/chat.html` into the box, and click Apply. The file is about 190 KB;
   [Wix documents no character limit](https://support.wix.com/en/article/wix-editor-embedding-a-site-or-a-widget)
   on this element.
4. Drag the element to the size you want. The chat fills whatever box you give
   it, and anything under about 320 px tall gets cramped.
5. Publish, then load the published page and click "Start the chat".

Wix only accepts HTTPS in embedded code, which the CDN URL in `web_llm.js`
already uses.

Because the chat is inside a third-party iframe, the browser gives it a
partitioned cache. The model still caches, but under that partition, so a
visitor who also uses the same model elsewhere downloads the weights again.

## Option B: host the four files and embed them by URL

`embed/site/` is `index.html`, `styles.css`, `web_llm.js` and
`main.client.dart.js`, which is the whole site. Put it on any static host that
serves HTTPS (GitHub Pages, Netlify, Cloudflare Pages, or your own), then add
the element: in the Wix Editor, Add Elements, then Embed Code, then Embed a
Site; in Wix Studio, Add Elements, then Embed & Social, then Embed Site. Click
Change Website Address and give it the URL, which has to start with `https`.

It has to be a server rather than a folder: `file://` will not work, because the
page loads WebLLM as a module.

This is worth the extra host when you want to update the chat without editing
the Wix page, or when you want the model cached under your own origin rather
than under Wix's iframe partition. Option A is otherwise simpler.

## Why there is no Velo custom element here

The vanilla widget can also be loaded as a Velo custom element, which puts it in
the page itself rather than in an iframe. That path does not carry over as it
is, for two reasons that are worth knowing before you go looking for it.

A compiled Jaspr app is a script that mounts itself into the page, and nothing
in it calls `customElements.define`, so there is no element for Wix to put on
the page. Jaspr can mount somewhere other than `body` (`runApp` takes an
`attachTo` selector), so a wrapper that defines the element and lets the
compiled app attach to it is possible, but it is code that does not exist
here.

And `web/web_llm.js` reaches WebLLM with a static `import` from a CDN, which
Velo's bundler would try to resolve at build time. The vanilla widget avoids
this by importing WebLLM dynamically, at the moment the visitor clicks start.

Wix also requires a Premium plan, a connected domain, and ads removed before
custom elements run on a live site, so a free site can only ever preview one.

## Configuring the chat

[lib/config.dart](lib/config.dart) holds everything that is not a fact about
your business: the model, the header, the greeting, and the system prompt.

`systemPrompt` sets the assistant's manner. The facts it answers from live in
`lib/knowledge.dart`, not here.

`greeting` is shown without calling the model, so the page has something to say
before the weights finish loading. It is display copy only and is deliberately
kept out of the conversation the model sees, for the reason in the next section.

The model choice is the one decision that matters, because the visitor pays for
it in download size and in the GPU memory the model needs while running:

| Model id | Download | VRAM needed | Notes |
| --- | --- | --- | --- |
| `SmolLM2-360M-Instruct-q4f16_1-MLC` | 210 MB | 376 MB | too weak for open-ended chat |
| `Qwen2.5-0.5B-Instruct-q4f16_1-MLC` | 290 MB | 945 MB | invents contact details |
| `Llama-3.2-1B-Instruct-q4f16_1-MLC` | 700 MB | 879 MB | the default, and the one to use |
| `Qwen2.5-1.5B-Instruct-q4f16_1-MLC` | 1.1 GB | 1630 MB | best answers, longest wait |

Download sizes are the sum of the files in the matching `mlc-ai` repository on
Hugging Face; VRAM figures are WebLLM's own `vram_required_MB`. These are the
same models and the same measurements as the vanilla widget, which is where the
notes come from. Any id in `WebLlmClient.models()` works; if you pick one that
is not in the table, add it to `downloadMb` in `lib/config.dart` so the start
panel can still tell visitors what they are about to download.

## Why the model is not allowed to repeat itself

Two things exist specifically to stop the loop where every answer comes back as
a variation of the same sentence.

The greeting is never added to the history sent to the model. An assistant turn
that arrives before the user has said anything reads to a small model as the
pattern it should follow, and it will then answer every question with a
rewording of the greeting. With the greeting left in, Qwen2.5-0.5B answered the
same prompt twice with byte-identical text; with it removed, it did not.

Every request sends `frequency_penalty`, `presence_penalty` and
`repetition_penalty`, set in `chatSampling` in
[lib/chat_session.dart](lib/chat_session.dart). Without them, all three models
tested returned character-for-character identical text when the same question
was asked twice in a row.

The committed values (0.6, 0.6, 1.1 at temperature 0.7) are the mildest setting
that works. Two stronger settings were tried and both made answers worse:
Qwen2.5-0.5B moved from correctly answering `wix.com` to consistently answering
`wiz.com`, and Llama-3.2-1B started inventing URLs. Turning the penalties up is
not the lever it looks like.

Passing these at all is a small addition to `package:genui`, which until now
sent one temperature suited to generating A2UI JSON. `WebLlmClient` takes a
`Sampling` now, and sends WebLLM's defaults when it is left out, which is what
`jaspr/simple_chat` does.

One case survives all of this. Ask the exact same question twice and a small
model may give the exact same sentence back, because that is the answer it has.
That is different from the failure this section is about, which was every
question getting the same answer.

The chat also sends only the last twelve turns plus the system message
(`maxHistory` in [lib/grounding.dart](lib/grounding.dart)), because the
supported models have a 4096 token context window and a long conversation would
otherwise overrun it.

## What it gets wrong

This is the part to read before pointing customers at it.

A model this small invents answers when your content does not cover the
question, and no wording of the instructions reliably stops it. Four system
prompts were tried against the vanilla widget, from mild to a flat order to
refuse, and every one of them fabricated something. Qwen2.5-0.5B invented a
phone number under all three prompts it was given, told a visitor the studio was
open on Monday when the content says it is closed, and confirmed it accepted
Bitcoin. Llama-3.2-1B invented a named head photographer. The strictest prompt
cut the inventions but started refusing questions the content does answer.

Two things follow from that.

`Llama-3.2-1B` is the default, and `Qwen2.5-0.5B` is not a good choice for a
public business page. On the same nine questions Llama answered all five covered
ones correctly and declined the phone number; Qwen got two covered questions
wrong and invented contact details.

Invented contact details are blocked outright rather than discouraged. A phone
number of seven digits or more, an email address or a link in an answer that
does not appear in `lib/knowledge.dart` cannot have come from your content, so
the chat replaces the whole answer with a line pointing at the site's real
contact details. The check ignores prices, hours and street numbers. It is
`inventedContactDetail` in [lib/grounding.dart](lib/grounding.dart), and fifteen
of the twenty-one tests are about it.

Nothing similar can be done for an invented service or policy, because there is
no way to tell a made-up "we also do video" from a real one by looking at it.
The defence there is your content: say what you do not do, and say how to reach
you. The chat also tells visitors under the composer that answers can be wrong.

## Limits worth knowing before you ship this

Visitors need WebGPU. Recent Chrome and Edge have it, and Safari has shipped it
since Safari 26; older browsers, and some mobile browsers, do not. The page
checks for a WebGPU adapter before offering the button and says so instead of
failing silently, but on those browsers there is no chat.

The first visit downloads hundreds of megabytes. Nothing is downloaded until the
visitor clicks, and the size is on the button's panel before they do.

## Verified

The rules in `lib/grounding.dart` are covered by 21 tests, which run in under a
second with `dart test`: the contact-detail guard, the content selection that
picks entries when the site outgrows one request, and the ordering of what it
picks.

`embed/chat.html` was then driven end to end in headless Chrome, over
SwiftShader (CPU, so the speed below is a floor rather than what a visitor with
a GPU sees), served over http from the generated file rather than from the dev
server. Both models below downloaded, compiled and answered from the sample
content in `lib/knowledge.dart`.

`Llama-3.2-1B`, the default, loaded in 11 seconds on a fast connection and
answered from the content: opening hours, the price of a headshot session,
weddings, and parking. Asked for a phone number the content does not have, it
said so, once going on to give the email address that is in the content, which
the guard correctly left alone.

It is not steady. Over two runs of the same six questions, one asking of
opening hours came back as "I am not a part of Northwind Studio's business",
a refusal to answer something the content answers plainly. The same question
asked again in the same conversation was answered correctly. That is the model,
not the content, and it is the ceiling a 1B model sets.

`Qwen2.5-0.5B` answered the same covered questions correctly but got opening
hours wrong on a second asking, twice over two runs, once saying Sunday through
Monday and once Monday through Friday when the content says Tuesday to
Saturday. Asked for a phone number, it answered "Your phone number is 5364217".
That is the vanilla widget's finding about this model, reproduced here, and the
reason the default is Llama.

That invented number also found a gap. The vanilla widget's phone pattern needs
eight characters to match, so a bare seven-digit number went straight through
the guard and was shown to the browser. The pattern here matches seven, the
answer that got through is now one of the tests, and on the next run the same
question came back as the withheld line instead.

Both ends of the WebGPU check were watched: started with `--disable-gpu`, the
page explains that there is no GPU to run on and offers no button; with an
adapter, it offers the download and names its size, 700 MB for Llama and 290 MB
for Qwen, from `downloadMb` in `lib/config.dart`.

`jaspr serve` and `jaspr build` were both run against this project on Dart
3.13.2 and Jaspr 0.23.

Adding `Sampling` to `package:genui` left its own 75 tests passing and
`jaspr/simple_chat` analyzing clean; that app passes no sampling and so gets
exactly what it got before.

The Wix editor steps above come from the Wix documentation linked below and
have not been run against a live Wix account.

* [Wix Editor: embedding a site or a widget](https://support.wix.com/en/article/wix-editor-embedding-a-site-or-a-widget), including that there is no character limit on the element
* [Studio Editor: adding an HTML iFrame element](https://support.wix.com/en/article/studio-editor-adding-an-html-iframe-element)
* [Accessing your editor](https://support.wix.com/en/article/accessing-your-editor) and [building a site with a template](https://support.wix.com/en/article/wix-editor-building-a-site-with-a-template)
* [About custom elements](https://dev.wix.com/docs/velo/velo-only-apis/$w/custom-element/introduction), including the Premium plan requirement
* [WebLLM](https://github.com/mlc-ai/web-llm), [Jaspr](https://jaspr.site)
