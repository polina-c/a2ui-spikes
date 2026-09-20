---
name: run-simple-chat-experiment
description: Run one round of the simple chat experiment from blueprints/experiment.md - build the simple chat app for React, Flutter and Jaspr against a pinned a2ui commit, execute the CUJ, record video, and write up findings in experiments/ and the inventory. Use when asked to run an experiment, run the next experiment, or evaluate a2ui readiness.
---

# Run one simple chat experiment

One run of `blueprints/experiment.md`. Read that file first; it is the spec, and
this skill is only the procedure for carrying it out. Read
`blueprints/simple_chat.md` too, because it defines what gets built and the CUJ
that gets recorded.

## What an arm is

An arm is one framework build run against one model: "the React arm on Gemini
Flash". Both halves are part of it, because a result only means something when
you can name the framework and the model that produced it.

In practice the model is held fixed across the experiment. The blueprint asks
for one model name in the experiment README, and all three frameworks are built
against the same a2ui commit and run with that same model. So the usual
experiment has three arms, one per framework, and the framework is the only
thing that varies between them. That is what makes them comparable.

The apps themselves still offer a choice of model at runtime, because the
blueprint asks for that. The experiment's model is the one the CUJ is actually
run with, which is the default the picker opens on.

If an experiment deliberately runs a second model as well, that is a second arm
for each framework, not a footnote on the first: name it
`<framework>-<model>`, give it its own video, and say in the README why the
comparison was worth the extra runs.

Each arm gets its own pass through the CUJ and its own video. Each framework
gets its own subdirectory and its own README with the commands to run it. The
arms are built and judged separately, so one failing says nothing about the
others.

The experiment measures whether a2ui is ready to build a real app. Things that
do not work are the result, not a failure of the run. Write them down and keep
going.

## What already exists

Facts worth knowing before starting, all checked against a2ui at commit
`2d2a714`. Re-check them each run and update this skill, since the point of the experiment is to see what changed.

The a2ui repo is `https://github.com/a2ui-project/a2ui`. Clone it somewhere
outside this repo (a scratch directory) and record the commit; do not vendor it.

React is the only one of the three frameworks with a renderer in the a2ui repo.
It is `renderers/react`, published as `@a2ui/react`, and it is used together
with `@a2ui/web_core`. Import from the versioned path (`@a2ui/react/v0_9`), not
the package root. At 0.11.1 the package advertises `./styles/structural.css` in
its export map without shipping it and does not export the `v0_9/index.css` it
does ship, so use `injectStyles()` from `@a2ui/react/styles`; its dependency
`@a2ui/web_core` stops at 0.11.0. Styling is the host's job: the structural CSS
expects the page to define the `--a2ui-*` palette. `Text` renders markdown only
when a renderer is passed through `MarkdownContext`.

Flutter has no package in the a2ui repo. `dart/a2ui_flutter` is a README saying
a package is coming and pointing at `https://github.com/flutter/genui`, which
ships `genui` and `genui_a2a` on pub.dev. `genui_a2a` connects to an A2A agent
over a server; an app that calls the model straight from the client wants
`genui` alone, with an `A2uiTransportAdapter` whose `onSend` calls the model.
genui carries the most of the three: `PromptBuilder.chat` writes the protocol
half of the system prompt from the catalog, `Conversation` runs the interaction
loop, and the catalog has `openUrl`. Its own integration skill is out of date
with its API, so read the source: the builder takes `systemPromptFragments` and
exposes `systemPrompt()` and `systemPromptJoined()`.

Jaspr has no renderer anywhere. `dart/a2ui_core` is framework-agnostic Dart and
is the thing to build on, so the Jaspr arm means writing a renderer. In the
2026-09-19-1347 run that renderer was 180 lines, because `a2ui_core` already
parses the messages, keeps the tree and the data model, resolves paths and
dispatches actions. Budget for the decisions around it rather than for the code:
which catalog, how a surface redraws, what an unknown component looks like.

Three gaps hit every run and are worth checking before building rather than
after. Nothing generates the system prompt outside a2ui's Python agent SDK and
genui's Dart one, so the React and Jaspr arms have to write those instructions
by hand; `getClientCapabilities({includeInlineCatalogs: true})` in `web_core`
does give the catalog as JSON Schema at runtime, which saves copying schemas.
The web catalog cannot express a link and `Text` does not render markdown links,
so clicking through to a landing page, the last step of the CUJ, needs a Button
with an agreed action name that the app turns into a navigation; genui has a
built-in `openUrl` and needs none of this. And `@a2ui/web_core`'s root export
points at v0.8, so both web packages must be imported from `/v0_9`.

Useful reading in the a2ui checkout: `docs/public/quickstart.md`,
`docs/public/guides/a2ui-with-any-agent-framework.md` (the relevant one, since
this app talks to the model directly rather than to an ADK agent),
`docs/public/guides/client-setup.md`, `docs/public/guides/defining-your-own-catalog.md`,
`specification/v1_0/` and `specification/v0_9/docs/a2ui_protocol.md`.

The protocol in one paragraph: the model emits a stream of messages. Its
`createSurface` opens a rendering area against a catalog, `updateComponents`
sends the component tree, and `updateDataModel` sends the data the components
bind to through `{path: '/...'}` references. The renderer keeps the two in sync.

## Step 1: setup

Name the folder `experiments/<date>-<time>` using the real current date and
time, zero-padded, as `YYYY-MM-DD-HHMM`. Get it from `date`, do not guess it.

Write `README.md` in that folder before building anything, so that a run that
dies halfway still leaves a record. It states the a2ui commit as a link to the
commit on GitHub, the model name, and the model parameters, and it keeps empty
sections for the three frameworks and the findings.

Resolve the commit with `git ls-remote https://github.com/a2ui-project/a2ui HEAD`
or `git rev-parse HEAD` in the checkout, and link it as
`https://github.com/a2ui-project/a2ui/commit/<sha>`. Record the full sha.

## Step 2: generate

Build the app from `blueprints/simple_chat.md` three times, into `react/`,
`flutter/` and `jaspr/` under the experiment folder. Each one is a working app,
not a sketch: the model picker that opens the app, the Gemini and local families,
the API key entered behind dots when `GEMINI_API_KEY` is absent, the chat, and
the assistant answering with a2ui-generated UI rather than only text.

The domain knowledge is `domain/knowledge.md` and the landing pages are in
`domain/landing_pages/`. Either embed them or fetch them over HTTP, whichever
the framework makes reasonable, and say in the README which one was used and why.

Build the three independently. Do not let a working React arm quietly become the
source for the others, because how hard each one is on its own is the thing being
measured. Note where the a2ui documentation answered a question and where it did
not.

Give each arm a README with the commands to run it.

When the three are built, measure how much hand-written source each one took.
Size is the cheapest signal of how much an SDK carries: the arm with no renderer
should cost more, and by how much is the interesting part.

`tools/count-source.sh` in the experiment folder does the counting and prints a
table plus a per-file breakdown. Run it from the experiment folder and copy the
numbers into the README and the inventory. A new arm adds its source and test
paths to the arrays at the top of the script.

Count the code, markup and styles the app is built from. Do not count tests in
that number, report them separately, and leave out dependencies, build output,
files marked generated, package manifests, tool configuration, and scaffolding
left exactly as a generator produced it. The script already applies these rules;
the point of writing them down is that the next run counts the same way, because
a size comparison against a differently drawn line is worse than none.

Report the lines together with what they bought. The Jaspr number carries a
renderer that does not exist upstream, so quote that file's size on its own as
well as in the arm's total.

## Step 3: evaluate

Run the CUJ from `blueprints/simple_chat.md` once per framework and model
combination, as Jane: open the app, take the default model, accept the default
prompt, let the assistant guide the choice, and click through to a landing page.
Record each run. With one model that is three runs and three videos; with a
second model it is six, and the video names say which is which.

Record with Playwright's built-in video capture rather than an OS screen
recorder. It writes webm per browser context, needs no screen-recording
permission, and works the same for all three arms once Flutter is built for web.
`ffmpeg` is not installed here, so do not plan on a conversion step.

Point `recordVideo` at a directory of its own per run, then move the file to
`videos/<framework>.webm`. Playwright names the file itself, so a run that picks
its recording out of the shared `videos/` folder can pick up, or delete, another
arm's video. That happened in the 2026-09-19-1347 run and cost two re-records.

One driver can serve all three arms if it takes the arm's kind. React and Jaspr
render real elements and are driven normally. Flutter web paints a canvas, so
the app has to call `SemanticsBinding.instance.ensureSemantics()` and the driver
works through `flt-semantics[role="button"]`; a real pointer click is swallowed
by whichever overlapping node is on top, so dispatch the click on the node
itself with `el.click()`, the path a screen reader takes.

Pick Jane's answers by matching rules against the question on screen, not by
counting turns. Matching only against the options cross-talks: "On the countertop
(no plumbing)" contains "no", which reads like an answer to the question about
noise. The chat is a transcript and earlier turns stay on screen, so treat only
labels that have not been seen before as the current question's options.

Gemini returns 503 under load often enough to end a recorded run. Give the
model client a retry with a backoff before recording anything.

Never write a link to a video that does not exist. If an arm cannot be driven to
completion, say exactly how far it got and why, and link whatever partial
recording exists. A README claiming a video that is not in `videos/` is worse
than no video.

Write the observations into the experiment README as the CUJ is executed, while
the detail is still fresh: what the model produced, what the renderer did with
it, where the UI was wrong or slow, and what had to be worked around. Compare
the three arms at the end.

## Step 4: add to inventory

Add the experiment to `experiments/inventory.md`, newest first. An `H2` header
that is exactly the folder name, then a table, then bullets.

The table has one row per framework, and carries the link to that framework's
video, the link to its README in the experiment folder, and its line count. Keep
it to those columns; anything else belongs in a bullet or in the experiment
README.

| Framework | Video | README | Source lines |
| --- | --- | --- | --- |
| React | [video](...) | [react](...) | 877 |

If the experiment ran more than one model, there is a row per framework and
model combination rather than per framework, because that is what an arm is, and
the row names both.

The bullets carry the experiment details and the findings: the link to the
experiment README, the a2ui commit, the model and its parameters, and what the
run showed. Keep them short enough to scan, since the experiment README holds
the full account.

The line count in the table is the source count from step 2, not source plus
tests. If an arm's test count is worth saying, say it in a bullet, because
mixing the two in one column makes the arms look closer or further apart than
they are.

## Integrity

The experiment is only worth the honesty of its record. Do not write an
observation about behavior that was not observed, do not link a video that was
not recorded, and do not describe an arm as working when it was not run. An arm
that was abandoned is reported as abandoned, with the reason.
