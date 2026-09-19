/**
 * Drives the primary CUJ and records it.
 *
 * Jane has a plumbed kitchen with a 60 cm gap, a household of two, no open-plan
 * noise problem, and she cares about what the machine costs to run rather than
 * what it costs on the day. Following the knowledge base, that is the Eco.
 *
 * Usage: node cuj.mjs <url> <videoDir> <name>
 */
import {chromium} from 'playwright';
import fs from 'node:fs';
import path from 'node:path';

const [url, videoDir, name] = process.argv.slice(2);
const KEY = process.env.GEMINI_API_KEY;
if (!KEY) throw new Error('GEMINI_API_KEY is not set.');

const size = {width: 1280, height: 900};
const beat = (ms = 1200) => new Promise(r => setTimeout(r, ms));

// What Jane answers, in the order the knowledge base asks.
const ANSWERS = [
  {
    want: /under[- ]?the[- ]?counter|under[- ]?counter|plumb|built|permanent|water line/i,
    avoid: /countertop|counter top|renting|portable|tank|no plumbing/i,
  },
  {want: /\b60\b/, avoid: /\b45\b/},
  {
    want: /once a day|1 to 4|1-4|\btwo\b|\bthree\b|couple|small|fewer|normally/i,
    avoid: /5\+|5 or more|\bfive\b|twice|lots of cooking|large/i,
  },
  {
    want: /\bno\b|not really|closed|separate|daytime|during the day/i,
    avoid: /\byes\b|open to|night|bedroom|living/i,
  },
  {
    want: /water|energy|power|running|consum|efficien|afterwards|bills|long run|later/i,
    avoid: /price|cheapest|upfront|on the day|budget|today/i,
  },
];

const LANDING = /see|view|open|learn more|landing|page|details|buy|shop/i;

const browser = await chromium.launch();
const context = await browser.newContext({viewport: size, recordVideo: {dir: videoDir, size}});
const page = await context.newPage();

const log = [];
const note = m => { log.push(m); console.log(m); };

await page.goto(url, {waitUntil: 'networkidle'});
await beat(2000);

// Step 2 and 3: the app opens on the model picker with defaults already chosen.
note('opened the app on the model picker');
await page.locator('input[type=password]').fill(KEY);
await beat(1500);
await page.getByRole('button', {name: 'Start the chat'}).click();
note('accepted the default model and started the chat');
await beat(1500);

// Steps 4 and 5: the default prompt is already in the box.
const draft = await page.locator('.composer input').inputValue();
note(`default prompt in the box: ${JSON.stringify(draft)}`);
await beat(1200);
await page.getByRole('button', {name: 'Send'}).click();

/** Waits until the assistant has drawn a surface we have not seen yet. */
async function waitForNewSurface(seen) {
  await page.waitForFunction(
    c => document.querySelectorAll('.surface').length > c,
    seen,
    {timeout: 180000},
  );
  await beat(1800);
}

/**
 * Picks Jane's answer by matching the rules against the options on screen,
 * rather than by counting turns. A rule only applies when it singles out
 * exactly one option, so a rule meant for a different question stays out of
 * the way and the order the assistant asks in does not matter.
 */
function choose(labels) {
  for (const rule of ANSWERS) {
    const hits = labels
      .map((l, i) => [l, i])
      .filter(([l]) => rule.want.test(l) && !rule.avoid.test(l));
    if (hits.length === 1) return hits[0][1];
  }
  return -1;
}

let landed = false;
let seen = 0;
for (let step = 0; step < 8 && !landed; step++) {
  try {
    await waitForNewSurface(seen);
  } catch {
    const said = await page.locator('.entry.assistant .bubble:not(.pending)').last().innerText().catch(() => '(none)');
    note(`step ${step}: the assistant drew nothing new. It said: ${said.slice(0, 400)}`);
    break;
  }
  seen = await page.locator('.surface').count();

  const buttons = page.locator('.surface').last().locator('button');
  const count = await buttons.count();
  if (count === 0) { note(`step ${step}: the new surface has no buttons, stopping`); break; }

  const labels = [];
  for (let i = 0; i < count; i++) labels.push((await buttons.nth(i).innerText()).trim());
  note(`step ${step}: options ${JSON.stringify(labels)}`);

  const landingIndex = labels.findIndex(l => LANDING.test(l));
  if (landingIndex !== -1) {
    note(`step ${step}: pressing the landing page button "${labels[landingIndex]}"`);
    const [popup] = await Promise.all([
      context.waitForEvent('page', {timeout: 20000}).catch(() => null),
      buttons.nth(landingIndex).click(),
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

  let pick = choose(labels);
  if (pick === -1) { note(`step ${step}: no rule matched, taking the first option`); pick = 0; }
  note(`step ${step}: Jane presses "${labels[pick]}"`);
  await buttons.nth(pick).click();
  await beat(1200);
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
