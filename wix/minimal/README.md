# Minimal Wix AI site

A Wix page with a chat widget, where the language model runs inside the
visitor's browser. There is no backend, no API key, and no per-message cost.

[WebLLM](https://github.com/mlc-ai/web-llm) loads a quantized open-weights model
into the browser and runs it on the GPU through WebGPU. The weights come from
the Hugging Face CDN on first use and stay in the browser cache afterwards, so
the only hosting Wix has to do is serve a static page. Nothing a visitor types
leaves their device.

## What's here

    public/custom-elements/ai-chat.js   the widget, and the only file with logic in it
    embed/chat.html                     generated standalone page for the Embed HTML element
    embed/_head.html, embed/_tail.html  the wrapper build.sh puts around the widget
    build.sh                            regenerates embed/chat.html from the widget
    local/index.html                    local preview, so you can test before touching Wix

Everything else is generated. Edit `public/custom-elements/ai-chat.js` and run
`./build.sh`.

## Try it locally first

    cd wix/minimal
    python3 -m http.server 8000

Then open http://localhost:8000/local/ and click "Start the chat". A `file://`
URL will not work, because the ES module import and the model cache both need a
real origin.

The local page uses `SmolLM2-360M-Instruct-q4f16_1-MLC`, a 210 MB download, so
the first run finishes in well under a minute on a normal connection.

## Option A: paste it into an Embed HTML element

This works on a free Wix site and needs no Velo code. The widget runs in the
sandboxed iframe Wix uses for embedded code.

1. Run `./build.sh` and open `embed/chat.html`.
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
2. In the code sidebar, create `public/custom-elements/ai-chat.js` and paste in
   this repository's copy of that file. The directory matters: Wix only lists
   files from `public/custom-elements`.
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

`greeting` is shown without calling the model, so the page has something to say
before the weights finish loading.

The model choice is the one decision that matters, because the visitor pays for
it in download size and in the GPU memory the model needs while running:

| Model id | Download | VRAM needed |
| --- | --- | --- |
| `SmolLM2-360M-Instruct-q4f16_1-MLC` | 210 MB | 376 MB |
| `Qwen2.5-0.5B-Instruct-q4f16_1-MLC` | 290 MB | 945 MB |
| `Llama-3.2-1B-Instruct-q4f16_1-MLC` | 700 MB | 879 MB |
| `Qwen2.5-1.5B-Instruct-q4f16_1-MLC` | 1.1 GB | 1630 MB |

Download sizes are the sum of the files in the matching `mlc-ai` repository on
Hugging Face; VRAM figures are WebLLM's own `vram_required_MB`. `Llama-3.2-1B`
is the default in `embed/chat.html` and is a reasonable balance. Any id from
WebLLM's `prebuiltAppConfig.model_list` works; if you pick one that is not in
the table above, add it to `DOWNLOAD_MB` in the widget so the start panel can
still tell visitors what they are about to download.

## Limits worth knowing before you ship this

Visitors need WebGPU. Recent Chrome and Edge have it, and Safari has shipped it since Safari 26; older
browsers, and some mobile browsers, do not. The widget checks `navigator.gpu`
and says so instead of failing silently, but on those browsers there is no chat.

The first visit downloads hundreds of megabytes. The widget waits for a click
before starting that download and shows the size first, which is why there is a
start button rather than an automatic load.

Small models are weak at facts and will invent answers about your business.
Whatever the model needs to know has to fit in `system-prompt`, because there is
no server to retrieve anything from. That constraint is the point of the
serverless setup, not an oversight in it.

## Verified

The widget was driven end to end in headless Chrome from
`local/index.html`: `SmolLM2-360M` loaded in 23 seconds over SwiftShader (CPU,
no real GPU), answered a question correctly, and reported 32 tokens/sec. On a
machine with a real GPU it is considerably faster. The Wix editor steps above
come from the Wix documentation linked below and have not been run against a
live Wix account.

* [Add a custom element](https://dev.wix.com/docs/velo/velo-only-apis/$w/custom-element/add-a-custom-element)
* [About custom elements](https://dev.wix.com/docs/velo/velo-only-apis/$w/custom-element/introduction), including the Premium plan requirement
* [Wix Editor: embedding a site or a widget](https://support.wix.com/en/article/wix-editor-embedding-a-site-or-a-widget)
* [WebLLM](https://github.com/mlc-ai/web-llm)
