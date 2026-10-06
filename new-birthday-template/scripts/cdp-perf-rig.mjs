import { spawn } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';

const SHELL = '/Users/yashkumarmeena/Desktop/Work/Wishes/Be/heartcraft-video/node_modules/.remotion/chrome-headless-shell/mac-arm64/chrome-headless-shell-mac-arm64/chrome-headless-shell';
const [origin, label, throttle = '6'] = process.argv.slice(2);
const port = 9300 + Math.floor(Math.random() * 500);
const proc = spawn(SHELL, [`--remote-debugging-port=${port}`, '--no-first-run', '--disable-gpu-vsync=false', `--user-data-dir=/tmp/cdp-rig-${port}`, 'about:blank'], { stdio: 'ignore' });

async function wsUrl() {
  for (let i = 0; i < 60; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const page = list.find((t) => t.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch {}
    await sleep(250);
  }
  throw new Error('no devtools');
}

const ws = new WebSocket(await wsUrl());
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let seq = 0;
const pending = new Map();
ws.addEventListener('message', (m) => {
  const msg = JSON.parse(m.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
});
const send = (method, params = {}) => new Promise((res) => { const id = ++seq; pending.set(id, res); ws.send(JSON.stringify({ id, method, params })); });
const evaluate = async (expression) => {
  const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (r.result?.exceptionDetails) return { error: r.result.exceptionDetails.exception?.description || r.result.exceptionDetails.text };
  return r.result?.result?.value;
};
const go = async (path) => { await send('Page.navigate', { url: origin + path }); await sleep(4500); };

await send('Page.enable');
await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
await go('/f/test123');
await evaluate(`(() => { const d = { recipientName: 'Aarohi', userName: 'Yash', birthDay: 22, birthMonth: 'August', birthYear: 2026, message: 'Happy birthday! Wishing you the sweetest year yet, full of laughter, cake and people who love you.', templateId: 'FRUIT_BIRTHDAY', photos: [0,1,2,3,4].map(i => ({ type: 'PHOTO', url: '/__perf/p' + i + '.jpg', order: i })) }; localStorage.setItem('birthday_test_data', JSON.stringify(d)); return true; })()`);
await send('Emulation.setCPUThrottlingRate', { rate: Number(throttle) });

const RIG = `
window.__measure = async (mode, seconds) => {
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const peek = [...document.querySelectorAll('button')].find((b) => /peek/i.test(b.textContent));
  const frames = []; let last = performance.now(); let id;
  const tick = (t) => { frames.push(t - last); last = t; id = requestAnimationFrame(tick); };
  const lt = []; const po = new PerformanceObserver((l) => { for (const e of l.getEntries()) lt.push(Math.round(e.duration)); });
  po.observe({ entryTypes: ['longtask'] });
  if (peek) { peek.click(); await sleep(mode === 'open' ? 0 : 2600); }
  frames.length = 0; last = performance.now(); id = requestAnimationFrame(tick);
  const stage = () => document.querySelector('.fr-canvas .stage');
  const pe = (el, type, x, y) => el.dispatchEvent(new PointerEvent(type, { bubbles: true, cancelable: true, pointerId: 1, pointerType: 'touch', isPrimary: true, clientX: x, clientY: y }));
  const t0 = performance.now();
  let actions = 0;
  while (performance.now() - t0 < seconds * 1000) {
    const el = stage(); if (!el) { await sleep(100); continue; }
    const r = el.getBoundingClientRect();
    if (mode === 'game') {
      const fr = [...document.querySelectorAll('.flying-fruit:not(.fruit-piece)')].map((e) => e.getBoundingClientRect()).filter((b) => b.top > r.top + 90 && b.bottom < r.bottom - 60);
      const t = fr[0]; const cx = t ? t.left + t.width / 2 : r.left + r.width / 2; const cy = t ? t.top + t.height / 2 : r.top + r.height / 2;
      pe(el, 'pointerdown', cx - 70, cy + 40);
      for (let i = 1; i <= 8; i++) { pe(el, 'pointermove', cx - 70 + 140 * i / 8, cy + 40 - 80 * i / 8); await sleep(16); }
      pe(el, 'pointerup', cx + 70, cy - 40); actions++;
      await sleep(450);
    } else if (mode === 'photos') {
      el.dispatchEvent(new MouseEvent('click', { bubbles: true })); actions++;
      await sleep(2400);
    } else { await sleep(200); }
  }
  cancelAnimationFrame(id); po.disconnect();
  const n = frames.length; const s = frames.slice().sort((a, b) => a - b);
  const pct = (p) => +s[Math.min(n - 1, Math.floor(n * p))].toFixed(1);
  const dropped = frames.reduce((a, f) => a + Math.max(0, Math.round(f / 16.7) - 1), 0);
  return { mode, seconds, actions, frames: n, fps: +(n / seconds).toFixed(1), p50: pct(0.5), p95: pct(0.95), p99: pct(0.99), worst: +s[n - 1].toFixed(1), droppedFrames: dropped, over34: frames.filter((f) => f > 34).length, over50: frames.filter((f) => f > 50).length, longTasks: lt.length, longTaskMs: lt.reduce((a, b) => a + b, 0), biggestLongTask: Math.max(0, ...lt), scene: stage()?.className, score: document.querySelectorAll('.x-filled').length, photoPx: [...document.querySelectorAll('.photo-polaroid-shot img')].map((i) => i.naturalWidth + 'x' + i.naturalHeight).join(' ') };
};
true;`;

const out = {};
for (const [mode, path, secs] of [['open', '/f/test123', 5], ['game', '/f/test123?from=ninjaGame', 10], ['photos', '/f/test123?from=photos', 14]]) {
  await go(path);
  await evaluate(RIG);
  out[mode] = await evaluate(`window.__measure('${mode}', ${secs})`);
}
console.log(JSON.stringify({ label, origin, throttle: Number(throttle), ...out }, null, 1));
ws.close();
proc.kill('SIGKILL');
process.exit(0);
