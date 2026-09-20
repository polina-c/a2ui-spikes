# Experiment 2026-09-20-0155

[gallery]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/
[react-video]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/react.webm
[flutter-video]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/flutter.webm
[jaspr-video]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/jaspr.webm
[react-picker]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/react-picker.png
[react-ui]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/react-generated-ui.png
[react-landing]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/react-landing.png
[flutter-picker]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/flutter-picker.png
[flutter-ui]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/flutter-generated-ui.png
[flutter-landing]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/flutter-landing.png
[jaspr-picker]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/jaspr-picker.png
[jaspr-ui]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/jaspr-generated-ui.png
[jaspr-landing]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-20-0155/videos/jaspr-landing.png

One run of [the simple chat experiment](../../blueprints/experiment.md): build the
[simple chat app](../../blueprints/simple_chat.md) for React, Flutter and Jaspr
against a pinned a2ui commit, run the CUJ against each, and record what happened.

## Details

* a2ui commit: [`2d2a714`](https://github.com/a2ui-project/a2ui/commit/2d2a714dafd22590e705c32a47cd5390ab96fdc5)
  (`main` at the time of the run, and the same commit the 2026-09-19-1347 run
  used - nothing landed upstream in between)
* Package versions: `@a2ui/react` 0.11.1, `@a2ui/web_core` 0.11.0, `a2ui_core`
  0.1.1, `genui` 0.10.3. All four are unchanged since the previous run.
* Model the three apps ran with: Gemini `gemini-flash-latest`
* Model parameters: temperature 0.7, max output tokens 4096
* Model that generated the application code: Claude Opus 5, harness defaults
* All three arms ran the same CUJ with the same model, so the framework is the
  only thing that differs between them.
* The three apps were written fresh for this run rather than carried over from
  2026-09-19-1347, so the line counts below are comparable to each other but
  not to that run's.
* The videos and screenshots are served from the [recordings site][gallery]
  rather than kept here, to keep this repo small. That page plays all three
  runs side by side. The CUJ logs stay here, being text.

## Result

All three arms work, and all three completed the CUJ end to end: the app opens
on a model picker, takes the default, asks Jane five questions through
generated UI, recommends the Just Shining Eco, and opens its landing page. The
answers Jane gave were the same in all three runs and so was the
recommendation, which is what the knowledge base prescribes for her.

a2ui has not moved since the previous run - same commit, same four package
versions - so every rough edge that run reported is still there, and this run
reproduced each one. What is new here is in the apps and the harness rather
than in a2ui: the landing page link, the per-message error handling in the Dart
arm, and three environment problems that had to be solved before anything could
be recorded at all.

## The recordings

All three CUJs were recorded and are published on the
[recordings site][gallery], which plays the three arms side by side:
[react.webm][react-video], [flutter.webm][flutter-video] and
[jaspr.webm][jaspr-video].

Publishing them took two goes. The first attempt was refused: this session's
GitHub credentials were read-only for both repositories, `git push` returned
403 with "Claude doesn't have GitHub access", and the API write path returned
"Resource not accessible by integration". Installing the Claude GitHub App on
the two repositories fixed it, and everything below was pushed afterwards. A
scheduled run has no way around that on its own, so it is worth checking that
the push can happen before recording anything.

One check the usual procedure asks for could not be done from here. The step
after pushing is to fetch each Pages URL and compare its sha256 with the local
file, and `polina-c.github.io` is blocked by this container's egress policy -
every request to it fails at the proxy with a 403 CONNECT, including URLs from
the previous run that are known to work. Instead each file was verified through
the GitHub API against `main`, the branch Pages serves: all twelve are present
at the paths above and every git blob SHA matches the local file byte for byte.
The three `*-landing.png` share a SHA because all three arms landed on the same
page.

The step-by-step log of each run is text, so it stays in this repo:
[react](videos/react-cuj.log), [flutter](videos/flutter-cuj.log),
[jaspr](videos/jaspr-cuj.log). Each one lists the options the assistant drew at
every turn, which answer Jane pressed and why, and the URL the landing page
button opened.

## Size of each arm

Hand-written source, counted with [tools/count-source.sh](tools/count-source.sh),
which leaves out dependencies, build output, generated files, package manifests
and tool configuration.

* React: 886 lines of source, 53 lines of tests
* Flutter: 764 lines of source, 55 lines of tests
* Jaspr: 1361 lines of source, 149 lines of tests

Flutter is the smallest arm, and it is smallest for the reason the experiment
is looking for: genui writes the protocol half of the system prompt from the
catalog, runs the conversation loop, and styles the generated widgets from the
app's theme. Its 24-line `prompt.dart` is the whole of what the app has to say
about A2UI. The React arm's equivalent is 102 lines and the Jaspr arm's is 107,
both hand-written, and both are the part most likely to drift.

Jaspr costs about 475 lines more than React. 220 of those are the renderer and
the catalog it needs - [renderer.dart](jaspr/lib/a2ui/renderer.dart) is 184
lines and [catalog.dart](jaspr/lib/a2ui/catalog.dart) is 36. Most of the rest
is styling: 320 lines of CSS against React's 244, because the Jaspr arm styles
the generated components as well as the app around them, and the React arm gets
that from the package.

## React

Uses `@a2ui/react` 0.11.1 with `@a2ui/web_core` 0.11.0, the only official
renderer of the three. Code in [react/](react), and how to run it in
[react/README.md](react/README.md). The CUJ ran end to end:
[react.webm][react-video], with stills of the [picker][react-picker], the
[first generated UI][react-ui] and the [landing page][react-landing], and the
step-by-step log in [videos/react-cuj.log](videos/react-cuj.log).

This was the quickest arm to get working and the one with the most packaging
problems, all of them the same ones the previous run found:

* The package advertises `./styles/structural.css` in its export map without
  shipping it, and does not export the `v0_9/index.css` it does ship, so
  neither import resolves. `injectStyles()` from `@a2ui/react/styles` works and
  is what the app calls.
* The published versions are still out of step: the renderer is 0.11.1 and the
  core it depends on stops at 0.11.0.
* `@a2ui/web_core`'s root export still points at v0.8, so both packages have to
  be imported from `/v0_9`.
* `@a2ui/markdown-it`, which `@a2ui/react` depends on for markdown, is at
  0.1.2 while everything around it is at 0.11.x. Nothing breaks, but a version
  guessed from its neighbours does not exist.

One correction to what the previous run recorded. Styling is not entirely the
host's problem: the basic catalog injects its own defaults at `:where(:root)`,
so generated UI is legible before the host does anything, and the host only
overrides what it wants. The token names are real and documented in
[a2ui's theming guide](https://github.com/a2ui-project/a2ui/blob/main/docs/public/guides/theming.md),
with the full list in web_core's `basic_catalog/styles/default.ts`. Invented
names - this run started with `--a2ui-radius-medium` and `--a2ui-spacing-medium`
- are silently ignored, which is easy to mistake for the renderer ignoring the
host.

## Flutter

Uses the [Flutter GenUI SDK](https://github.com/flutter/genui), `genui` 0.10.3,
because a2ui has no Flutter package: `dart/a2ui_flutter` is still a README
pointing at flutter/genui. Code in [flutter/](flutter), and how to run it in
[flutter/README.md](flutter/README.md). The CUJ ran end to end on the first
recorded attempt: [flutter.webm][flutter-video], with stills of the
[picker][flutter-picker], the [first generated UI][flutter-ui] and the
[landing page][flutter-landing], and the step-by-step log in
[videos/flutter-cuj.log](videos/flutter-cuj.log).

genui remains the most complete of the three. `PromptBuilder.chat` writes the
protocol instructions from the catalog, `Conversation` runs the loop so a press
on a generated button comes back as a turn without the app arranging it, and
Material theming reaches the generated widgets, which is why this arm looks the
best with the least styling.

Two things this run did differently. It uses `BasicCatalogItems.asNoAssetCatalog()`,
which drops the image, audio and video components an app like this never shows.
And it does not use genui's built-in `openUrl`: see the landing page section
below.

The API drift the previous run reported in genui's own integration skill is
still there - the package takes `systemPromptFragments` and exposes
`systemPrompt()` and `systemPromptJoined()`, not the `instructions` and
`systemPrompt` property the skill shows. Reading the source is still the way to
use it.

## Jaspr

Uses Jaspr 0.23.4 and `a2ui_core` 0.1.1, with a renderer written for this
experiment. a2ui still has nothing for Jaspr, and nothing for the web in Dart
at all. Code in [jaspr/](jaspr), and how to run it in
[jaspr/README.md](jaspr/README.md). The CUJ ran end to end:
[jaspr.webm][jaspr-video], with stills of the [picker][jaspr-picker], the
[first generated UI][jaspr-ui] and the [landing page][jaspr-landing], and the
step-by-step log in [videos/jaspr-cuj.log](videos/jaspr-cuj.log).

The second run confirms the surprise of the first: writing the renderer is not
the expensive part. `a2ui_core` parses the messages, holds the component tree
and the data model, resolves `{path: ...}` bindings and dispatches actions, so
the renderer is the last step only - 184 lines to turn a component tree into
Jaspr components, and the result is hard to tell apart from the React arm on
screen.

What costs is everything a published renderer would have decided. This app had
to choose its catalog (a2ui_core ships a minimal one with no Card, so this one
adds a Card, and nothing says another Jaspr app would), how a surface redraws
(watching `/` on the data model plus the component model's created and deleted
events), what an unknown component looks like (a visible red placeholder rather
than nothing), and what the generated components' class names are - they are
this renderer's invention, so the 320-line stylesheet is part of the cost of
having no renderer.

One new failure, and it is worth knowing about. `A2uiMessage.fromJson` is
strictly typed and throws on a shape it does not recognise. Handing it a whole
reply at once means one malformed message loses the entire turn, and
`gemini-flash-latest` does produce one every so often: the first recorded
attempt died on turn two with `type 'List<dynamic>' is not a subtype of type
'Map<String, dynamic>'` and the same prompt worked on the next try. The app now
applies messages one at a time and steps over a bad one, which is what any host
on `a2ui_core` will have to do.

Both pieces of Jaspr friction from the previous run are unchanged: a freshly
generated project does not resolve until `build_web_compilers` is held at
`^4.8.5`, and a project generated into a directory called `jaspr` is named
`jaspr` and cannot depend on the package of the same name.

## The landing page link, and a model that rewrites URLs

The last step of the CUJ is Jane clicking through to the product page, and it
is the step the web catalog cannot express: there is no link component and
`Text` does not render markdown links. The React and Jaspr arms both work
around it the same way, with a Button whose action the host turns into a
navigation. genui has a built-in `openUrl` and needs no workaround.

The first recorded React run exposed something else. The prompt asked the model
to put the landing page URL in the action, quoting it from the knowledge base,
and `gemini-flash-latest` returned
`.../blob/main/domain/landing_pages/eco.md` - the real address with the `ci/`
segment missing. The CUJ "completed": a tab opened, the driver logged a URL, the
screenshot showed a page. The page was a GitHub 404.

All three arms now name the machine instead - `{"name":"openLandingPage",
"context":{"model":"eco"}}` - and the app looks the address up in the knowledge
base it already has. That is why the Flutter arm has its own `openLandingPage`
client function rather than using genui's `openUrl`: `openUrl` takes the address
from the model, which is the shape that failed. The driver now logs the title
of the page it lands on as well as the URL, so a 404 is visible in the log
rather than looking like success.

The general point is worth keeping: an action context is the natural place to
put an identifier the host resolves, not an address the host obeys. A URL that
has been through a language model is a URL that can lose a path segment.

## Three environment problems, before any of this ran

None of these are a2ui's, but they cost most of the run's time and the next run
should not pay for them again.

* **The browser did not trust the proxy.** Every `fetch` to Gemini failed with
  `ERR_CERT_AUTHORITY_INVALID`, which surfaces in the app as "Failed to fetch"
  and looks exactly like a bad API key. The container's HTTPS goes through a
  TLS-terminating proxy whose CA is at `/root/.ccr/ca-bundle.crt`; Chromium
  reads user CAs from the NSS store, which was empty. Installing
  `libnss3-tools` and adding the bundle with `certutil -d sql:$HOME/.pki/nssdb`
  fixed it for every arm at once.
* **Playwright wanted a browser it could not download.** The installed
  Playwright expects a Chromium revision newer than the one in the image, and
  downloads are off. `tools/launch.mjs` now points `chromium.launch()` at
  `/opt/pw-browsers/chromium` directly.
* **Flutter web loads CanvasKit from gstatic.com**, which the egress policy
  blocks, so the app rendered nothing at all and the semantics tree was empty.
  `flutter build web` already copies CanvasKit into the build, so
  `web/flutter_bootstrap.js` now sets `canvasKitBaseUrl: 'canvaskit/'`. The
  `--dart-define=FLUTTER_WEB_CANVASKIT_URL=...` that older instructions
  suggest does nothing; the loader config is what counts.

## Findings

**a2ui is ready to build this app on all three frameworks, and this run is the
second piece of evidence for that.** The protocol, the message flow, the data
model and the action round trip did what they promise, and the model drove them
well enough to run the whole CUJ three times over.

**Nothing moved upstream between the two runs.** Same a2ui commit, same four
published package versions, a day apart. Every defect the previous run recorded
reproduced exactly. That is the main thing a weekly run is for, and it is worth
saying plainly: on this evidence the packaging problems are not being fixed
faster than they are being found.

**How far the SDK carries you is still entirely about the framework, and the
gap is still packaging rather than protocol.** 886 lines for the framework with
a renderer, 764 for the framework with no a2ui package but the best SDK, 1361
for the framework with nothing. `a2ui_core` is why the third number is not
worse, and it deserves more prominence than a directory in a monorepo.

**Prompt generation is still the biggest hole for client-only apps.** a2ui
generates the system prompt in its Python agent SDK, genui generates it in Dart
for Flutter, and there is nothing in JavaScript and nothing framework-neutral
in Dart. Two of the three arms hand-wrote about a hundred lines of instructions
each. `getClientCapabilities({includeInlineCatalogs: true})` gives the catalog
as JSON Schema at runtime in both `web_core` and `a2ui_core`, which is the
useful half; what is missing is the prose around it, and it is the same prose
in both arms.

**`a2ui_core` is strict where `web_core` is forgiving, and a host has to plan
for it.** One malformed message from the model throws and takes the turn with
it unless the app applies messages one at a time. A renderer package would
absorb this; a host writing its own has to know.

**The model was not the hard part, but it is not free either.** Valid A2UI on
essentially every turn across three arms, the questions asked in the order the
knowledge base sets out, and the recommendation the knowledge base prescribes.
The one thing it got wrong was a URL it was asked to copy, and that is an
argument for never asking it to copy one.

**A scheduled run needs its write access checked before it records anything.**
This one recorded all three CUJs and then could not push them: both
repositories were read-only for this session until the Claude GitHub App was
installed on them. The recordings are published now, but the run had already
finished by the time that was fixed, and a run that cannot publish has nothing
to show for itself. Checking the push first costs a second.

## Reproducing

The apps are in [react/](react), [flutter/](flutter) and [jaspr/](jaspr), each
with a README. The CUJ driver shared by all three is in [tools/](tools); it
needs `GEMINI_API_KEY` in the environment, types the key into the app the way a
user would, and picks Jane's answers by reading the options on screen.

```bash
node tools/cuj.mjs dom     http://localhost:4173/ videos react
node tools/cuj.mjs flutter http://localhost:4174/ videos flutter
node tools/cuj.mjs dom     http://localhost:4175/ videos jaspr
```
