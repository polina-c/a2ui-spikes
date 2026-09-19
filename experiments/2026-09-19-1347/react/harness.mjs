import fs from 'node:fs';
import path from 'node:path';
import {MessageProcessor} from '@a2ui/web_core/v0_9';
import {basicCatalog} from '@a2ui/web_core/v0_9/basic_catalog';
import {buildSystemPrompt} from './build-prompt/prompt.js';

const ROOT = '/Users/polina/_/a2ui4w';
const read = p => fs.readFileSync(path.join(ROOT, p), 'utf8');
const pages = ['classic','eco','family','mini','silent','slim']
  .map(n => `--- landing page: ${n} ---\n${read(`domain/landing_pages/${n}.md`)}`).join('\n\n');
const corpus = `${read('domain/knowledge.md')}\n\n${pages}`;

const actions = [];
const processor = new MessageProcessor([basicCatalog], a => actions.push(a));
const caps = processor.getClientCapabilities({includeInlineCatalogs: true});
const inline = caps['v0.9'].inlineCatalogs[0];
const system = buildSystemPrompt(inline, basicCatalog.id, corpus);

console.log('system prompt chars:', system.length);

const turns = [];
async function ask(text, surfaceId) {
  turns.push({role: 'user', parts: [{text: `${text}\n\n(Draw your answer on surfaceId "${surfaceId}".)`}]});
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${process.env.GEMINI_API_KEY}`,
    {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({
      systemInstruction: {parts:[{text: system}]},
      contents: turns,
      generationConfig: {temperature: 0.7, maxOutputTokens: 4096, responseMimeType: 'application/json'},
    })});
  const data = await res.json();
  if (data.error) throw new Error(`${data.error.code}: ${data.error.message}`);
  const raw = data.candidates?.[0]?.content?.parts?.map(p=>p.text??'').join('') ?? '';
  if (!raw) throw new Error('no text, finishReason=' + data.candidates?.[0]?.finishReason);
  turns.push({role:'model', parts:[{text: raw}]});

  const parsed = JSON.parse(raw);
  console.log('\n--- say:', parsed.say);
  console.log('--- a2ui messages:', parsed.a2ui?.length);
  try {
    processor.processMessages(parsed.a2ui);
    const s = processor.model.surfacesMap.get(surfaceId);
    if (!parsed.a2ui.find(m=>m.updateComponents)) {
      console.log('--- RAW KEYS:', parsed.a2ui.map(m=>Object.keys(m).join('+')).join(' | '));
      console.log('--- RAW:', JSON.stringify(parsed.a2ui).slice(0,900));
    }
    console.log('--- surface rendered:', !!s);
    if (s) {
      const comps = parsed.a2ui.find(m=>m.updateComponents)?.updateComponents?.components ?? [];
      console.log('--- components:', comps.map(c=>`${c.id}:${c.component}`).join(', '));
    }
  } catch (e) {
    console.log('--- PROCESSOR REJECTED:', e.message.slice(0, 600));
  }
  return parsed;
}

// Walk the CUJ: Jane answers by pressing the buttons the assistant drew.
// She has a normal plumbed kitchen, a 60 cm gap, a household of two, a quiet
// open-plan kitchen is not a concern, and she cares about running costs. That
// should land on the Eco.
let n = 0;
const first = await ask("Hi, I am looking for a dishwasher. I am overwhelmed with choices and don't know where to start.", `turn-${n}`);

function buttons(parsed) {
  const comps = parsed.a2ui.find(m=>m.updateComponents)?.updateComponents?.components ?? [];
  return comps.filter(c => c.component === 'Button');
}

let parsed = first;
const picks = [0, 0, 0, 1, 1];
for (const pick of picks) {
  const btns = buttons(parsed);
  if (btns.length === 0) { console.log('\n(no buttons this turn, stopping the walk)'); break; }
  const b = btns[Math.min(pick, btns.length - 1)];
  n += 1;
  console.log(`\n>>> Jane presses ${b.id}`);
  parsed = await ask(
    `The user pressed "${b.id}" in the UI you drew. The action was ` +
    `"${b.action?.event?.name ?? 'press'}" with context ${JSON.stringify(b.action?.event?.context ?? {})}. ` +
    `Answer as if they had told you this.`, `turn-${n}`);
  const text = JSON.stringify(parsed.a2ui);
  const link = text.match(/https:\/\/github\.com[^"')\s]*landing_pages[^"')\s]*/);
  if (link) { console.log('\n*** LANDING PAGE LINK REACHED:', link[0]); break; }
}
