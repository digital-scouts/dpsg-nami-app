// Schreibt Logo, App-Icon und die Ebenen für die Startanimation nach
// design/marke/svg/ sowie eine Übersicht nach design/marke/preview.html.
//
//   node design/marke/generate.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { icon, logo } from './lib/marke.mjs';

const ordner = dirname(fileURLToPath(import.meta.url));
const ziel = join(ordner, 'svg');
mkdirSync(ziel, { recursive: true });

const dateien = {};
for (const modus of ['hell', 'dunkel']) {
  dateien[`logo-${modus}.svg`] = logo(modus);
  dateien[`icon-${modus}.svg`] = icon(modus);
  // Ebenen für #279: erst die Personen ohne Tuch, dann Tuch samt Zipfeln, zuletzt der Knoten.
  dateien[`icon-${modus}-grund.svg`] = icon(modus, { ebenen: ['grund', 'person', 'zeilen'] });
  dateien[`icon-${modus}-tuch.svg`] = icon(modus, { ebenen: ['zipfel', 'tuch'] });
  dateien[`icon-${modus}-knoten.svg`] = icon(modus, { ebenen: ['knoten'] });
}
for (const [name, svg] of Object.entries(dateien)) {
  writeFileSync(join(ziel, name), `${svg}\n`);
}

const kachel = (name, px) => `<img src="svg/${name}" width="${px}" height="${px}" style="border-radius:22.4%;box-shadow:0 2px 8px rgba(0,0,0,.18)">`;
const reihe = (modus) => `<section class="${modus}">
  <img src="svg/logo-${modus}.svg" width="160" height="160">
  <div class="lockup"><img src="svg/logo-${modus}.svg" width="58" height="58"><b>NaMi</b></div>
  ${kachel(`icon-${modus}.svg`, 120)} ${kachel(`icon-${modus}.svg`, 60)} ${kachel(`icon-${modus}.svg`, 29)}
  <span class="ebenen">${['grund', 'tuch', 'knoten'].map((e) => `<img src="svg/icon-${modus}-${e}.svg" width="60" height="60" title="${e}">`).join('')}</span>
</section>`;
writeFileSync(
  join(ordner, 'preview.html'),
  `<!doctype html>
<html lang="de"><head><meta charset="utf-8"><title>Marke</title><style>
body { margin:0; font:14px system-ui, sans-serif; }
section { display:flex; align-items:center; gap:24px; padding:24px 32px; flex-wrap:wrap; }
.hell { background:#fbfaf7; color:#1c1c1e; } .dunkel { background:#15171d; color:#f0f0f5; }
.lockup { display:flex; align-items:center; gap:10px; } .lockup b { font-size:30px; letter-spacing:-.5px; }
.ebenen { display:flex; gap:8px; } .ebenen img { outline:1px dashed #8888; }
</style></head><body>
${reihe('hell')}
${reihe('dunkel')}
</body></html>
`,
);
console.log(`${Object.keys(dateien).length} Dateien in ${ziel}`);
