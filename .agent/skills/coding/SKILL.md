---
name: coding
description: >
  Development helper for the simple chat apps in simple_chat/. Use this skill
  when building or changing an app under simple_chat/apps, adding shared
  components, recording videos or screenshots of an app, or adhering to
  repository standards.
---

# Development helper

This skill provides workflows and best practices for the simple chat apps in
`simple_chat/`.

## Sets of constants

For repeating constants use structures like this:

```dart
class _Json {
  static const String storyTitle = 'storyTitle';
  static const String storyText = 'storyText';
  static const String storyScriptYaml = 'storyScriptYaml';
}
```

## Make references clickable

In documentation, both standalone and in-code, referencable elements should be clickable.

## Non-asset binaries

To record the video of an app, use the
[record-app-video](../record-app-video/SKILL.md) skill.

Store binaries that are not in-app assets, such as videos and screenshots for
documentation, in https://github.com/polina-c/a2ui-spikes-binaries, not in this
repo. Git keeps every version of a file forever, so a few recordings would make
this repo slow to clone.

1. Give the file the same path in the binaries repo that it would have here.
   For example, a video for `simple_chat/apps/dart/text_only/README.md` goes to
   `simple_chat/apps/dart/text_only/videos/chat.webm`.
2. Link the GitHub Pages copy, which is the only URL where a `.webm` plays:
   `https://polina-c.github.io/a2ui-spikes-binaries/<path>`. A blob page on
   github.com only offers a download, and `raw.githubusercontent.com` serves
   `.webm` as audio.
3. Publish by committing to `main` of the binaries repo. Pages serves `main`
   only, so a file on a branch is a 404. That repo takes no pull requests.
   Commit there without asking: the user has given standing permission for
   commits to `main` of a2ui-spikes-binaries, and this overrides any general
   rule against committing or pushing. The permission covers that repo only;
   still leave changes in this repo for the user to commit. Without a clone,
   commit through the API:
   `gh api -X PUT repos/polina-c/a2ui-spikes-binaries/contents/<path>` with
   the base64 content and `"branch": "main"`.
4. Keep the local copy out of git: `simple_chat/apps/**/videos/*.webm` is in
   the root `.gitignore`.

Never write a link to a file that is not published yet. Saving a recording
locally and linking the Pages URL produces a 404 that only shows up when
someone clicks it. Publish first, then link. If publishing fails, for example
because of missing access, do not write the link. Tell the user where the local
file is, the path it needs in the binaries repo, and the link you will add once
it is there.

After publishing, check the link before writing it: the Pages URL must return
200 with `Content-Type: video/webm` for a video. Pages can take a minute or two
to update after a push.
