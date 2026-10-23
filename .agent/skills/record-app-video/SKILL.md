---
name: record-app-video
description: >
  Record a phone-size video of a simple chat app under simple_chat/apps going
  through its main flow, publish it to the binaries repo, and link it in the
  app's README. Use when asked to record, re-record or add a video of an app.
---

# Record an app video

Every app under `simple_chat/apps` has one video, linked from its README, of
the same flow at phone size, so the apps can be compared by watching. This
skill records it with [tools/record.mjs](tools/record.mjs), publishes it with
[tools/publish.sh](tools/publish.sh), and links it.

The driver is adapted from the CI one,
[cuj.mjs](../../../ci/experiments/2026-09-20-0155/tools/cuj.mjs). It works for
the Flutter apps, through their semantics tree, and for the React apps, whose
buttons carry the same names: Send, Pause, Resume, Cancel and "Send and
resume".

## The flow

Jane, described in [tools/persona.mjs](tools/persona.mjs), sends the default
prompt and answers the assistant's questions. When the assistant offers
options, she presses the one that fits her, and otherwise she types her
answer. After answering how many people eat at home, she pauses the answer,
adds that the kitchen is open to the living room, and resumes. The run ends
on the recommendation, and scrolls up through it and back.

To show more after the recommendation, pass `--then` with a message for Jane
to type, once per message.

## Steps

1. Check that the video can be published before recording it:
   `gh api repos/polina-c/a2ui-spikes-binaries --jq .permissions.push` must
   print `true`. If it does not, say so and stop.
2. Install the driver once, in [tools](tools): `npm install`. The Playwright
   version is pinned to the browser in `~/Library/Caches/ms-playwright`; if
   that browser is missing, `npx playwright install chromium-headless-shell`
   gets it.
3. Build the app for the web with the key, and serve it on 127.0.0.1, in the
   background:
   1. Flutter, from the app folder:
      `flutter build web --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY`, then
      `python3 -m http.server 8765 --bind 127.0.0.1` in `build/web`.
   2. React, from the app folder, with `GEMINI_API_KEY` set:
      `npm run build`, then `npx vite preview --host 127.0.0.1 --port 8765`.
4. Record into the app's `videos/chat.webm`, from the root of the repo:

   ```bash
   node .agent/skills/record-app-video/tools/record.mjs \
     http://127.0.0.1:8765 simple_chat/apps/<platform>/<app>/videos/chat.webm \
     --shots <scratchpad>/shots
   ```

   The driver prints each step: what the assistant offered and what Jane
   pressed or typed.
5. Check the recording before publishing it. Look at the screenshots in
   `--shots`, one per answer, and at frames around the pause, extracted with
   the ffmpeg that comes with Playwright:

   ```bash
   ~/Library/Caches/ms-playwright/ffmpeg-1011/ffmpeg-mac \
     -ss <seconds> -i <video> -frames:v 1 <frame>.png
   ```

   Record again if an answer failed, or if the run stopped before the
   recommendation.
6. Stop the server and delete the build, `build/web` or `dist`: it holds the
   key.
7. Publish: `.agent/skills/record-app-video/tools/publish.sh
   simple_chat/apps/<platform>/<app>/videos/chat.webm`. It commits the file to
   `main` of the binaries repo, at the same path, and waits until GitHub Pages
   serves it. See "Non-asset binaries" in the [coding skill](../coding/SKILL.md)
   for why videos live there.
8. Link the video in the app's README, under the first paragraph, the way
   [text_only](../../../simple_chat/apps/dart/text_only/README.md) does:

   ```markdown
   [Video](https://polina-c.github.io/a2ui-spikes-binaries/simple_chat/apps/<platform>/<app>/videos/chat.webm),
   at phone size: <what the video shows>.
   ```

   Describe what this recording shows, from the driver's log and the
   screenshots, not what the flow was meant to show. Replace the link if the
   README has one.

Write the link only after `publish.sh` prints `published`. A link to a file
that is not on Pages yet is a 404 that nobody notices until they click it.

`videos/*.webm` is ignored by git here, so the local copy stays out of this
repo.
