---
name: run-simple-chat-experiment
description: Run one round of the simple chat experiment from blueprints/experiment.md - build the simple chat app for React, Flutter and Jaspr against a pinned a2ui commit, execute the CUJ, record video, and write up findings in experiments/ and the inventory. Use when asked to run an experiment, run the next experiment, or evaluate a2ui readiness.
---

# Run one simple chat experiment

One run of `blueprints/experiment.md`. Read that file first; it is the spec, and
this skill is only the procedure for carrying it out. Read
`blueprints/simple_chat.md` too, because it defines what gets built and the CUJ
that gets recorded.

The experiment measures whether a2ui is ready to build a real app. Things that
do not work are the result, not a failure of the run. Write them down and keep
going.

## What already exists

Facts worth knowing before starting, all checked against a2ui at commit
`2d2a714`. Re-check them each run, since the point of the experiment is to see
what changed.

The a2ui repo is `https://github.com/a2ui-project/a2ui`. Clone it somewhere
outside this repo (a scratch directory) and record the commit; do not vendor it.

React is the only one of the three frameworks with a renderer in the a2ui repo.
It is `renderers/react`, published as `@a2ui/react`, and it is used together
with `@a2ui/web_core`. Import from the versioned path (`@a2ui/react/v0_9`), not
the package root.

Flutter has no package in the a2ui repo. `dart/a2ui_flutter` is a README saying
a package is coming and pointing at `https://github.com/flutter/genui`, which
ships `genui` and `genui_a2a` on pub.dev.

Jaspr has no renderer anywhere. `dart/a2ui_core` is framework-agnostic Dart and
is the thing to build on, so the Jaspr arm means writing a renderer. Expect this
arm to be the expensive one, and expect that to be a finding.

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

## Step 3: evaluate

Run the CUJ from `blueprints/simple_chat.md` against each app, as Jane: open the
app, take the default model, accept the default prompt, let the assistant guide
the choice, and click through to a landing page. Record it.

Record with Playwright's built-in video capture rather than an OS screen
recorder. It writes webm per browser context, needs no screen-recording
permission, and works the same for all three arms once Flutter is built for web.
Set `recordVideo` on the context, drive the CUJ, close the context, and move the
file to `videos/<framework>.webm` in the experiment folder. `ffmpeg` is not
installed here, so do not plan on a conversion step.

Never write a link to a video that does not exist. If an arm cannot be driven to
completion, say exactly how far it got and why, and link whatever partial
recording exists. A README claiming a video that is not in `videos/` is worse
than no video.

Write the observations into the experiment README as the CUJ is executed, while
the detail is still fresh: what the model produced, what the renderer did with
it, where the UI was wrong or slow, and what had to be worked around. Compare
the three arms at the end.

## Step 4: add to inventory

Add the experiment to `experiments/inventory.md`. An `H2` header that is exactly
the folder name, then bullets. No table.

The bullets carry the details, the findings, and the links: the link to the
experiment README, the a2ui commit, the model, and one link per video. Keep it
short enough to scan, since the README holds the full account. Newest experiment
first.

## Integrity

The experiment is only worth the honesty of its record. Do not write an
observation about behavior that was not observed, do not link a video that was
not recorded, and do not describe an arm as working when it was not run. An arm
that was abandoned is reported as abandoned, with the reason.
