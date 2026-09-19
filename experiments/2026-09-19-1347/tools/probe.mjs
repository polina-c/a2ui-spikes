import {chromium} from 'playwright';
const url = process.argv[2];
const b = await chromium.launch();
const p = await b.newPage({viewport: {width: 1280, height: 900}});
await p.goto(url, {waitUntil: 'networkidle'});
await new Promise(r => setTimeout(r, 6000));
const info = await p.evaluate(() => {
  const out = {tappable: [], inputs: [], roles: {}, textfields: 0};
  document.querySelectorAll('flt-semantics').forEach(e => {
    const role = e.getAttribute('role') || 'none';
    out.roles[role] = (out.roles[role] || 0) + 1;
    if (e.hasAttribute('flt-tappable') || role === 'button')
      out.tappable.push((e.getAttribute('aria-label') || e.textContent || '').trim().slice(0, 70));
  });
  document.querySelectorAll('input,textarea').forEach(e => out.inputs.push(`${e.tagName}:${e.type || ''}`));
  return out;
});
console.log(JSON.stringify(info, null, 1).slice(0, 2500));
await b.close();
