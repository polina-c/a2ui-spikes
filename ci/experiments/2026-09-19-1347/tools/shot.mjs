/**
 * Takes the two screenshots the write-up uses: the model picker, and the first
 * piece of UI the assistant generates.
 *
 * Usage: node tools/shot.mjs <kind> <url> <outDir> <name>
 */
import {chromium} from 'playwright';
import path from 'node:path';

const [kind, url, outDir, name] = process.argv.slice(2);
const KEY = process.env.GEMINI_API_KEY;
if (!KEY) throw new Error('GEMINI_API_KEY is not set.');

const beat = (ms) => new Promise(r => setTimeout(r, ms));
const b = await chromium.launch();
const p = await b.newPage({viewport: {width: 1280, height: 900}});

const press = async label => {
  if (kind === 'dom') await p.getByRole('button', {name: label}).click();
  else await p.locator('flt-semantics[role="button"]').filter({hasText: label}).first().evaluate(el => el.click());
};
const buttonCount = async () =>
  kind === 'dom'
    ? p.locator('.surface button').count()
    : p.locator('flt-semantics[role="button"]').count();

await p.goto(url, {waitUntil: 'networkidle'});
await beat(kind === 'flutter' ? 6000 : 2000);
await p.screenshot({path: path.join(outDir, `${name}-picker.png`)});

await p.locator('input[type=password]').fill(KEY);
await beat(1500);
await press('Start the chat');
await beat(kind === 'flutter' ? 3000 : 1500);
await press('Send');

const baseline = await buttonCount();
for (let i = 0; i < 120; i++) {
  await beat(1000);
  if ((await buttonCount()) > baseline) break;
}
await beat(2500);
await p.screenshot({path: path.join(outDir, `${name}-generated-ui.png`)});
console.log('shots saved');
await b.close();
