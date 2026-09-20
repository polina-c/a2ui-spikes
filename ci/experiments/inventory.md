# Experiments inventory

## 2026-09-19-1347

Note: this experiment produced app that allow user to choose model, that took extra code lines.

| Framework | Video                                               | README                                       | Source lines |
| --------- | --------------------------------------------------- | -------------------------------------------- | ------------ |
| React     | [react.webm](2026-09-19-1347/videos/react.webm)     | [react](2026-09-19-1347/react/README.md)     | 877          |
| Flutter   | [flutter.webm](2026-09-19-1347/videos/flutter.webm) | [flutter](2026-09-19-1347/flutter/README.md) | 929          |
| Jaspr     | [jaspr.webm](2026-09-19-1347/videos/jaspr.webm)     | [jaspr](2026-09-19-1347/jaspr/README.md)     | 1227         |

* [Experiment README](2026-09-19-1347/README.md): the simple chat app built for
  React, Flutter and Jaspr, with the CUJ run and recorded against each.
* a2ui commit [`2d2a714`](https://github.com/a2ui-project/a2ui/commit/2d2a714dafd22590e705c32a47cd5390ab96fdc5);
  all three arms ran on Gemini `gemini-flash-latest` at temperature 0.7, max
  4096 output tokens.
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
* Biggest hole for client-only apps: prompt generation exists only in a2ui's
  Python SDK and in genui for Flutter, so the React and Jaspr arms hand-wrote
  the instructions that teach the model to emit A2UI.
* Second hole: the web catalog cannot express a link, and `Text` does not render
  markdown links, so sending the user to a product page needs a host-side
  workaround on every web app.
* `@a2ui/react` 0.11.1 has packaging bugs: it advertises a stylesheet it does
  not ship, does not export the one it does, and depends on a core that stops at
  0.11.0.
