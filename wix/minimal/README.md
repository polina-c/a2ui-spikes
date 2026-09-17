# Minimal Wix AI site

A Wix page with a chat widget, where the language model runs inside the
visitor's browser. There is no backend, no API key, and no per-message cost.

[WebLLM](https://github.com/mlc-ai/web-llm) loads a quantized open-weights model
into the browser and runs it on the GPU through WebGPU. The weights come from
the Hugging Face CDN on first use and stay in the browser cache afterwards, so
the only hosting Wix has to do is serve a static page. Nothing a visitor types
leaves their device.

The assistant answers from a file of facts about your business that ships with
the page, so it can answer "what do you sell?" and "are you open on Monday?"
without a server or a search API. Read the section on what it gets wrong before
putting it in front of customers.

## What's here

    content/knowledge.js                what the assistant knows about you; the file you edit
    public/custom-elements/ai-chat.js   the widget, and the only file with logic in it
    embed/chat.html                     generated page for the Embed HTML element (option A)
    embed/ai-chat.velo.js               generated file for the Velo custom element (option B)
    embed/_head.html, embed/_tail.html  the wrapper build.sh puts around the widget
    build.sh                            folds knowledge.js into both generated files
    local/index.html                    local preview, so you can test before touching Wix

The two files in `embed/` are generated. Edit `content/knowledge.js` or
`public/custom-elements/ai-chat.js` and run `./build.sh`.

## Try it locally first

    cd wix/minimal
    python3 -m http.server 8000

Then open http://localhost:8000/local/ and click "Start the chat". A `file://`
URL will not work, because the ES module import and the model cache both need a
real origin.

The local page uses `Llama-3.2-1B-Instruct-q4f16_1-MLC`, a 700 MB download, and
it is the same model `embed/chat.html` uses, so what you test is what visitors
get. Ask it about prices or opening hours: those answers come from
`content/knowledge.js`.

## Telling the assistant about your business

Edit `content/knowledge.js` and run `./build.sh`. It holds a list of entries
with a title and some text:

    window.AI_CHAT_KNOWLEDGE = [
      {
        title: "Opening hours",
        text: "The studio is open Tuesday to Saturday, 9am to 6pm.",
      },
    ];

Write plain sentences, the way you would answer a customer. Give each entry one
subject and a title that names it, because when there is more content than fits
in one request, the title is what gets matched against the question.

Entries that say what you do not do are worth as much as the ones that say what
you do. The model invents an answer when the content is silent, so "we do not
shoot weddings" and "we do not take phone bookings" stop questions before they
turn into guesses. The same goes for a contact entry: if people ask how to reach
you, put the real answer in the file.

Content under 6000 characters is sent with every question. Above that, the
widget sends the entries whose titles and text best match the question, which
was checked against 20,000 characters of content: it picked the parking entry
for a parking question and the refund entry for a refund question.

## Getting a Wix site open in the editor

Both options below start inside the Wix Editor, so you need an account and a
site first. If you already have one, open its dashboard and click Edit Site, or
Design Site if this is the first time you are opening that site. With more than
one site in the account, pick the one you want from the Site dropdown at the top
left of the dashboard before clicking through.

For a throwaway site to test this widget on, the shortest route is a blank
template:

1. Create a free account at https://www.wix.com.
2. Go to https://www.wix.com/website/templates and open Blank Templates.
3. Hover over a template and click Edit. That creates the site and opens it in
   the Wix Editor, skipping the guided AI setup flow.

Wix has two editors with different menus. The template route above gives you the
Wix Editor; Wix Studio is the separate editor aimed at agencies, and where its
menus differ the steps below give both. Nothing you do in either editor is
visible on the web until you click Publish, so you can paste the widget in and
try it in preview without touching a live page.

## Option A: paste it into an Embed HTML element

This works on a free Wix site and needs no Velo code. The widget runs in the
sandboxed iframe Wix uses for embedded code.

1. Edit `content/knowledge.js`, run `./build.sh`, and open `embed/chat.html`.
2. In the Wix Editor, click Add Elements, then Embed Code, then Popular Embeds,
   then Embed HTML.
3. Click Enter Code on the element and paste the entire contents of
   `embed/chat.html` into the code box.
4. Drag the element to the size you want. The widget fills whatever box you give
   it, and anything under about 320 px tall gets cramped.
5. Publish, then load the published page and click "Start the chat".

Wix only accepts HTTPS in embedded code, which the CDN URL in the widget already
uses.

Because the widget is inside a third-party iframe, the browser gives it a
partitioned cache. The model still caches, but under that partition, so a
visitor who also uses the widget elsewhere downloads the weights again.

## Option B: load it as a Velo custom element

This puts the widget directly in the page rather than in an iframe, which means
it shares the page's fonts and layout and can exchange data with Velo page code.

1. In the Wix Editor, click Dev Mode in the top bar, then Turn on Dev Mode.
2. Run `./build.sh`. In the code sidebar, create
   `public/custom-elements/ai-chat.js` and paste in the contents of
   `embed/ai-chat.velo.js`, which is the widget with your `knowledge.js`
   already folded in. The directory matters: Wix only lists files from
   `public/custom-elements`.
3. Add the element to the page. In the Wix Editor, click Add Elements, then
   Embed, then Popular Embeds, then Custom Element. In Wix Studio, click Add
   Elements, then Embed & Social, then Custom Element.
4. Click Choose Source, select Velo file, and pick `ai-chat.js` from the
   dropdown.
5. Set the Tag Name to `ai-chat`, which is the name passed to
   `customElements.define()` at the bottom of the file.
6. Optionally click Set Attributes to set `model`, `heading`, `greeting`, or
   `system-prompt`.
7. Preview the page. The element does not render in the editor canvas.

Two things to know before you commit to this path. Wix requires a Premium plan,
a connected domain, and ads removed before custom elements run on a live site,
so a free site can only preview it. And Wix renders custom elements in an iframe
in editor and preview mode but not on the live site, so the live page is the
only place the no-iframe behaviour is real.

Custom elements are invisible to crawlers that do not run JavaScript unless you
also set [`seoMarkup`](https://dev.wix.com/docs/velo/api-reference/$w/custom-element/seo-markup)
from page code.

## Which one to use

Start with option A. It works on a free site, the setup is one paste, and the
iframe keeps the widget's CSS away from the rest of the page. Move to option B
when you need the widget to sit in the page itself or to talk to Velo code, and
you already have a Premium site.

## Configuring the widget

The element takes four optional attributes:

    <ai-chat
      model="Llama-3.2-1B-Instruct-q4f16_1-MLC"
      heading="Ask me anything"
      greeting="Hi! I run entirely inside your browser."
      system-prompt="You are a helpful assistant on a website. Keep answers short."
    ></ai-chat>

`system-prompt` sets the assistant's manner. The facts it answers from live in
`content/knowledge.js`, not here.

`greeting` is shown without calling the model, so the page has something to say
before the weights finish loading. It is display copy only and is deliberately
kept out of the conversation the model sees, for the reason in the next section.

The model choice is the one decision that matters, because the visitor pays for
it in download size and in the GPU memory the model needs while running:

| Model id | Download | VRAM needed | Notes |
| --- | --- | --- | --- |
| `SmolLM2-360M-Instruct-q4f16_1-MLC` | 210 MB | 376 MB | too weak for open-ended chat |
| `Qwen2.5-0.5B-Instruct-q4f16_1-MLC` | 290 MB | 945 MB | invents contact details, see below |
| `Llama-3.2-1B-Instruct-q4f16_1-MLC` | 700 MB | 879 MB | the default, and the one to use |
| `Qwen2.5-1.5B-Instruct-q4f16_1-MLC` | 1.1 GB | 1630 MB | best answers, longest wait |

Download sizes are the sum of the files in the matching `mlc-ai` repository on
Hugging Face; VRAM figures are WebLLM's own `vram_required_MB`. Any id from
WebLLM's `prebuiltAppConfig.model_list` works; if you pick one that is not in
the table above, add it to `DOWNLOAD_MB` in the widget so the start panel can
still tell visitors what they are about to download.

Avoid `SmolLM2-360M` for a chat that takes arbitrary questions. In testing it
answered "give me compliment" and "give me link to wix home page" with the same
sentence, and no sampling setting rescued it. It is fine for a narrow, scripted
use, not for an open prompt box.

## Why the model is not allowed to repeat itself

Two things in the widget exist specifically to stop the loop where every answer
comes back as a variation of the same sentence.

The greeting is never added to the message list sent to the model. An assistant
turn that arrives before the user has said anything reads to a small model as
the pattern it should follow, and it will then answer every question with a
rewording of the greeting. With the greeting left in, Qwen2.5-0.5B answered the
same prompt twice with byte-identical text; with it removed, it did not.

Every request sends `frequency_penalty`, `presence_penalty` and
`repetition_penalty`, set in `GENERATION` near the top of the widget. Without
them, all three models tested returned character-for-character identical text
when the same question was asked twice in a row. These are the sampling
parameters WebLLM accepts on `chat.completions.create`.

The committed values (0.6, 0.6, 1.1 at temperature 0.7) are the mildest setting
that works. Two stronger settings were tried and both made answers worse:
Qwen2.5-0.5B moved from correctly answering `wix.com` to consistently answering
`wiz.com`, and Llama-3.2-1B started inventing URLs. Turning the penalties up is
not the lever it looks like.

One case survives all of this. Ask the exact same question twice and a small
model may give the exact same sentence back, because that is the answer it has.
That is different from the failure this section is about, which was every
question getting the same answer.

The widget also sends only the last twelve turns plus the system prompt
(`MAX_HISTORY`), because the supported models have a 4096 token context window
and a long conversation would otherwise overrun it.

## Limits worth knowing before you ship this

Visitors need WebGPU. Recent Chrome and Edge have it, and Safari has shipped it since Safari 26; older
browsers, and some mobile browsers, do not. The widget checks `navigator.gpu`
and says so instead of failing silently, but on those browsers there is no chat.

The first visit downloads hundreds of megabytes. The widget waits for a click
before starting that download and shows the size first, which is why there is a
start button rather than an automatic load.

## What it gets wrong

This is the part to read before pointing customers at it.

A model this small invents answers when your content does not cover the
question, and no wording of the instructions reliably stops it. Four system
prompts were tried, from mild to a flat order to refuse, against both models.
Every one of them fabricated something. Qwen2.5-0.5B invented a phone number
under all three prompts it was given, told a visitor the studio was open on
Monday when the content says it is closed, and confirmed it accepted Bitcoin.
Llama-3.2-1B invented a named head photographer. The strictest prompt cut the
inventions but started refusing questions the content does answer, and got the
closing days wrong, so it is not the setting shipped here.

Two things follow from that.

`Llama-3.2-1B` is the default in both the preview and `embed/chat.html`, and
`Qwen2.5-0.5B` is not a good choice for a public business page. On the same nine
questions Llama answered all five covered ones correctly and declined the phone
number; Qwen got two covered questions wrong and invented contact details.

Invented contact details are blocked outright rather than discouraged. A phone
number, email address or link in an answer that does not appear in
`content/knowledge.js` cannot have come from your content, so the widget
replaces the whole answer with a line pointing at the site's real contact
details. The check ignores prices, hours and street numbers. It is in
`inventedContactDetail`, covered by twelve cases, and it was watched catching a
real invented number in the browser.

Nothing similar can be done for an invented service or policy, because there is
no way to tell a made-up "we also do video" from a real one by looking at it.
The defence there is your content: say what you do not do, and say how to reach
you. The widget also tells visitors under the composer that answers can be
wrong.

## Verified

Answering from `content/knowledge.js` was checked end to end in the browser:
the five questions the sample content covers came back correct and specific,
including prices, closing days and the street address, and the retrieval picked
the right entry out of 20,000 characters of content when everything no longer
fit in one request. The contact-detail check passed twelve cases and was
observed replacing a phone number the model had made up.

The widget was driven end to end in headless Chrome from `local/index.html`,
over SwiftShader (CPU, no real GPU, so the speed below is a floor rather than
what a visitor sees). From an empty browser profile, `Qwen2.5-0.5B` downloaded
and loaded in 25 seconds and generated at 120 tokens/sec, and four questions
came back answered on topic with no two consecutive answers alike.

Model behaviour was compared across SmolLM2-360M, Qwen2.5-0.5B and Llama-3.2-1B
with and without the greeting in the history, and with and without the sampling
penalties, using the prompts that first showed the repetition.

The Wix editor steps above come from the Wix documentation linked below and have
not been run against a live Wix account.

* [Add a custom element](https://dev.wix.com/docs/velo/velo-only-apis/$w/custom-element/add-a-custom-element)
* [About custom elements](https://dev.wix.com/docs/velo/velo-only-apis/$w/custom-element/introduction), including the Premium plan requirement
* [Wix Editor: embedding a site or a widget](https://support.wix.com/en/article/wix-editor-embedding-a-site-or-a-widget)
* [Accessing your editor](https://support.wix.com/en/article/accessing-your-editor) and [building a site with a template](https://support.wix.com/en/article/wix-editor-building-a-site-with-a-template)
* [WebLLM](https://github.com/mlc-ai/web-llm)
