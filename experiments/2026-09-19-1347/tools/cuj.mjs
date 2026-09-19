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

const [kind, url, videoDir, name] = process.argv.slice(2);
const KEY = process.env.GEMINI_API_KEY;
if (!KEY) throw new Error('GEMINI_API_KEY is not set.');
if (!['dom', 'flutter'].includes(kind)) throw new Error(`unknown kind: ${kind}`);

const size = {width: 1280, height: 900};
const beat = (ms = 1200) => new Promise(r => setTimeout(r, ms));

const browser = await chromium.launch();
const context = await browser.newContext({viewport: size, recordVideo: {dir: videoDir, size}});
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

async function clickLabel(label) {
  if (kind === 'dom') {
    await page.locator('.surface').last().locator('button', {hasText: label}).first().click();
  } else {
    // Flutter's semantics nodes sit on top of each other, so a parent is
    // usually "intercepting pointer events" by Playwright's reckoning. The
    // click still reaches Flutter, so the check is skipped.
    await page.locator('flt-semantics[role="button"]').filter({hasText: label.split('\n')[0]}).first().click({force: true});
  }
}

async function clickByName(label) {
  if (kind === 'dom') await page.getByRole('button', {name: label}).click();
  else await page.locator('flt-semantics[role="button"]').filter({hasText: label}).first().click({force: true});
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

/** Waits until the assistant is offering a set of options we have not answered. */
async function waitForNewOptions(previous, timeout = 180000) {
  const deadline = Date.now() + timeout;
  const before = JSON.stringify(previous);
  while (Date.now() < deadline) {
    const now = await options();
    if (now.length > 0 && JSON.stringify(now) !== before) return now;
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
let previous = [];
for (let step = 0; step < 8 && !landed; step++) {
  let labels;
  try {
    labels = await waitForNewOptions(previous);
  } catch {
    note(`step ${step}: the assistant drew nothing new, stopping`);
    break;
  }
  previous = labels;
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
      note(`landing page opened: ${popup.url()}`);
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

// Give the recording its final name.
const files = fs.readdirSync(videoDir).filter(f => f.endsWith('.webm'));
files.sort((a, b) => fs.statSync(path.join(videoDir, b)).size - fs.statSync(path.join(videoDir, a)).size);
if (files[0]) {
  fs.renameSync(path.join(videoDir, files[0]), path.join(videoDir, `${name}.webm`));
  for (const f of files.slice(1)) fs.unlinkSync(path.join(videoDir, f));
  note(`video saved as ${name}.webm`);
}
fs.writeFileSync(path.join(videoDir, `${name}-cuj.log`), log.join('\n') + '\n');
console.log(landed ? 'CUJ COMPLETE' : 'CUJ INCOMPLETE');
