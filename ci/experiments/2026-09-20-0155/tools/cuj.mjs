/**
 * Drives the primary CUJ against one arm and records it.
 *
 * Usage: node tools/cuj.mjs <kind> <url> <videoDir> <name>
 *   kind: "dom" for the React and Jaspr arms, which render real elements,
 *         "flutter" for the Flutter arm, which paints a canvas and is driven
 *         through its semantics tree instead.
 */
import {chromium} from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import {choose, LANDING, PRODUCT, CHROME} from './answers.mjs';
import {LAUNCH} from './launch.mjs';

const [kind, url, videoDir, name] = process.argv.slice(2);
const KEY = process.env.GEMINI_API_KEY;
if (!KEY) throw new Error('GEMINI_API_KEY is not set.');
if (!['dom', 'flutter'].includes(kind)) throw new Error(`unknown kind: ${kind}`);

const size = {width: 1280, height: 900};
const beat = (ms = 1200) => new Promise(r => setTimeout(r, ms));

// Record into a directory of its own. Playwright names the file itself, and
// picking it out of a shared folder afterwards risks grabbing, or deleting,
// another arm's recording.
const recordDir = path.join(videoDir, `.recording-${name}`);
fs.rmSync(recordDir, {recursive: true, force: true});
fs.mkdirSync(recordDir, {recursive: true});

const browser = await chromium.launch(LAUNCH);
const context = await browser.newContext({viewport: size, recordVideo: {dir: recordDir, size}});
const page = await context.newPage();

const log = [];
const note = m => { log.push(m); console.log(m); };

/** The options the assistant is currently offering, without the app's own buttons. */
async function options() {
  const labels = kind === 'dom'
    ? await page.locator('.surface').last().locator('button').allInnerTexts()
    : await page.evaluate(() =>
        Array.from(document.querySelectorAll('flt-semantics[role="button"]'))
          .map(e => (e.getAttribute('aria-label') || e.textContent || '').trim())
          .filter(Boolean));
  return labels.map(l => l.trim()).filter(l => l && !CHROME.test(l));
}

/** The last thing the assistant said in words, error bubbles included. */
async function lastSaid() {
  if (kind === 'dom') {
    return page.locator('.entry.assistant .bubble').last().innerText().catch(() => '');
  }
  return questionText();
}

/** What the assistant is asking, used to pick which answer rule applies. */
async function questionText() {
  if (kind === 'dom') {
    const said = await page.locator('.entry.assistant .bubble:not(.pending)').last().innerText().catch(() => '');
    const drawn = await page.locator('.surface').last().innerText().catch(() => '');
    return `${said}\n${drawn}`;
  }
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('flt-semantics'))
      .filter(e => e.getAttribute('role') !== 'button')
      .map(e => (e.getAttribute('aria-label') || e.textContent || '').trim())
      .join('\n'));
}

/**
 * Presses a Flutter button through its semantics node.
 *
 * Flutter's semantics nodes overlap, so a real pointer click lands on whichever
 * node is on top and is lost. Dispatching the click on the node itself is the
 * path a screen reader uses, and it reaches the widget.
 */
async function flutterPress(label) {
  await page
    .locator('flt-semantics[role="button"]')
    .filter({hasText: label})
    .first()
    .evaluate(el => el.click());
}

async function clickLabel(label) {
  if (kind === 'dom') {
    await page.locator('.surface').last().locator('button', {hasText: label}).first().click();
  } else {
    await flutterPress(label.split('\n')[0]);
  }
}

async function clickByName(label) {
  if (kind === 'dom') await page.getByRole('button', {name: label}).click();
  else await flutterPress(label);
}

async function hasButton(label) {
  if (kind === 'dom') return (await page.getByRole('button', {name: label}).count()) > 0;
  return (await page.locator('flt-semantics[role="button"]').filter({hasText: label}).count()) > 0;
}

/**
 * Presses a button and checks the screen actually changed.
 *
 * On Flutter the press goes through a semantics node layered over the canvas,
 * and a press sent before the tree has settled is silently dropped, so it is
 * worth confirming rather than assuming.
 */
async function pressUntil(label, expected, tries = 5) {
  for (let i = 0; i < tries; i++) {
    if (await hasButton(label)) await clickByName(label);
    for (let waited = 0; waited < 6; waited++) {
      await beat(1000);
      if (await hasButton(expected)) return;
    }
    note(`"${label}" did not bring up "${expected}", pressing again`);
  }
  throw new Error(`pressing "${label}" never produced "${expected}"`);
}

/**
 * Waits for options the assistant has not offered before.
 *
 * The chat is a transcript, so earlier turns stay on screen and their buttons
 * stay in the tree. Only labels that have not been seen belong to the question
 * being asked now.
 */
async function waitForNewOptions(seen, timeout = 180000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const fresh = (await options()).filter(l => !seen.has(l));
    if (fresh.length > 0) {
      // Let the rest of the turn arrive before reading it.
      await beat(1200);
      const settled = (await options()).filter(l => !seen.has(l));
      return settled.length > 0 ? settled : fresh;
    }
    await beat(1000);
  }
  throw new Error('timed out waiting for the assistant to draw something new');
}

await page.goto(url, {waitUntil: 'networkidle'});
await beat(kind === 'flutter' ? 6000 : 2000);

// Steps 2 and 3: the app opens on the model picker with the defaults chosen.
note('opened the app on the model picker');
await page.locator('input[type=password]').fill(KEY);
await beat(1500);
await pressUntil('Start the chat', 'Send');
note('accepted the default model and started the chat');
await beat(kind === 'flutter' ? 2500 : 1500);

// Steps 4 and 5: the default prompt is already in the box.
if (kind === 'dom') {
  note(`default prompt in the box: ${JSON.stringify(await page.locator('.composer input').inputValue())}`);
}
await beat(1200);
await clickByName('Send');
note('sent the default prompt');

let landed = false;
const seen = new Set();
for (let step = 0; step < 8 && !landed; step++) {
  let labels;
  try {
    labels = await waitForNewOptions(seen);
  } catch {
    // Say what was on screen when it stopped: an error bubble here is the
    // difference between "the model refused" and "the driver missed it".
    const last = await lastSaid();
    note(`step ${step}: the assistant drew nothing new, stopping. Last it said: ${JSON.stringify(last.slice(0, 400))}`);
    break;
  }
  for (const l of labels) seen.add(l);
  note(`step ${step}: options ${JSON.stringify(labels)}`);

  const landingIndex = labels.findIndex(l => LANDING.test(l) || PRODUCT.test(l));
  if (landingIndex !== -1) {
    note(`step ${step}: pressing the landing page button "${labels[landingIndex]}"`);
    const [popup] = await Promise.all([
      context.waitForEvent('page', {timeout: 20000}).catch(() => null),
      clickLabel(labels[landingIndex]),
    ]);
    await beat(1500);
    if (popup) {
      await popup.waitForLoadState('domcontentloaded').catch(() => {});
      await beat(3000);
      await popup.screenshot({path: path.join(videoDir, `${name}-landing.png`)});
      // The title is in the log because a page that failed to load still
      // counts as a tab opening; a 404 here is a failed last CUJ step.
      note(`landing page opened: ${popup.url()} (title: ${JSON.stringify(await popup.title())})`);
    } else {
      note('no landing page tab opened');
    }
    landed = true;
    break;
  }

  const question = await questionText();
  let {index: pick, rule} = choose(labels, question);
  if (pick === -1) { note(`step ${step}: no rule matched, taking the first option`); pick = 0; }
  note(`step ${step}: Jane presses "${labels[pick]}"${rule ? ` (rule: ${rule})` : ''}`);
  await clickLabel(labels[pick]);
  await beat(1500);
}

await beat(2500);
await context.close();
await browser.close();

// Move this run's recording out and drop the directory it was written to.
const recorded = fs.readdirSync(recordDir).filter(f => f.endsWith('.webm'));
recorded.sort((a, b) => fs.statSync(path.join(recordDir, b)).size - fs.statSync(path.join(recordDir, a)).size);
if (recorded[0]) {
  fs.renameSync(path.join(recordDir, recorded[0]), path.join(videoDir, `${name}.webm`));
  note(`video saved as ${name}.webm`);
} else {
  note('no video was recorded');
}
fs.rmSync(recordDir, {recursive: true, force: true});
fs.writeFileSync(path.join(videoDir, `${name}-cuj.log`), log.join('\n') + '\n');
console.log(landed ? 'CUJ COMPLETE' : 'CUJ INCOMPLETE');
