# Regular run

[experiment]: experiment.md
[skill]: ../skills/run-simple-chat-experiment/SKILL.md
[inventory]: ../experiments/inventory.md
[repo]: https://github.com/polina-c/a2ui-spikes

## Goal

Run the [simple chat experiment][experiment] every week without anyone starting
it, and open a pull request with the results, to evaluate a2ui parameters.

## Where it runs

GitHub Actions in [the repo][repo], against its own `main`. The results are a
branch and a PR in the same repo, so no cross-repo token is needed.

The git remote still points at `polina-c/a2ui4w`, which is the repo's old name
and works only through GitHub's redirect. Update it to `a2ui-spikes` before
relying on it from a workflow.

## Schedule

Weekly, on a fixed day and hour in UTC, plus a manual trigger so a run can be
started by hand without waiting for the schedule.

Two things about scheduled workflows to design around. GitHub disables them
after 60 days without activity in the repo, and a merged PR every week is
usually enough to prevent that, but a quiet month is not. And scheduled runs are
delayed when the runners are busy, so the folder name must come from the clock
at the start of the run, never from the schedule.

Only one run at a time. If a run is still going, or an experiment PR from a
previous week is still open, do not start another one: two runs both editing the
[inventory][inventory] produce a conflict, and the second PR is written against
findings nobody has read yet.

## Steps

### 1. Prepare the environment

The run needs Node, Flutter (which brings Dart), the Jaspr CLI, Playwright with
Chromium, and something to serve a built directory over HTTP. It does not need
ffmpeg.

It needs two API keys as repository secrets: one for the model the apps call,
and one for the coding agent that builds them. The job also needs permission to
push a branch and open a pull request.

Neither key may reach the results. They are typed into the app at runtime, never
compiled into a build, and never written to a log, a video or a committed file.

The experiment was developed on macOS. Flutter web and headless Chromium both
work on Linux runners, but the first automated run is the one that finds out
what differs, so expect to fix it rather than to inherit it working.

### 2. Run the experiment

Run the [skill][skill], which carries the procedure and what previous runs
learned.

This step is a coding agent building three applications, not a script executing.
Two runs of the same blueprint will not produce the same code, and that is the
measurement, not noise in it. Nothing in the run should try to make the output
reproducible.

Do not pin the a2ui commit. Take whatever `main` is at the time and record it,
because a version that moves is the thing being watched. Record the model the
same way, including the version an alias resolved to, since an alias moves
without any change here.

### 3. Open the pull request

One branch and one PR per run, named for the experiment folder.

The PR contains the new experiment folder and the updated [inventory][inventory]
entry, and nothing else. Its description is the inventory entry for the run:
the table, the details and the findings, so the whole result can be read without
opening a file.

It is a pull request and not a push to `main` because the findings are prose
written by a model about software it just used, and somebody should read them
before they become the record.

### 4. Report what happened

An arm that fails is a result. Record how far it got and why, keep the arms that
worked, and open the PR.

A run that could not start is not a result. If a secret is missing, the
toolchain will not install, or the agent never ran, fail the job, say so, and do
not open a pull request. An empty or invented experiment in the inventory is
worse than a week with no entry.

## Videos

Each run records about 15 MB of video, and the repo is already around 40 MB.
Committing them every week adds most of a gigabyte a year to a repository whose
text is a few hundred kilobytes, and git keeps every copy forever.

Decide where videos live before the first automated run, not after. Moving them
later means rewriting history, and the links in old inventory entries are what
breaks.

Attaching them to a release per run keeps them permanent, keeps them out of the
git history, and leaves the inventory linking to a stable URL. Git LFS also
works and is simpler to set up, at the cost of a quota. Plain workflow artifacts
are the one option to avoid: they expire, and an inventory is meant to be read
years later.

Whichever is chosen, the rule from the experiment still holds: the inventory
never links to a video that does not exist.

## Cost

A run builds three applications and holds several model conversations, so it
spends real money on two APIs every week, and takes long enough that the job
needs a generous timeout and a ceiling that stops a stuck run from spending all
day.

If that turns out to be too much for weekly, the thing to reduce is frequency,
not scope. Three arms run monthly still show the trend. One arm run weekly only
shows whether React broke.
