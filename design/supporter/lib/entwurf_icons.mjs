// Entwurf Icons, Runde 2: freigegebener Icon-Satz (Stufe 2, Nachthimmel B1)
// und die Mondposition fuer Waldsee Nacht. Runde 1 (entwurf-icons-runde-1.html,
// entwurf-icons/a-*, b*-, c-*) ist als fester Stand abgelegt.
import { r1 } from './util.mjs';
import { MOTIFS, TIMES, SCENES, buildIcon, buildIconFrom } from './icons.mjs';
import { PAGE_CSS } from './entwurf_szenen.mjs';

export const MONDPOSITIONEN = [
  { id: 'm1', label: 'M1: Knapp über dem Gipfel', moon: [700, 340] },
  { id: 'm2', label: 'M2: Im Sattel, unten angeschnitten', moon: [600, 400] },
  { id: 'm3', label: 'M3: Halb hinter der Bergflanke', moon: [745, 460] },
];

const TIME_KEYS = Object.keys(TIMES);

export function entwurfIconFiles() {
  const files = [];
  for (const motif of MOTIFS) {
    for (const time of TIME_KEYS) {
      files.push({ path: `entwurf-icons/r2-${motif.id}-${time}.svg`, content: buildIcon(motif.id, time) });
    }
  }
  for (const m of MONDPOSITIONEN) {
    files.push({ path: `entwurf-icons/r2-mond-${m.id}.svg`, content: buildIconFrom(SCENES.waldsee, `waldsee ${m.id}`, 'nacht', { waldseeMoon: m.moon }) });
  }
  return files;
}

const bigCell = (src, label) => `<figure class="ic"><img src="${src}" alt="${label}" width="168" height="168"><figcaption>${label}</figcaption></figure>`;

const realSizes = (srcs) => `<div class="real">
${['light', 'dark']
  .map(
    (mode) => `<div class="realcard ${mode}">${[60, 56, 46]
      .map((size) => `<div class="realrow"><span>${size} px</span>${srcs.map((s) => `<img src="${s}" width="${size}" height="${size}" style="border-radius:${r1(size * 0.225)}px" alt="">`).join('')}</div>`)
      .join('')}</div>`,
  )
  .join('')}
</div>`;

export function buildEntwurfIconsPage() {
  const srcs = [];
  const grid = MOTIFS.map((motif) => {
    const cells = TIME_KEYS.map((time) => {
      const src = `entwurf-icons/r2-${motif.id}-${time}.svg`;
      srcs.push(src);
      return bigCell(src, `${motif.label} ${TIMES[time].label}`);
    }).join('');
    return `<div class="icrow">${cells}</div>`;
  }).join('');
  const mond = MONDPOSITIONEN.map((m) => bigCell(`entwurf-icons/r2-mond-${m.id}.svg`, m.label)).join('');
  const mondReal = realSizes(MONDPOSITIONEN.map((m) => `entwurf-icons/r2-mond-${m.id}.svg`));
  return `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Entwürfe: Icons, Runde 2</title>
<style>
${PAGE_CSS}
main { padding-bottom: 160px; }
.icgrid { display:flex; flex-direction:column; gap:10px; }
.icrow { display:flex; gap:14px; flex-wrap:wrap; }
.ic { margin:0; }
.ic img { display:block; border-radius:38px; }
.real { display:flex; gap:16px; flex-wrap:wrap; margin-top:16px; }
.realcard { border-radius:16px; padding:12px 16px; display:flex; flex-direction:column; gap:10px; }
.realcard.light { background:#f2f2f7; color:#3c3c43; }
.realcard.dark { background:#1c1c1e; color:#c9c9d4; }
.realrow { display:flex; gap:10px; align-items:center; }
.realrow span { width:48px; font-size:12px; }
.bar { position:fixed; left:0; right:0; bottom:0; background:#1b231e; border-top:1px solid #2b352f; padding:12px 24px; }
.bar .inner { max-width:1100px; margin:0 auto; display:flex; gap:20px; flex-wrap:wrap; align-items:flex-start; }
.bar fieldset { border:0; padding:0; margin:0; }
.bar legend { font-size:13px; color:#9aa69e; }
.opt { font-size:14px; margin-right:10px; white-space:nowrap; }
.bar textarea { flex:1; min-width:260px; height:58px; background:#121814; color:#e4eae3; border:1px solid #2b352f; border-radius:8px; padding:6px 8px; font:14px system-ui; }
.bar button { background:#e0b155; color:#1b1b1b; border:0; border-radius:8px; padding:10px 16px; font-weight:600; cursor:pointer; }
@media (max-width: 700px) { .ic img { width:30vw; height:30vw; border-radius:7vw; } }
</style>
</head>
<body>
<main>
<h1>Icons, Runde 2</h1>
<p>Umgesetzt aus Runde 1: Sonne und Mond in Stufe 2, Waldsee morgens und abends wie bisher, Nachthimmel nach B1 und nachts ohne Mond. Die Kohte am Waldsee (C1) ist festgelegt.</p>
<nav><a href="#mond">Mond bei Waldsee Nacht</a><a href="#satz">Icon-Satz</a></nav>
<section id="mond"><h2>Mond bei Waldsee Nacht</h2>
<p>Tiefer an den Berg. Mond in Stufe 2, Spiegelung im See folgt der Position.</p>
<div class="icrow">${mond}</div>
${mondReal}
</section>
<section id="satz"><h2>Icon-Satz</h2>
<p>Alle neun Icons, Waldsee Nacht mit M3. Darunter echte Größen auf hellem und dunklem Grund.</p>
<div class="icgrid">${grid}</div>
${realSizes(srcs)}
</section>
</main>
<div class="bar"><div class="inner">
<fieldset><legend>Mond Waldsee Nacht</legend>${MONDPOSITIONEN.map((m) => `<label class="opt"><input type="radio" name="m" value="${m.label.split(':')[0]}"> ${m.label.split(':')[0]}</label>`).join('')}</fieldset>
<fieldset><legend>Icon-Satz</legend><label class="opt"><input type="radio" name="s" value="passt"> passt</label><label class="opt"><input type="radio" name="s" value="ändern"> ändern</label></fieldset>
<textarea id="note" placeholder="Anmerkungen"></textarea>
<button id="copy">Auswahl kopieren</button>
</div></div>
<script>
document.getElementById('copy').addEventListener('click', async () => {
  const pick = (n) => document.querySelector('input[name="' + n + '"]:checked')?.value ?? '-';
  const text = 'Mond Waldsee Nacht: ' + pick('m') + '\\nIcon-Satz: ' + pick('s') + '\\nAnmerkungen: ' + (document.getElementById('note').value || '-');
  try { await navigator.clipboard.writeText(text); document.getElementById('copy').textContent = 'Kopiert'; }
  catch { prompt('Auswahl', text); }
});
</script>
</body>
</html>
`;
}
