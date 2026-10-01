// Exportiert Elemente mit data-shot bzw. data-shot-group aus einer Entwurfsseite
// als PNG nach design/statistik/out/ (nicht versioniert).
//
// Nutzung:
//   node design/statistik/render.mjs [entwurf-runde-N.html] [--stamm gross|klein] [--stil punkte|balken|zahlen] [--kopf H1|H2|H3] [--nur <praefix>]
//
// Benötigt Google Chrome; steuert es direkt über das DevTools-Protokoll
// (Node >= 22 bringt WebSocket mit), ohne weitere Pakete.
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : fallback;
};
const datei = args.find((a) => a.endsWith('.html')) || 'entwurf-runde-1.html';
const stamm = opt('stamm', 'gross');
const stil = opt('stil', 'balken');
const kopf = opt('kopf', 'H1');
const nur = opt('nur', '');
const scale = Number(opt('scale', '2'));
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PORT = 9300 + Math.floor(Math.random() * 500);
const OUT = join(DIR, 'out', `${basename(datei, '.html')}-${stamm}`);

const profil = mkdtempSync(join(tmpdir(), 'statistik-render-'));
const chrome = spawn(CHROME, [
  '--headless=new', '--disable-gpu', '--hide-scrollbars', `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profil}`, '--allow-file-access-from-files', 'about:blank',
], { stdio: 'ignore' });

const warte = (ms) => new Promise((r) => setTimeout(r, ms));
async function ziel() {
  for (let i = 0; i < 50; i++) {
    try {
      const liste = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
      const seite = liste.find((t) => t.type === 'page');
      if (seite) return seite.webSocketDebuggerUrl;
    } catch {}
    await warte(200);
  }
  throw new Error('Chrome antwortet nicht');
}

const ws = new WebSocket(await ziel());
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let naechsteId = 1;
const offen = new Map();
const ereignisse = [];
ws.addEventListener('message', (m) => {
  const msg = JSON.parse(m.data);
  if (msg.id && offen.has(msg.id)) {
    const { res, rej } = offen.get(msg.id);
    offen.delete(msg.id);
    msg.error ? rej(new Error(msg.error.message)) : res(msg.result);
  } else if (msg.method === 'Runtime.exceptionThrown') {
    const d = msg.params.exceptionDetails;
    console.error(`JS-Fehler: ${d.exception?.description || d.text} (Zeile ${d.lineNumber + 1})`);
  } else if (msg.method) {
    ereignisse.push(msg.method);
  }
});
const cdp = (method, params = {}) => new Promise((res, rej) => {
  const id = naechsteId++;
  offen.set(id, { res, rej });
  ws.send(JSON.stringify({ id, method, params }));
});

try {
  await cdp('Page.enable');
  await cdp('Runtime.enable');
  await cdp('Emulation.setDeviceMetricsOverride', { width: 1800, height: 1200, deviceScaleFactor: scale, mobile: false });
  const url = `file://${resolve(DIR, datei)}?stamm=${stamm}&stil=${stil}&kopf=${kopf}`;
  await cdp('Page.navigate', { url });
  for (let i = 0; i < 100; i++) {
    const r = await cdp('Runtime.evaluate', { expression: 'document.body && document.body.dataset.fertig', returnByValue: true });
    if (r.result.value === '1') break;
    await warte(100);
  }
  await cdp('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
  await warte(300);
  const { result } = await cdp('Runtime.evaluate', {
    returnByValue: true,
    expression: `[...document.querySelectorAll('[data-shot],[data-shot-group]')].map((el) => {
      const r = el.getBoundingClientRect();
      return { name: el.dataset.shotGroup || el.dataset.shot, x: r.left + scrollX, y: r.top + scrollY, w: r.width, h: r.height };
    })`,
  });
  // Prüfberichte der Seite (Elemente mit data-bericht) in die Konsole schreiben.
  const bericht = await cdp('Runtime.evaluate', {
    returnByValue: true,
    expression: `[...document.querySelectorAll('[data-bericht]')].map((el) => el.innerText).join('\\n')`,
  });
  if (bericht.result.value) console.log(bericht.result.value);
  mkdirSync(OUT, { recursive: true });
  for (const e of result.value.filter((x) => !nur || x.name.startsWith(nur))) {
    const pad = 14;
    const shot = await cdp('Page.captureScreenshot', {
      format: 'png', captureBeyondViewport: true,
      clip: { x: e.x - pad, y: e.y - pad, width: e.w + 2 * pad, height: e.h + 2 * pad, scale: 1 },
    });
    const ziel = join(OUT, `${e.name}.png`);
    writeFileSync(ziel, Buffer.from(shot.data, 'base64'));
    console.log(`  ${ziel.replace(DIR + '/', '')}  ${Math.round(e.w)}×${Math.round(e.h)}`);
  }
} finally {
  ws.close();
  chrome.kill();
  await warte(300);
  rmSync(profil, { recursive: true, force: true });
}
