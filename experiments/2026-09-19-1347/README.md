# Experiment 2026-09-19-1347

One run of [the simple chat experiment](../../blueprints/experiment.md): build the
[simple chat app](../../blueprints/simple_chat.md) for React, Flutter and Jaspr
against a pinned a2ui commit, run the CUJ against each, and record what happened.

## Details

* a2ui commit: [`2d2a714`](https://github.com/a2ui-project/a2ui/commit/2d2a714dafd22590e705c32a47cd5390ab96fdc5)
  (`main` at the time of the run)
* Model the three apps ran with: Gemini `gemini-flash-latest`, which the API
  resolved to `gemini-3.8-flash`
* Model parameters: temperature 0.7, max output tokens 4096
* Model that generated the application code: Claude Opus 5, harness defaults
* All three arms ran the same CUJ with the same model, so the framework is the
  only thing that differs between them.

## Result

All three arms work. Each one opens on a model picker, takes the default, asks
Jane five questions through generated UI, recommends the Just Shining Eco, and
opens its landing page. The three reached the same recommendation from the same
answers, which is what the knowledge base prescribes for Jane.

The interesting differences are not in whether a2ui works, but in how much of
the way it carries you. For React it ships a renderer. For Flutter it ships a
pointer to someone else's. For Jaspr it ships nothing, and the renderer was
written here.

## Size of each arm

Hand-written source, counted with [tools/count-source.sh](tools/count-source.sh),
which leaves out dependencies, build output, generated files, package manifests
and tool configuration.

* React: 877 lines of source, no tests
* Flutter: 929 lines of source, 45 lines of tests
* Jaspr: 1227 lines of source, 101 lines of tests

The three are close enough that the missing Jaspr renderer is not the story it
looked like it would be. Jaspr costs about 350 lines more than React, and 180 of
those are [the renderer itself](jaspr/lib/a2ui/renderer.dart). Most of the rest
is the styling and prompt scaffolding the React arm gets from its package: 209
lines of CSS against React's 153, because the Jaspr arm styles the generated
components as well as the app around them.

Flutter sits in the middle, and would sit lower if Dart were as terse as JSX;
its 929 lines buy a prompt builder, a conversation loop and a working link, none
of which the other two get for free.

The React arm having no tests is a gap in this run rather than a finding about
a2ui. The other two arms were testable without a browser, and writing those
tests was cheap; the React arm's equivalent was skipped under time.

## React

Uses `@a2ui/react` 0.11.1 with `@a2ui/web_core` 0.11.0, the only official
renderer of the three. Code in [react/](react), and how to run it in
[react/README.md](react/README.md).

The CUJ ran end to end: [videos/react.webm](videos/react.webm). Stills of the
[picker](videos/react-picker.png), the [first generated UI](videos/react-generated-ui.png)
and the [landing page](videos/react-landing.png), and the options the driver saw
at every step in [videos/react-cuj.log](videos/react-cuj.log).

This arm was the quickest to get running and the roughest at the edges.

The package advertises `./styles/structural.css` in its export map and does not
ship the file; the CSS it does ship, `v0_9/index.css`, is not exported at all,
so neither import resolves and the build fails. `injectStyles()` from
`@a2ui/react/styles` works and is what the app uses. The published versions are
also out of step: the renderer is 0.11.1 and the core it depends on stops at
0.11.0.

`@a2ui/web_core`'s root export points at v0.8. Both `@a2ui/react` and
`@a2ui/web_core` have to be imported from `/v0_9` or the app silently builds
against the older protocol.

Styling is the host's problem. The structural CSS lays components out and
expects the page to define the `--a2ui-*` palette; without it the generated UI
is legible but plain, which the screenshot shows next to Flutter's.

`Text` renders markdown only when a renderer is passed through
`MarkdownContext`. `@a2ui/markdown-it` is already a dependency of
`@a2ui/react`, but nothing is wired up by default, so markdown arrives as
literal asterisks until the app connects the two.

## Flutter

Uses the [Flutter GenUI SDK](https://github.com/flutter/genui), `genui` 0.10.3,
because a2ui has no Flutter package. Code in [flutter/](flutter), and how to run
it in [flutter/README.md](flutter/README.md).

The CUJ ran end to end: [videos/flutter.webm](videos/flutter.webm). Stills of the
[picker](videos/flutter-picker.png), the [first generated UI](videos/flutter-generated-ui.png)
and the [landing page](videos/flutter-landing.png), and the step by step log in
[videos/flutter-cuj.log](videos/flutter-cuj.log).

`dart/a2ui_flutter` in the a2ui repo is a README saying a package is coming and
pointing at flutter/genui. Following the pointer costs nothing, since genui
depends on `a2ui_core` and speaks the same protocol, but it does mean the
Flutter story is owned by a different repo on a different release cycle.

genui is the most complete of the three. It builds the protocol half of the
system prompt from the catalog with `PromptBuilder.chat`, so this app only
supplies the selling instructions and the knowledge base. Its `Conversation`
runs the loop on its own: a press on a generated button comes back as a turn
without the app arranging it. And its catalog ships an `openUrl` client
function, so the landing page link needed no code at all, where the React and
Jaspr arms both had to implement it.

The generated UI also looks the best without effort, because Material theming
reaches the generated widgets.

Two rough edges. genui's own integration skill is out of date with its API: it
shows `PromptBuilder.chat(catalog:, instructions:)` and a `systemPrompt`
property, while the package takes `systemPromptFragments` and exposes
`systemPrompt()` and `systemPromptJoined()`. And Flutter web paints into a
canvas, so there is no DOM for a screen reader or a test driver; the app turns
the semantics tree on permanently to get one.

## Jaspr

Uses `a2ui_core` 0.1.1 and a renderer written for this experiment. Code in
[jaspr/](jaspr), and how to run it in [jaspr/README.md](jaspr/README.md).

The CUJ ran end to end: [videos/jaspr.webm](videos/jaspr.webm). Stills of the
[picker](videos/jaspr-picker.png), the [first generated UI](videos/jaspr-generated-ui.png)
and the [landing page](videos/jaspr-landing.png), and the step by step log in
[videos/jaspr-cuj.log](videos/jaspr-cuj.log).

This was the arm that was supposed to be expensive, and it was the most
interesting result of the run: it was not. `a2ui_core` is plain Dart and does
the protocol work, so the missing piece was only the last step, turning a
component tree into views.
[jaspr/lib/a2ui/renderer.dart](jaspr/lib/a2ui/renderer.dart) is 180 lines and
covers the minimal catalog plus Card.

The cost of having no renderer is not the renderer. It is everything around it
that a published one would have decided: which catalog, how surfaces redraw,
what a component outside the catalog should look like, and how a link gets
opened. Those are answered here by one app making them up, and nothing checks
that the answers match what another Jaspr app would choose.

The friction on this arm was Jaspr's, not a2ui's. A freshly generated project
does not resolve, because `jaspr_builder` wants `analyzer ^12.1.0` and the
`build_web_compilers` it pins wants `>=13.3.0`; holding the compilers below
4.8.6 fixes it. A project generated into a directory called `jaspr` is named
`jaspr` and cannot depend on the package of the same name. And reading a value
out of an input event through `dynamic` analyzes cleanly, then does nothing once
compiled to JavaScript.

## Findings

**a2ui is ready to build this app, on all three frameworks.** The protocol,
the message flow, the data model and the action round trip all did what they
promise, first time, and the model was able to drive them.

**How ready depends entirely on the framework, and the gap is about packaging,
not protocol.** React has a renderer with packaging bugs. Flutter has no a2ui
package but the best SDK, owned elsewhere. Jaspr has nothing, and needed 180
lines. The sizes bear this out: 877, 929 and 1227 lines of source, a spread of
about 40 percent between the arm that is handed a renderer and the arm that
writes one. `a2ui_core` is the reason the third case is cheap, and it deserves
more prominence than a directory in a monorepo.

**Prompt generation is the biggest hole for client-only apps.** a2ui generates
the system prompt in its Python agent SDK; genui generates it in Dart for
Flutter. There is nothing in JavaScript, and nothing framework-neutral in Dart.
Both the React and Jaspr arms hand-wrote the instructions that tell a model how
to emit A2UI, and they are the part most likely to drift and hardest to test.
`getClientCapabilities({includeInlineCatalogs: true})` in `web_core` does give
the catalog as JSON Schema at runtime, which is the useful half, so what is
missing is the prose around it.

**The web catalog cannot express a link.** There is no link component, and
`Text` documents that markdown links are not supported. Sending a user to a
product page is the last step of this CUJ and of most selling conversations, and
on the web stack every app has to invent the same workaround: a Button with an
agreed action name that the host turns into a navigation. genui gets this right
with a built-in `openUrl`.

**The model was not the hard part.** `gemini-flash-latest` produced valid A2UI
on essentially every turn across three arms and many runs, asked the questions
in the order the knowledge base sets out, and reached the recommendation the
knowledge base prescribes. The failures in this run were packaging, tooling and
test-harness problems, not generation problems.

**Two things about the runs themselves, for the next experiment.** Gemini
returns 503 under load often enough that a retry is needed for a recorded run to
survive. And Flutter web needs its semantics tree turned on to be driveable at
all, with clicks dispatched on the semantics node rather than as real pointer
events.

## Reproducing

The apps are in [react/](react), [flutter/](flutter) and [jaspr/](jaspr), each
with a README. The CUJ driver shared by all three is in [tools/](tools); it
needs `GEMINI_API_KEY` in the environment, types the key into the app the way a
user would, and picks Jane's answers by reading the options on screen.
