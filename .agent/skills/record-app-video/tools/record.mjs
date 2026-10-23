/**
 * Records a simple chat app going through its main flow, at phone size.
 *
 * Usage:
 *   node record.mjs <url> <out.webm> [--then <message>]... [--shots <dir>]
 *
 * Jane sends the default prompt and answers the assistant's questions as
 * persona.mjs describes: she presses the option the assistant offers when it
 * offers one, and types her answer otherwise. On one answer she pauses, adds
 * context and resumes. The run ends on the recommendation, after the messages
 * given with --then, if any, and scrolls up through it and back.
 *
 * Works for the Flutter apps, driven through their semantics tree, and for
 * the React apps, whose buttons carry the same names. --shots saves a
 * screenshot after each answer, to check the run without playing the video.
 *
 * Adapted from ci/experiments/2026-09-20-0155/tools/cuj.mjs.
 */
import {chromium} from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import {CONTROLS, LANDING, PERSONA, choose} from './persona.mjs';

const args = process.argv.slice(2);
const [url, out] = args;
if (!url || !out) {
  throw new Error('Usage: node record.mjs <url> <out.webm> [--then <message>]... [--shots <dir>]');
}
const then = args.flatMap((a, i) => (a === '--then' ? [args[i + 1]] : []));
const shotsDir = args.includes('--shots') ? args[args.indexOf('--shots') + 1] : null;

// The size of a phone, as in the other videos of these apps.
const size = {width: 390, height: 844};
const beat = (ms = 1200) => new Promise(r => setTimeout(r, ms));
const note = m => console.log(`${new Date().toISOString().slice(11, 19)} ${m}`);

// Playwright names the file itself, so it records into a directory of its own.
const recordDir = path.join(path.dirname(out), `.recording-${path.basename(out, '.webm')}`);
fs.rmSync(recordDir, {recursive: true, force: true});
fs.mkdirSync(recordDir, {recursive: true});
if (shotsDir) fs.mkdirSync(shotsDir, {recursive: true});

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: size,
  deviceScaleFactor: 1,
  recordVideo: {dir: recordDir, size},
});
const page = await context.newPage();

const button = name => page.getByRole('button', {name, exact: true});

/**
 * Presses the newest button named [name].
 *
 * Flutter's semantics nodes overlap, so a pointer click can land on another
 * node and be lost. A click dispatched on the node itself reaches the widget,
 * and it works the same on a React button.
 */
async function press(name) {
  await button(name).last().evaluate(el => el.click());
}

/** The names of the buttons on screen, without the app's own. */
async function options() {
  const names = await page
    .locator('button, [role="button"]')
    .evaluateAll(els => els.map(e => (e.getAttribute('aria-label') || e.textContent || '').trim()));
  return names.filter(n => n && !CONTROLS.test(n));
}

async function type(text) {
  await page.getByRole('textbox', {disabled: false}).last().click();
  // The field drops a key typed right after it takes focus.
  await beat(500);
  await page.keyboard.type(text, {delay: 35});
  await beat(600);
}

let shot = 0;

/**
 * Waits for the answer to finish, and resumes it if it failed.
 *
 * Gemini returns 503 under load often enough to spoil a recording, and a
 * failed answer is paused, so Resume tries it again.
 */
async function waitForAnswer() {
  for (let attempt = 1; ; attempt++) {
    await button('Pause').waitFor({timeout: 30000});
    await button('Pause').waitFor({state: 'detached', timeout: 180000});
    await beat(1000);
    if ((await button('Resume').count()) === 0 || attempt === 3) break;
    note('the answer failed, resuming');
    await press('Resume');
  }
  await beat(2500);
  if (shotsDir) await page.screenshot({path: path.join(shotsDir, `${String(++shot).padStart(2, '0')}.png`)});
}

async function send(text) {
  await type(text);
  await press('Send');
}

await page.goto(url, {waitUntil: 'networkidle'});
const placeholder = page.locator('flt-semantics-placeholder');
if ((await placeholder.count()) > 0) {
  // Turns on Flutter's semantics tree, so buttons can be found by name.
  await placeholder.evaluate(el => el.click());
}
await button('Send').waitFor({timeout: 30000});
await beat(2500);

note('sends the default prompt');
const seen = new Set(await options());
await press('Send');
await waitForAnswer();

const used = new Set();
for (let turn = 0; turn < 8; turn++) {
  const offered = (await options()).filter(o => !seen.has(o));
  offered.forEach(o => seen.add(o));
  if (offered.some(o => LANDING.test(o))) {
    note(`the assistant recommends, offering ${JSON.stringify(offered)}`);
    break;
  }

  let rule;
  if (offered.length > 0) {
    const choice = choose(offered, used);
    rule = choice.rule;
    const label = offered[Math.max(choice.index, 0)];
    note(`presses "${label}" of ${JSON.stringify(offered)}${rule ? ` (${rule.name})` : ', matching no rule'}`);
    await press(label);
  } else {
    rule = PERSONA.find(r => !used.has(r) && r.reply);
    // With nothing offered and nothing left to say, the last answer was the
    // recommendation.
    if (!rule) break;
    note(`types "${rule.reply}" (${rule.name})`);
    await send(rule.reply);
  }
  if (rule) used.add(rule);

  if (rule?.pause) {
    await button('Pause').waitFor({timeout: 30000});
    await beat(2500);
    note('pauses the answer');
    await press('Pause');
    await beat(2000);
    note(`adds "${rule.pause}" and resumes`);
    await type(rule.pause);
    await press('Send and resume');
  }
  await waitForAnswer();
}

for (const message of then) {
  note(`types "${message}"`);
  await send(message);
  await waitForAnswer();
}

// The last answer can be taller than the screen: scroll up through it and
// back down.
await page.mouse.move(size.width / 2, size.height / 2);
for (let i = 0; i < 12; i++) {
  await page.mouse.wheel(0, -120);
  await beat(250);
}
await beat(1500);
for (let i = 0; i < 12; i++) {
  await page.mouse.wheel(0, 120);
  await beat(250);
}
await beat(3000);

const video = await page.video().path();
await context.close();
await browser.close();
fs.renameSync(video, out);
fs.rmSync(recordDir, {recursive: true, force: true});
note(`saved ${out}`);
