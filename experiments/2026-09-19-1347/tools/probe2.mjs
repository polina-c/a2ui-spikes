import {chromium} from 'playwright';
const b = await chromium.launch();
const p = await b.newPage({viewport:{width:1280,height:900}});
await p.goto(process.argv[2], {waitUntil:'networkidle'});
await new Promise(r=>setTimeout(r,6000));
await p.locator('input[type=password]').fill(process.env.GEMINI_API_KEY);
await p.locator('flt-semantics[role="button"]').filter({hasText:'Start the chat'}).first().click({force:true});
await new Promise(r=>setTimeout(r,5000));
const info = await p.evaluate(() => ({
  all: Array.from(document.querySelectorAll('flt-semantics')).map(e => ({
    role: e.getAttribute('role'),
    label: (e.getAttribute('aria-label')||e.textContent||'').trim().slice(0,60),
    tappable: e.hasAttribute('flt-tappable'),
  })).filter(x => x.label || x.role),
  inputs: Array.from(document.querySelectorAll('input,textarea')).map(e=>`${e.tagName}:${e.type||''}`),
}));
console.log(JSON.stringify(info, null, 1).slice(0,3000));
await p.screenshot({path:'/tmp/flutter-chat.png'});
await b.close();
