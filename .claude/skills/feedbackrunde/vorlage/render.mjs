// Rendert eine Rundenseite per Chrome headless und schneidet alle [data-shot]
// als PNG aus, dazu eine Gesamtansicht `seite.png`. Zum Selbstpruefen vor dem
// Oeffnen fuer den Nutzer.
//
//   node render.mjs runde-1.html [--out <ordner>] [--nur <praefix>] [--scale 2] [--js '<ausdruck>'] [theme=beide ts=1.4 geraet=ipad ...]
//
// Zusaetzliche key=value-Argumente landen als URL-Parameter auf der Seite
// (Kopfzeilen-Zustand: theme, ts, geraet und eigene Steuerungen). `--js` wird
// nach dem Laden ausgewertet und das Ergebnis ausgegeben, z. B. um Klicks und
// `Runde.markdown()` zu pruefen.
// Standardziel ist out/<datei>/ neben der Seite. Braucht Google Chrome und
// Node >= 22 (WebSocket eingebaut), keine weiteren Pakete.
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : fallback;
};
const datei = resolve(args.find((a) => a.endsWith('.html')) ?? 'runde-1.html');
const nur = opt('nur', '');
const js = opt('js', '');
const scale = Number(opt('scale', '2'));
const params = new URLSearchParams(args.filter((a) => /^[\w-]+=/.test(a)).map((a) => a.split(/=(.*)/s).slice(0, 2)));
const OUT = resolve(opt('out', join(dirname(datei), 'out', basename(datei, '.html'))));
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PORT = 9300 + Math.floor(Math.random() * 500);

const profil = mkdtempSync(join(tmpdir(), 'feedbackrunde-'));
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
let fehler = 0;
ws.addEventListener('message', (m) => {
  const msg = JSON.parse(m.data);
  if (msg.id && offen.has(msg.id)) {
    const { res, rej } = offen.get(msg.id);
    offen.delete(msg.id);
    msg.error ? rej(new Error(msg.error.message)) : res(msg.result);
  } else if (msg.method === 'Runtime.exceptionThrown') {
    const d = msg.params.exceptionDetails;
    fehler++;
    console.error(`JS-Fehler: ${d.exception?.description || d.text} (Zeile ${d.lineNumber + 1})`);
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
  await cdp('Page.navigate', { url: `file://${datei}${params.size ? `?${params}` : ''}` });
  for (let i = 0; i < 100; i++) {
    const r = await cdp('Runtime.evaluate', { expression: 'document.body && document.body.dataset.fertig', returnByValue: true });
    if (r.result.value === '1') break;
    await warte(100);
  }
  await cdp('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
  await warte(300);
  if (js) {
    const r = await cdp('Runtime.evaluate', { expression: js, returnByValue: true, awaitPromise: true });
    console.log(r.exceptionDetails ? `JS-Fehler: ${r.exceptionDetails.exception?.description}` : r.result.value);
  }
  mkdirSync(OUT, { recursive: true });
  const { result } = await cdp('Runtime.evaluate', {
    returnByValue: true,
    expression: `({ titel: document.title, hoehe: document.documentElement.scrollHeight, shots: [...document.querySelectorAll('[data-shot]')].map((el) => {
      const r = el.getBoundingClientRect();
      return { name: el.dataset.shot, x: r.left + scrollX, y: r.top + scrollY, w: r.width, h: r.height };
    }) })`,
  });
  const { titel, hoehe, shots } = result.value;
  console.log(`Tab: ${titel}`);
  const seite = await cdp('Page.captureScreenshot', {
    format: 'png', captureBeyondViewport: true,
    clip: { x: 0, y: 0, width: 1800, height: Math.min(hoehe, 16000), scale: 0.5 },
  });
  writeFileSync(join(OUT, 'seite.png'), Buffer.from(seite.data, 'base64'));
  for (const e of shots.filter((x) => !nur || x.name.startsWith(nur))) {
    const pad = 14;
    const shot = await cdp('Page.captureScreenshot', {
      format: 'png', captureBeyondViewport: true,
      clip: { x: e.x - pad, y: e.y - pad, width: e.w + 2 * pad, height: e.h + 2 * pad, scale: 1 },
    });
    writeFileSync(join(OUT, `${e.name}.png`), Buffer.from(shot.data, 'base64'));
  }
  console.log(`${shots.length} Ausschnitte und seite.png in ${OUT}${fehler ? `, ${fehler} JS-Fehler` : ''}`);
} finally {
  ws.close();
  chrome.kill();
  await warte(300);
  rmSync(profil, { recursive: true, force: true });
}
