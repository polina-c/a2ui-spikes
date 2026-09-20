# Configuring the weekly run

[blueprint]: ../blueprints/ci.md
[experiment]: ../blueprints/experiment.md
[skill]: ../skills/run-simple-chat-experiment/SKILL.md
[inventory]: ../experiments/inventory.md
[a2ui-spikes]: https://github.com/polina-c/a2ui-spikes
[binaries]: https://github.com/polina-c/a2ui-spikes-binaries
[recordings]: https://polina-c.github.io/a2ui-spikes-binaries/
[routines]: https://claude.ai/code/routines
[routines-doc]: https://code.claude.com/docs/en/routines
[environments-doc]: https://code.claude.com/docs/en/cloud-environments
[allowlist]: https://code.claude.com/docs/en/cloud-environments#default-allowed-domains
[github-app]: https://github.com/apps/claude

How to set up the weekly run described in [the CI blueprint][blueprint]. You do
this once, in a browser, and then read a pull request every week.

The mechanism is a [routine][routines-doc]: a saved prompt, a set of
repositories and a cloud environment, started by a trigger and run as a full
Claude Code session on Anthropic's infrastructure. One weekly schedule trigger
is all this needs. Routines are a research preview on the Pro, Max, Team and
Enterprise plans, so the names of the fields below may drift.

A routine belongs to one claude.ai account and acts as that account. The
branches, the commits and the pull request all carry your GitHub user.

## Before you start

You need a paid claude.ai plan with cloud sessions and routines enabled, and a
Gemini API key.

Cloud sessions reach GitHub through a proxy that keeps your credentials out of
the container, but you have to connect GitHub first. Either install the
[Claude GitHub App][github-app] on both repositories, or run `/web-setup` in a
terminal session to hand your `gh` token to your account. The run clones
[a2ui-spikes][a2ui-spikes] and pushes to it, and does the same with
[a2ui-spikes-binaries][binaries], so both have to be reachable.

The videos go in the binaries repository, not this one. `.gitignore` keeps
`*.webm` and `*.png` out of `ci/experiments/*/videos/`. A weekly run that
committed its recordings here would add most of a gigabyte a year to a
repository whose text is a few hundred kilobytes.

That repository is published with GitHub Pages as the [recordings site][recordings],
because a video committed to a repository cannot be played on github.com: the
blob page only offers a download, and a raw link serves `.webm` as `audio/webm`,
which plays the sound of a screen recording and shows no picture. The links in
the [inventory][inventory] point at the Pages origin for that reason. Each run
also adds a gallery page for its experiment, so the three arms can be watched
side by side. Pages is already enabled, on `main` at the repository root.

## Step 1: the cloud environment

The environment decides what the run can reach, what is installed, and what
secrets it holds. Create one at [claude.ai/code][routines] from the environment
selector rather than reusing Default, because this one needs a network change
and a key.

### Network access

Set network access to Custom, keep the box that includes the default list of
common package managers, and add one domain:

```text
cdn.playwright.dev
```

The [default list][allowlist] already covers everything else the run touches:
`github.com` for the a2ui checkout, `registry.npmjs.org` for the React arm,
`pub.dev` and `api.pub.dev` for the Dart packages, `storage.googleapis.com` for
the Flutter SDK download, and `*.googleapis.com`, which is how the apps reach
`generativelanguage.googleapis.com` to call Gemini. Playwright fetches Chromium
from its own CDN, which is not on that list, and a request to a host outside
the allowlist fails with a `403`.

### The Gemini key

Add an environment variable:

```text
GEMINI_API_KEY=<your key>
```

Anyone who can use the environment can read that value. Pro and Max plans also
offer API credentials, which keep a key outside the VM and attach it to
outbound requests, but that does not fit here: the apps read the key themselves
and one of them is a browser that a Playwright driver types it into. The key
has to be inside the container, so an environment variable is the right place
for it. Use a key you are willing to rotate, and keep it out of anything the
run commits.

### The setup script

Node 22, npm, git, `gh`, `jq` and ripgrep are on the image already. Flutter is
not, and neither is Chromium. A setup script installs them:

```bash
#!/bin/bash
# Flutter (which brings Dart), the Jaspr CLI, and Chromium for Playwright.

git clone --depth 1 -b stable https://github.com/flutter/flutter /opt/flutter
ln -sf /opt/flutter/bin/flutter /opt/flutter/bin/dart /usr/local/bin/

# Cloned as root. Without this, every flutter call dies on git's ownership
# check if Claude runs as anyone else.
git config --global --add safe.directory /opt/flutter

flutter config --enable-web || echo "SETUP WARNING: flutter config failed"
flutter precache --web || echo "SETUP WARNING: flutter precache failed"

dart pub global activate jaspr_cli || echo "SETUP WARNING: jaspr_cli failed"
ln -sf /root/.pub-cache/bin/jaspr /usr/local/bin/ || true

# Split, because the two halves fail for different reasons: the deps step is
# apt and needs the distro mirrors, the download step needs cdn.playwright.dev.
npx --yes playwright@1.49 install-deps chromium || echo "SETUP WARNING: chromium system deps failed; the browser may not launch"
npx --yes playwright@1.49 install chromium || echo "SETUP WARNING: chromium download failed"

echo "SETUP: done"
flutter --version || echo "SETUP WARNING: flutter missing"
dart --version || echo "SETUP WARNING: dart missing"

exit 0
```

That script has not been run yet. It is a starting point, and the first run is
where you find out what it gets wrong; the experiment was developed on macOS
and these are Linux containers.

Three things constrain it. It must exit zero, or the session fails to start,
which is why nothing optional is allowed to fail the script. It should finish
in about five minutes. And it symlinks the binaries into `/usr/local/bin`
instead of adding them to `PATH`, because the script runs as root before Claude
Code launches and its `PATH` does not carry into the shell that Claude runs
commands in.

Exiting zero is what makes the script dangerous to read a green tick from, so
each step that is allowed to fail says so on its way past rather than going
quiet. Search the setup log for `SETUP WARNING` before trusting a run. The
version checks at the end are there to turn "Flutter is missing" into one line
near the bottom of the log instead of a puzzling failure twenty minutes later.

`playwright install --with-deps` is split in two on purpose. The deps half
shells out to `apt-get`, which needs the Debian mirrors rather than
`cdn.playwright.dev`, so if those hosts are not on your allowlist that half
fails while the download half succeeds, and Chromium lands without the shared
libraries it needs to start.

The five minutes matter more here than they would elsewhere. After the script
succeeds the filesystem is snapshotted and later sessions skip it, but the
snapshot is rebuilt when you edit the script, when you change the allowed
hosts, and when it expires after roughly seven days. At a weekly cadence most
runs will pay for the script rather than reuse the snapshot.

## Step 2: the routine

Go to [claude.ai/code/routines][routines] and click New routine.

Give it a name, and pick the model in the selector above the prompt box. The
run uses that model on every run, and it is the model that writes the three
applications, so the [experiment README][experiment] records it. It is not the
model the apps themselves call: that one is Gemini, chosen in the blueprint.

Add both repositories, [a2ui-spikes][a2ui-spikes] and
[a2ui-spikes-binaries][binaries]. Each is cloned at the start of every run from
its default branch.

Select the environment from step 1.

Under Connectors, remove all of them. Every connector left in the list is a set
of tools the session can call without asking, and this run needs none.

For the trigger, choose Schedule and then Weekly, with a day and hour. Times
are entered in your own zone and converted for you. Runs start a few minutes
after the hour you pick, by an offset that stays the same for the routine,
which does not matter here because the experiment folder is named from the
clock when the run starts rather than from the schedule.

## Step 3: the prompt

Paste this into the instructions box.

```text
Run one round of the simple chat experiment in the polina-c/a2ui-spikes
repository, then open a pull request with the result.

Read ci/skills/run-simple-chat-experiment/SKILL.md first and follow it. It is
the procedure, and it carries what previous runs learned. The specs it points
at are ci/blueprints/experiment.md and ci/blueprints/simple_chat.md, and the
domain knowledge is ci/domain/knowledge.md with the landing pages beside it.

For this environment:

* Take a2ui from whatever its main branch is at the time of the run and record
  the commit. It is the moving version that is being watched, so do not reuse
  a commit named in the skill.
* GEMINI_API_KEY is set. The apps read it. It must not reach a committed file,
  a log, or a recording.
* Videos and screenshots do not belong in this repository; .gitignore keeps
  them out. Commit the CUJ logs here, and push the recordings to
  polina-c/a2ui-spikes-binaries under ci/experiments/<date>-<time>/videos/,
  together with the experiment's gallery page.
* That binaries repository is a GitHub Pages site served from main at the
  repository root, so push it straight to main with `git push origin HEAD:main`
  rather than to a claude/ branch, and do not open a pull request against it.
  Nothing is published until it is on main, so a link written before that push
  has landed is a link to a 404. Check one URL after pushing.
* Link every recording through https://polina-c.github.io/a2ui-spikes-binaries/,
  never a github.com or raw URL. The skill has the detail.
* Write the experiment README and the inventory entry before opening the pull
  request.

Open the pull request against main in polina-c/a2ui-spikes with gh pr create,
from a claude/ branch named for the experiment folder. The description is the
inventory entry for this run, the table and the details and the findings, so
the result can be read without opening a file.

An arm that fails is a result: record how far it got and why, keep the arms
that worked, and open the pull request. A run that could not start is not a
result: if the toolchain is missing or the key is rejected, stop and say so
rather than opening a pull request for an experiment that did not happen.
```

The prompt names the skill by path on purpose. A cloud session picks up skills
committed under `.claude/skills/` in a cloned repository, and this repository
keeps [its skill][skill] at `ci/skills/`, so nothing loads it on its own. If
you would rather have it loaded automatically, move it under `.claude/skills/`
and then the prompt only has to ask for the experiment by name.

Everything else in the prompt is there because the run is autonomous. It gets
the saved prompt as its task and nothing else: no conversation, no chance to
ask you what you meant, and no memory of last week.

## Step 4: the first run

Click Run now rather than waiting for the schedule, and watch it.

A green status in the run list means the session started and exited without an
infrastructure error. It does not mean the experiment worked. Open the run and
read the transcript: blocked network requests, a setup script that half
succeeded, and an arm that was quietly abandoned all show up there and nowhere
else.

Worth checking on the first run: that the setup log has no `SETUP WARNING` in
it, that `flutter`, `dart`, `jaspr` and Chromium are all present, that nothing
hit a `403`, that a `claude/` branch was pushed to both repositories, that the
new gallery page plays its three videos on the [recordings site][recordings],
and that the pull request exists and reads like the inventory entry.

If something in the environment was wrong, fix it and run again. Editing the
setup script or the allowed hosts rebuilds the snapshot on the next run.

## Living with it

The pull request is the output, and reading it is the point. The findings are
prose written by a model about software it has just used, so somebody should
read them before they become the record.

Do not let two runs overlap. The routine has no memory of previous runs, and
two of them editing the [inventory][inventory] produce a conflict. If last
week's pull request is still open when the next run starts, expect to resolve
one by hand. Pause the routine with the switch on its detail page if the
backlog gets ahead of you.

The skill asks each run to re-check its own notes about what a2ui ships and
update them, so a pull request that changes the skill as well as adding an
experiment is working as intended.

If your GitHub connection expires, the routine skips its runs for up to 72
hours and then turns itself off. Reconnect and switch it back on.

Routines draw down the same subscription usage as any other session, and they
have a separate daily cap on how many runs can start. One run a week is not
close to it.

## What this does not do

The routine does not retry. A run that dies leaves a session you can open and
continue by hand, and no pull request.

A full round builds three applications and records three CUJs, which is a long
autonomous session and the part of this setup most likely to need adjusting.
If the runs keep coming apart under their own length, reduce the frequency
rather than the scope. Three arms monthly still show the trend. One arm weekly
only shows whether React broke.
