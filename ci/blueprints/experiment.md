# Simple chat experiment

[a2ui]: https://github.com/a2ui-project/a2ui
[simple_chat_blueprint]: simple_chat.md
[inventory]: ../experiments/inventory.md
[binaries]: https://github.com/polina-c/a2ui-spikes-binaries
[recordings]: https://polina-c.github.io/a2ui-spikes-binaries/

## Goal

This experiment aims to evaluate [a2ui] readiness for implementing applications enhanced with generated UI.

## Steps 

### 1. Setup

Create an experiment folder '<date>-<time>' with a README.md that describes the experiment details: 

- link to the used commit of a2ui
- used model name
- used model parameters (if any)

### 2. Generate

Generate a simple chat application following the [simple chat blueprint][simple_chat_blueprint] for three UI frameworks: React, Flutter and Jaspr.

Put the generated code into a `<ui-framework>` subdirectory. The subdirectory
should contain README.md with steps to start the app.

### 3. Evaluate

Execute the primary CUJ once for each combination of UI framework and model
family: Gemini and the in-browser model, against each of React, Flutter and
Jaspr. That is six runs. Record a video of each and write it into the 'videos'
subdirectory as `<framework>-<family>.webm`.

Both families are recorded every run, because they answer different questions.
Gemini shows a2ui against the kind of model it was designed around. The
in-browser model runs on the machine with no key and is much smaller, so it
shows whether the generated UI survives a weak generator. Recording only Gemini
answers the easy half. Never substitute one family for the other.

Record every arm, including one that does not work. An arm that fails is a
result: the video of it failing shows how far it got and what the user was
looking at when it stopped, and that is the evidence for the finding. Keep the
recording, say in the README where it stopped and why, and label it as a failed
arm so nobody takes it for a working one. The only run with no video is one that
never started.

Put your observations and link to the corresponding video into the experiment README.md.

### 4. Move the media to the binaries repo

No images or videos are committed to this repo. They go to the
[binaries repo][binaries], so that cloning this one stays fast. Git keeps every
version of a file forever, and a run a week that adds megabytes of recordings
makes the repo slow for good.

That repo is published with GitHub Pages as the [recordings site][recordings],
because a video committed to a repo cannot be played on github.com at all.

Push each video and screenshot to [binaries][binaries] at the same path it had
here, delete it here, and add a gallery page for the experiment at
`ci/experiments/<date>-<time>/index.html` that plays the arms side by side. A
failed arm is published like any other, marked as failed on the gallery page and
in the inventory.
The site has one shared `style.css`, so the page is markup only.

Link the served copy, never a github.com or raw URL:

```
https://polina-c.github.io/a2ui-spikes-binaries/<path>
```

Push before writing the link, and check that the link resolves. A link to a file
that was never pushed looks exactly like a working one until someone clicks it,
and Pages takes a moment to redeploy after a push.

Text stays here. The CUJ logs are small and worth reading in a diff.

### 5. Add to inventory.

Add short description of the experiment and link to the experiment README.md into the [inventory][inventory].

Use H2 header "<date>-<time>" for each experiment. 
Create table with one row per arm, that is per combination of framework and model
family, showing the model family, link to the video, link to the README.md of the
framework and its line count.
Use bullet points for the experiment details and findings.


