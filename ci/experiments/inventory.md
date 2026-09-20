# Experiments inventory

## 2026-09-20-0155

The recordings of this run could not be published: this session had read-only
access to the binaries repo, so the Video column names the file that was made
rather than linking one that was never pushed. The step-by-step CUJ logs are in
the experiment folder.

| Framework | Video                     | README                                       | Source lines |
| --------- | ------------------------- | -------------------------------------------- | ------------ |
| React     | `react.webm` (not pushed)   | [react](2026-09-20-0155/react/README.md)     | 886          |
| Flutter   | `flutter.webm` (not pushed) | [flutter](2026-09-20-0155/flutter/README.md) | 764          |
| Jaspr     | `jaspr.webm` (not pushed)   | [jaspr](2026-09-20-0155/jaspr/README.md)     | 1361         |

* [Experiment README](2026-09-20-0155/README.md): the simple chat app built
  fresh for React, Flutter and Jaspr, with the CUJ run and recorded against
  each.
* a2ui commit [`2d2a714`](https://github.com/a2ui-project/a2ui/commit/2d2a714dafd22590e705c32a47cd5390ab96fdc5),
  which is what `main` was on 2026-09-19 as well: nothing landed upstream
  between the two runs, and `@a2ui/react` 0.11.1, `@a2ui/web_core` 0.11.0,
  `a2ui_core` 0.1.1 and `genui` 0.10.3 are all unchanged too.
* All three arms ran on Gemini `gemini-flash-latest` at temperature 0.7, max
  4096 output tokens.

### Observations

* All three arms completed the CUJ and recommended the Just Shining Eco from
  the same answers, which is what the knowledge base prescribes for Jane.
* Nothing moved upstream between this run and 2026-09-19-1347, and every defect
  that run recorded reproduced exactly. That is the main thing a repeated run
  buys.
* Flutter is now the smallest arm at 764 lines, because genui writes the
  protocol half of the system prompt, runs the conversation loop and themes the
  generated widgets. Its prompt file is 24 lines; the two hand-written ones are
  102 and 107.
* Jaspr costs 475 lines more than React. 220 of those are the renderer and its
  catalog; most of the rest is the stylesheet for the generated components,
  which the React arm gets from its package.
* The apps were written fresh for this run, so these line counts compare to
  each other but not to the 2026-09-19-1347 row.
* Tests on top of the source counts: React 53, Flutter 55, Jaspr 149. The React
  arm has tests this time, which closes the gap the previous run flagged.
* Correction to the previous run: the host does not have to define the
  `--a2ui-*` palette. The basic catalog injects defaults at `:where(:root)` and
  the host overrides what it wants; the names are in a2ui's theming guide and
  in web_core's `basic_catalog/styles/default.ts`. Invented names are ignored
  silently.

### Issues

* `gemini-flash-latest` rewrote a landing page URL it was asked to quote,
  dropping a path segment, and the CUJ "completed" onto a GitHub 404. All three
  arms now send the machine's name and let the app resolve the address; the
  driver logs the page title so a 404 is visible.
* `a2ui_core` throws on a message shape it does not recognise, so one malformed
  message from the model loses the whole turn unless the host applies messages
  one at a time. The Jaspr arm lost a recorded run to this before it did.
* Prompt generation still exists only in a2ui's Python SDK and in genui, so the
  React and Jaspr arms hand-wrote about a hundred lines of instructions each.
* The web catalog still cannot express a link, so sending a user to a product
  page needs a host-side workaround on every web app. genui's `openUrl` is the
  exception, but it takes the address from the model, which is the shape that
  failed above.
* `@a2ui/react` 0.11.1 still advertises a stylesheet it does not ship, still
  does not export the one it does, and still depends on a core that stops at
  0.11.0. `@a2ui/web_core`'s root export still points at v0.8.
* Jaspr still needs `build_web_compilers` held at `^4.8.5` to resolve at all,
  and a project generated into a directory called `jaspr` is still named
  `jaspr` and cannot depend on the package of the same name.
* The recordings were made and could not be published: `git push` and the API
  write path to polina-c/a2ui-spikes-binaries are both refused with 403 for
  this session, while reads succeed. Until the Claude GitHub App is installed
  on that repo, a scheduled run records videos and throws them away.

## 2026-09-19-1347

[2026-09-19-1347-react]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-19-1347/videos/react.webm
[2026-09-19-1347-flutter]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-19-1347/videos/flutter.webm
[2026-09-19-1347-jaspr]: https://polina-c.github.io/a2ui-spikes-binaries/ci/experiments/2026-09-19-1347/videos/jaspr.webm

Note: this experiment produced app that allow user to choose model, that took extra code lines.

| Framework | Video                                   | README                                       | Source lines |
| --------- | --------------------------------------- | -------------------------------------------- | ------------ |
| React     | [react.webm][2026-09-19-1347-react]     | [react](2026-09-19-1347/react/README.md)     | 877          |
| Flutter   | [flutter.webm][2026-09-19-1347-flutter] | [flutter](2026-09-19-1347/flutter/README.md) | 929          |
| Jaspr     | [jaspr.webm][2026-09-19-1347-jaspr]     | [jaspr](2026-09-19-1347/jaspr/README.md)     | 1227         |

* [Experiment README](2026-09-19-1347/README.md): the simple chat app built for
  React, Flutter and Jaspr, with the CUJ run and recorded against each.
* a2ui commit [`2d2a714`](https://github.com/a2ui-project/a2ui/commit/2d2a714dafd22590e705c32a47cd5390ab96fdc5);
  all three arms ran on Gemini `gemini-flash-latest` at temperature 0.7, max
  4096 output tokens.

### Observations

* All three arms completed the CUJ and recommended the Just Shining Eco from
  the same answers, which is what the knowledge base prescribes for Jane.
* a2ui ships a React renderer, no Flutter package (it points at flutter/genui),
  and nothing for Jaspr. How far the SDK carries you depends entirely on the
  framework, and the gap is packaging rather than protocol.
* The line counts above are source only, measured with
  [tools/count-source.sh](2026-09-19-1347/tools/count-source.sh). Tests on top:
  React 0, Flutter 45, Jaspr 101. The React arm having no tests is a gap in the
  run, not a finding about a2ui.
* Jaspr costs about 350 lines more than React, and 180 of those are the renderer
  that does not exist upstream. The rest is the prompt and the styling that the
  React arm gets from its package. The expensive part was not writing the
  renderer but the decisions a published one would have made: catalog, redraw,
  unknown components, links.
* genui is the most complete of the three: it generates the system prompt from
  the catalog, runs the conversation loop itself, and has a built-in `openUrl`.

### Issues

* Biggest hole for client-only apps: prompt generation exists only in a2ui's
  Python SDK and in genui for Flutter, so the React and Jaspr arms hand-wrote
  the instructions that teach the model to emit A2UI.
* Second hole: the web catalog cannot express a link, and `Text` does not render
  markdown links, so sending the user to a product page needs a host-side
  workaround on every web app.
* `@a2ui/react` 0.11.1 has packaging bugs: it advertises a stylesheet it does
  not ship, does not export the one it does, and depends on a core that stops at
  0.11.0.
