import sharp from '/Users/yashkumarmeena/Desktop/Work/Wishes/Fe/heartcraft-birthday-fe/node_modules/sharp/lib/index.js';
import { readdirSync, readFileSync, writeFileSync, statSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const [srcDir, outDir, drawnPath, headroom = '3.3', dryRun = ''] = process.argv.slice(2);
const drawn = drawnPath && drawnPath !== '-' && existsSync(drawnPath) ? JSON.parse(readFileSync(drawnPath, 'utf8')) : {};
const FLOOR = Number(process.env.FLOOR || 42);
const MIN_SAVE = 0.08;
const QUALITIES = [85, 88, 90, 92, 94];

async function rgba(input, w, h) {
  const { data } = await sharp(input).resize(w, h, { fit: 'fill', kernel: 'lanczos3' }).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  return data;
}

function psnr(a, b) {
  let se = 0; let n = 0;
  for (let i = 0; i < a.length; i += 4) {
    const aa = a[i + 3] / 255, ba = b[i + 3] / 255;
    for (let c = 0; c < 3; c++) {
      const av = a[i + c] * aa + 128 * (1 - aa);
      const bv = b[i + c] * ba + 128 * (1 - ba);
      se += (av - bv) ** 2; n++;
    }
    se += (a[i + 3] - b[i + 3]) ** 2 * 0.5; n += 0.5;
  }
  const mse = se / n;
  return mse === 0 ? 99 : 10 * Math.log10((255 * 255) / mse);
}

let before = 0, after = 0;
const rows = [];
for (const f of readdirSync(srcDir).filter((x) => x.endsWith('.webp')).sort()) {
  const src = join(srcDir, f);
  const orig = readFileSync(src);
  const meta = await sharp(orig).metadata();
  const d = drawn[f];
  let w = meta.width, h = meta.height, why = 'same px';
  if (d) {
    const needW = Math.ceil(d.w * Number(headroom)), needH = Math.ceil(d.h * Number(headroom));
    const k = Math.min(1, Math.max(needW / meta.width, needH / meta.height));
    if (k < 1) { w = Math.round(meta.width * k); h = Math.round(meta.height * k); why = `cap to ${headroom}x drawn`; }
  }
  const ref = await rgba(orig, w, h);
  let pick = null;
  for (const q of QUALITIES) {
    const buf = await sharp(orig).resize(w, h, { fit: 'fill', kernel: 'lanczos3' }).webp({ quality: q, alphaQuality: 100, effort: 6, smartSubsample: true }).toBuffer();
    const score = psnr(ref, await rgba(buf, w, h));
    if (score >= FLOOR) { pick = { q, buf, score }; break; }
  }
  before += orig.length;
  const keep = !pick || pick.buf.length > orig.length * (1 - MIN_SAVE);
  const final = keep ? orig : pick.buf;
  after += final.length;
  if (!dryRun && !keep) writeFileSync(join(outDir, f), final);
  if (!dryRun && keep && srcDir !== outDir) writeFileSync(join(outDir, f), orig);
  rows.push([f, `${meta.width}x${meta.height}`, keep ? 'kept original' : `${w}x${h} q${pick.q}`, orig.length, final.length, keep ? '-' : pick.score.toFixed(1), keep ? '' : why]);
}
for (const r of rows) console.log(`${r[0].padEnd(28)} ${r[1].padEnd(10)} -> ${r[2].padEnd(16)} ${String(r[3]).padStart(7)} -> ${String(r[4]).padStart(7)}  ${String(r[5]).padStart(5)} dB  ${r[6]}`);
console.log(`TOTAL ${before} -> ${after}  (${(100 - (after / before) * 100).toFixed(1)}% smaller), floor ${FLOOR} dB`);
