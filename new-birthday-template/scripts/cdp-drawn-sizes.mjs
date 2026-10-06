import { spawn } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';
const SHELL = '/Users/yashkumarmeena/Desktop/Work/Wishes/Be/heartcraft-video/node_modules/.remotion/chrome-headless-shell/mac-arm64/chrome-headless-shell-mac-arm64/chrome-headless-shell';
const origin = process.argv[2] || 'http://localhost:3000';
const port = 9300 + Math.floor(Math.random() * 500);
const proc = spawn(SHELL, [`--remote-debugging-port=${port}`, '--no-first-run', `--user-data-dir=/tmp/cdp-sizes-${port}`, 'about:blank'], { stdio: 'ignore' });
let wsu;
for (let i = 0; i < 60 && !wsu; i++) { try { const l = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json(); wsu = l.find((t) => t.type === 'page')?.webSocketDebuggerUrl; } catch {} if (!wsu) await sleep(250); }
const ws = new WebSocket(wsu); await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let seq = 0; const pend = new Map();
ws.addEventListener('message', (m) => { const x = JSON.parse(m.data); if (x.id && pend.has(x.id)) { pend.get(x.id)(x); pend.delete(x.id); } });
const send = (method, params = {}) => new Promise((res) => { const id = ++seq; pend.set(id, res); ws.send(JSON.stringify({ id, method, params })); });
const ev = async (expression) => (await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })).result?.result?.value;
await send('Page.enable'); await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 3, mobile: true });
await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
await send('Page.navigate', { url: origin + '/f/test123' }); await sleep(4000);
await ev(`(() => { const d = { recipientName: 'Aarohi', userName: 'Yash', birthDay: 22, birthMonth: 'August', birthYear: 2026, message: 'Happy birthday! Wishing you the sweetest year yet, full of laughter, cake and people who love you. '.repeat(3), templateId: 'FRUIT_BIRTHDAY', photos: [0,1,2,3,4].map(i => ({ type: 'PHOTO', url: '/fruit/cake.webp', order: i })) }; localStorage.setItem('birthday_test_data', JSON.stringify(d)); return 1; })()`);
const COLLECT = `(() => {
  const out = {};
  const canvas = document.querySelector('.fr-canvas'); const cover = document.querySelector('.fr-cover');
  const scaleOf = (el) => { const m = (el?.style.transform || '').match(/scale\\(([\\d.]+)\\)/); return m ? +m[1] : 1; };
  const sc = scaleOf(canvas), cv = scaleOf(cover);
  const add = (src, cssW, cssH, nat) => { const f = (src.match(/\\/fruit\\/([^?"')]+)/) || [])[1]; if (!f || !cssW) return; const o = out[f] || (out[f] = { w: 0, h: 0 }); o.w = Math.max(o.w, cssW); o.h = Math.max(o.h, cssH); };
  document.querySelectorAll('.fr-shell img').forEach((img) => {
    const inCover = !!img.closest('.fr-cover'); const s = inCover ? cv : sc;
    let w = img.offsetWidth, h = img.offsetHeight; let p = img.parentElement; let k = 1;
    for (let el = img; el && el !== canvas && el !== cover; el = el.parentElement) { const t = getComputedStyle(el).transform; if (t && t !== 'none') { const m = new DOMMatrix(t); k *= Math.max(Math.hypot(m.a, m.b), Math.hypot(m.c, m.d)); } const scl = getComputedStyle(el).scale; if (scl && scl !== 'none') k *= parseFloat(scl); }
    add(img.currentSrc || img.src, w * s * Math.max(1, k), h * s * Math.max(1, k));
  });
  document.querySelectorAll('.fr-shell *').forEach((el) => { const bg = getComputedStyle(el).backgroundImage; if (!bg || !bg.includes('/fruit/')) return; const inCover = !!el.closest('.fr-cover'); const s = inCover ? cv : sc; const size = getComputedStyle(el).backgroundSize; add(bg, el.offsetWidth * s * (size === 'cover' ? 1.2 : 1), el.offsetHeight * s * (size === 'cover' ? 1.2 : 1)); });
  return out;
})()`;
const merged = {};
const merge = (o) => { for (const [f, v] of Object.entries(o || {})) { const m = merged[f] || (merged[f] = { w: 0, h: 0 }); m.w = Math.max(m.w, v.w); m.h = Math.max(m.h, v.h); } };
const ACT = {
  ninjaGame: `(async () => { const st = document.querySelector('.fr-canvas .stage'); const r = st.getBoundingClientRect(); const pe = (t, x, y) => st.dispatchEvent(new PointerEvent(t, { bubbles: true, cancelable: true, pointerId: 1, pointerType: 'touch', isPrimary: true, clientX: x, clientY: y })); for (let k = 0; k < 3; k++) { const f = [...document.querySelectorAll('.flying-fruit:not(.fruit-piece)')].map((e) => e.getBoundingClientRect()).filter((b) => b.top > r.top + 90 && b.bottom < r.bottom - 60)[0]; if (!f) { await new Promise((q) => setTimeout(q, 400)); continue; } const cx = f.left + f.width / 2, cy = f.top + f.height / 2; pe('pointerdown', cx - 70, cy + 40); for (let i = 1; i <= 8; i++) { pe('pointermove', cx - 70 + 140 * i / 8, cy + 40 - 80 * i / 8); await new Promise((q) => setTimeout(q, 16)); } pe('pointerup', cx + 70, cy - 40); await new Promise((q) => setTimeout(q, 150)); } return 1; })()`,
  photos: `(async () => { document.querySelector('.fr-canvas .stage').dispatchEvent(new MouseEvent('click', { bubbles: true })); await new Promise((q) => setTimeout(q, 300)); return 1; })()`,
};
for (const scene of ['watermelon', 'balloons', 'ninjaIntro', 'ninjaGame', 'photos', 'basket', 'letter', 'gift', 'end']) {
  await send('Page.navigate', { url: `${origin}/f/test123?from=${scene}` }); await sleep(3500);
  await ev(`(() => { const b = [...document.querySelectorAll('button')].find((x) => /peek/i.test(x.textContent)); b?.click(); return !!b; })()`);
  for (let t = 0; t < 8; t++) { await sleep(700); if (ACT[scene]) await ev(ACT[scene]); merge(await ev(COLLECT)); }
}
console.log(JSON.stringify(merged));
ws.close(); proc.kill('SIGKILL'); process.exit(0);
