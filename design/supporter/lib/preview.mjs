// Baut preview.html zum Sichten und Auswaehlen der Entwuerfe.
import { MOTIFS, TIMES } from './icons.mjs';
import { BADGE_COLORS, BADGE_MOTIFS, FOERDERER_BADGES } from './badges.mjs';
import { BACKGROUNDS } from './backgrounds.mjs';
import { PALETTES, paletteChecks } from './palettes.mjs';

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');

const pick = (kind, id, label, inner, extraClass = '') =>
  `<button type="button" class="pick ${extraClass}" data-kind="${kind}" data-id="${id}" aria-pressed="false" aria-label="${esc(label)} auswählen">${inner}<span class="pick-id">${id}</span></button>`;

const STUFE = { woe: '#ff6400', jufi: '#2f53a7', pfadi: '#00823c', rover: '#cc1f2f', biber: '#d9dde2' };

function tile(name, sub, stufe, badge, size = 20) {
  const b = badge ? `<img class="tile-badge" src="badges/${badge}.svg" width="${size}" height="${size}" alt="">` : '';
  return `<span class="tile"><span class="tile-stripe" style="background:${STUFE[stufe]}"></span><span><span class="tile-name">${esc(name)}${b}</span><span class="tile-sub">${esc(sub)}</span></span></span>`;
}

function iconsSection() {
  const rows = MOTIFS.map((m) => {
    const variants = Object.keys(TIMES)
      .map((t) => {
        const id = `${m.id}-${t}`;
        return pick(
          'icon',
          id,
          `${m.label} ${TIMES[t].label}`,
          `<span class="icon-set"><img class="mask-ios" src="icons/${id}.svg" alt="" width="132" height="132"><span class="icon-small"><img class="mask-android" src="icons/${id}.svg" alt="" width="72" height="72"><img class="mask-ios" src="icons/${id}.svg" alt="" width="40" height="40"></span></span><span class="pick-label">${TIMES[t].label}</span>`,
        );
      })
      .join('');
    return `<div class="motif-row"><h3>${esc(m.label)}</h3><div class="variants">${variants}</div></div>`;
  }).join('');
  return `<section id="icons" aria-labelledby="h-icons">
<h2 id="h-icons">App-Icon-Pakete</h2>
<p class="lead">Vier Pakete. Wer ein Paket kauft, bekommt Morgen, Abend und Nacht und wählt selbst, welche Variante auf dem Homescreen erscheint. Groß mit iOS-Maske, daneben Android-Kreis und Homescreen-Größe.</p>
${rows}
</section>`;
}

function badgesSection() {
  const sets = BADGE_MOTIFS.map((m) => {
    const colors = BADGE_COLORS.map((c) => {
      const id = `${m.id}-${c.id}`;
      return pick('badge', id, `${m.label} ${c.label}`, `<img src="badges/${id}.svg" alt="" width="72" height="72"><span class="pick-label">${esc(c.label)}</span>`, 'pick-badge');
    }).join('');
    const f = FOERDERER_BADGES.find((b) => b.id === m.foerderer);
    const special = pick('badge', f.id, `Förderer ${f.label}`, `<img src="badges/${f.id}.svg" alt="" width="112" height="112"><span class="pick-label">Förderer: ${esc(f.label)}</span>`, 'pick-foerderer');
    const list = [
      tile('Lena Hoffmann', 'Fahrtenname: Luchs', 'pfadi', `${m.id}-pfadi`),
      tile('Jonas Wegner', '12. März 2011', 'jufi', `${m.id}-jufi`),
      tile('Mia Schröder', 'Mitgliedsnummer 482 113', 'woe', null),
      tile('Tim Albers', 'Fahrtenname: Specht', 'rover', f.id, 22),
    ].join('');
    return `<div class="badge-set">
<h3>${esc(m.claim)}</h3>
<div class="badge-row">${colors}${special}</div>
<div class="app-mock list-mock">${list}</div>
</div>`;
  }).join('');
  return `<section id="badges" aria-labelledby="h-badges">
<h2 id="h-badges">Supporter-Badges</h2>
<p class="lead">Ein einfaches Badge in allen Stufenfarben und ein besonderes Förderer-Badge.</p>
${sets}
</section>`;
}

function iosSection(ios) {
  if (!ios) return '';
  const names = { Default: 'Hell', Dark: 'Dunkel', TintedLight: 'Getönt', ClearLight: 'Klar' };
  const rows = ios.icons.map((name) => {
    const auto = name.endsWith('Automatisch');
    const renders = ios.renditions
      .map((r) => `<figure><img src="ios/previews/${name}-${r}.png" alt="" width="112" height="112"><figcaption>${names[r]}</figcaption></figure>`)
      .join('');
    return `<div class="ios-row${auto ? ' ios-auto' : ''}"><h3>${esc(name)}</h3><div class="ios-renders">${renders}</div></div>`;
  }).join('');
  return `<section id="ios" aria-labelledby="h-ios">
<h2 id="h-ios">iOS 27: finale Icons</h2>
<p class="lead">Gerendert mit Icon Composer (Liquid Glass, Design-Generation 27). Jede Szene besteht aus drei Ebenen, damit Glas, Schatten und die getönte bzw. klare Darstellung Tiefe bekommen. Unter iOS enthält jedes Paket zusätzlich „Automatisch“: im hellen Modus der Morgen, im Dunkelmodus die Nacht. Der Wechsel passiert durch das System, ohne Hinweis und auch bei geschlossener App.</p>
${rows}
</section>`;
}

function backgroundsSection() {
  const items = BACKGROUNDS.map((bg) =>
    pick(
      'background',
      bg.id,
      bg.label,
      `<span class="phone">
<span class="phone-header">
<img class="bg-light" src="backgrounds/${bg.id}-light.svg" alt="">
<img class="bg-dark" src="backgrounds/${bg.id}-dark.svg" alt="">
<span class="phone-title">Mitglieder</span>
<span class="phone-search">Suchen</span>
</span>
<span class="phone-body">${tile('Lena Hoffmann', 'Fahrtenname: Luchs', 'pfadi', 'kompass-pfadi')}${tile('Jonas Wegner', '12. März 2011', 'jufi', null)}</span>
</span><span class="pick-label">${esc(bg.label)}</span><span class="pick-id bg-light-text">Tag: ${esc(bg.day)}</span><span class="pick-id bg-dark-text">Nacht: ${esc(bg.night)}</span>`,
      'pick-bg',
    ),
  ).join('');
  return `<section id="hintergruende" aria-labelledby="h-bg">
<h2 id="h-bg">Animierte Hintergründe</h2>
<p class="lead">Für den Kopf der Mitgliederliste. Alle Bewegungen sind langsam und stehen still, wenn „Bewegung reduzieren“ aktiv ist. Hell zeigt die Tagesszene, Dunkel die Nachtszene; umschalten kannst du oben.</p>
<div class="bg-grid">${items}</div>
</section>`;
}

function paletteMock(p, mode) {
  const c = p[mode];
  const vars = Object.entries(c)
    .map(([k, v]) => `--p-${k}:${v}`)
    .join(';');
  return `<span class="pal-mock pal-${mode}" style="${vars}">
<span class="pal-bar">Mitglieder</span>
<span class="pal-tile"><span class="pal-stripe"></span><span><span class="pal-name">Lena Hoffmann</span><span class="pal-sub">Fahrtenname: Luchs</span></span></span>
<span class="pal-tile"><span class="pal-stripe" style="background:var(--p-secondary)"></span><span><span class="pal-name">Jonas Wegner</span><span class="pal-sub">12. März 2011</span></span></span>
<span class="pal-row"><span class="pal-btn">Speichern</span><span class="pal-chip">Leitung</span><span class="pal-switch" aria-hidden="true"></span></span>
<span class="pal-row"><span class="pal-ok">Synchronisiert</span><span class="pal-err">Offline</span></span>
</span>`;
}

function palettesSection() {
  const items = PALETTES.map((p) => {
    const checks = paletteChecks(p)
      .map((ch) => `<span class="check pal-${ch.mode}-only">Text ${ch.text.toFixed(1)} : 1, Primär ${ch.primary.toFixed(1)} : 1</span>`)
      .join('');
    return pick('palette', p.id, p.label, `${paletteMock(p, 'light')}${paletteMock(p, 'dark')}<span class="pick-label">${esc(p.label)}</span>${checks}`, 'pick-pal');
  }).join('');
  return `<section id="paletten" aria-labelledby="h-pal">
<h2 id="h-pal">Farbpaletten</h2>
<p class="lead">Gleiche Tokens wie die heutigen DPSGColors, damit der Umbau in theme.dart überschaubar bleibt. Unter jeder Palette steht der Kontrast gegen die Kartenfläche; 4,5 : 1 ist das Minimum für Fließtext.</p>
<div class="pal-grid">${items}</div>
</section>`;
}

const CSS = `
:root { color-scheme: light dark; --bg:#eceee8; --fg:#1c2621; --muted:#5d6962; --line:#cfd5cc; --card:#f7f8f4; --accent:#9b6f1c; --accent-bg:#f3e6c8; --tile:#ffffff; --tile-line:#e5e5ea; --tile-fg:#1c1c1e; --tile-muted:#6e6e73; }
html[data-mode="dark"] { --bg:#121814; --fg:#e4eae3; --muted:#9aa69e; --line:#2b352f; --card:#18201b; --accent:#e0b155; --accent-bg:#3a2f18; --tile:#1a1a22; --tile-line:#2e2e3a; --tile-fg:#f0f0f5; --tile-muted:#8a8a9a; }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--fg); font:17px/1.55 "Atkinson Hyperlegible", system-ui, sans-serif; }
h1, h2, h3 { font-family:"Bricolage Grotesque", system-ui, sans-serif; line-height:1.1; margin:0; }
h1 { font-size:clamp(2.4rem, 6vw, 4.2rem); font-weight:700; letter-spacing:-0.02em; font-variation-settings:"wdth" 85; }
h2 { font-size:2rem; font-weight:650; margin-bottom:.4rem; }
h3 { font-size:1.15rem; font-weight:600; margin:2rem 0 .8rem; }
.wrap { max-width:1180px; margin:0 auto; padding:0 24px 140px; }
header.top { padding:48px 0 24px; display:flex; gap:24px; align-items:flex-end; justify-content:space-between; flex-wrap:wrap; }
header.top p { max-width:60ch; color:var(--muted); margin:.8rem 0 0; }
.mode { display:flex; border:1px solid var(--line); border-radius:999px; padding:3px; }
.mode button { font:inherit; border:0; background:none; color:var(--fg); padding:6px 16px; border-radius:999px; cursor:pointer; }
.mode button[aria-pressed="true"] { background:var(--fg); color:var(--bg); }
.panorama { display:grid; grid-template-columns:repeat(4, 1fr); margin:8px -24px 56px; }
.panorama img { width:100%; aspect-ratio:1; display:block; }
section { padding-top:40px; border-top:1px solid var(--line); margin-top:40px; }
.lead { color:var(--muted); max-width:68ch; margin:0 0 1.2rem; }
.pick { font:inherit; color:inherit; background:none; border:2px solid transparent; border-radius:22px; padding:10px; cursor:pointer; display:inline-flex; flex-direction:column; align-items:center; gap:6px; position:relative; }
.pick:hover { background:var(--card); }
.pick:focus-visible { outline:3px solid var(--accent); outline-offset:2px; }
.pick[aria-pressed="true"] { border-color:var(--accent); background:var(--accent-bg); }
.pick[aria-pressed="true"]::after { content:"✓"; position:absolute; top:6px; right:8px; width:24px; height:24px; border-radius:50%; background:var(--accent); color:var(--bg); font-size:14px; line-height:24px; font-weight:700; }
.pick-id { font-size:12px; color:var(--muted); }
.pick-label { font-weight:600; }
.motif-row { display:grid; grid-template-columns:180px 1fr; gap:16px; align-items:center; padding:14px 0; border-bottom:1px solid var(--line); }
.motif-row h3 { margin:0; }
.variants { display:flex; flex-wrap:wrap; gap:12px; }
.icon-set { display:flex; gap:12px; align-items:flex-end; }
.icon-small { display:flex; flex-direction:column; gap:10px; align-items:center; }
.mask-ios { border-radius:22.5%; display:block; }
.mask-android { border-radius:50%; display:block; }
.table-wrap { overflow-x:auto; }
.badge-table { border-collapse:collapse; }
.badge-table th { font-weight:600; font-size:15px; text-align:left; padding:6px 10px; color:var(--muted); }
.badge-table td { padding:2px; }
.badge-set { margin-bottom:32px; }
.badge-row { display:flex; gap:8px; flex-wrap:wrap; align-items:flex-end; margin-bottom:16px; }
.pick-badge { border-radius:22px; }
.ios-row { display:grid; grid-template-columns:220px 1fr; gap:16px; align-items:center; padding:10px 0; border-bottom:1px solid var(--line); }
.ios-row h3 { margin:0; font-size:1rem; }
.ios-auto h3 { color:var(--accent); }
.ios-renders { display:flex; gap:12px; flex-wrap:wrap; }
.ios-renders figure { margin:0; text-align:center; }
.ios-renders figcaption { font-size:13px; color:var(--muted); }
.app-mock { background:var(--bg); border-radius:24px; padding:16px; max-width:420px; border:1px solid var(--line); }
.tile { display:flex; gap:12px; align-items:center; background:var(--tile); border:1px solid var(--tile-line); border-radius:16px; padding:12px 16px 12px 0; margin-bottom:6px; text-align:left; width:100%; }
.tile-stripe { width:4px; height:42px; border-radius:0 2px 2px 0; flex:none; }
.tile-name { font-weight:600; color:var(--tile-fg); display:flex; align-items:center; gap:6px; }
.tile-sub { display:block; font-size:14px; color:var(--tile-muted); }
.tile-badge { flex:none; }
.bg-grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(330px, 1fr)); gap:16px; }
.pick-bg, .pick-pal { align-items:stretch; }
.phone { display:block; border-radius:28px; overflow:hidden; border:1px solid var(--line); background:var(--bg); width:100%; }
.phone-header { display:block; position:relative; height:190px; overflow:hidden; }
.phone-header img { position:absolute; inset:0; width:100%; height:100%; object-fit:cover; }
html[data-mode="dark"] .bg-light, html:not([data-mode="dark"]) .bg-dark, html[data-mode="dark"] .bg-light-text, html:not([data-mode="dark"]) .bg-dark-text { display:none; }
.phone-title { position:absolute; left:18px; bottom:62px; font:700 30px/1 "Bricolage Grotesque", sans-serif; color:var(--tile-fg); }
.phone-search { position:absolute; left:16px; right:16px; bottom:14px; height:38px; border-radius:12px; background:color-mix(in srgb, var(--tile) 82%, transparent); color:var(--tile-muted); padding:8px 14px; text-align:left; font-size:15px; backdrop-filter:blur(8px); }
.phone-body { display:block; padding:12px; }
.pal-grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(260px, 1fr)); gap:16px; }
.pal-mock { display:flex; flex-direction:column; gap:8px; background:var(--p-bg); color:var(--p-fg); border-radius:22px; padding:12px; border:1px solid var(--line); text-align:left; }
html[data-mode="dark"] .pal-light, html:not([data-mode="dark"]) .pal-dark { display:none; }
html[data-mode="dark"] .pal-light-only, html:not([data-mode="dark"]) .pal-dark-only { display:none; }
.pal-bar { font:700 22px/1.2 "Bricolage Grotesque", sans-serif; color:var(--p-primary); padding:4px 4px 2px; }
.pal-tile { display:flex; gap:10px; align-items:center; background:var(--p-surface); border:1px solid var(--p-border); border-radius:14px; padding:10px 12px 10px 0; }
.pal-stripe { width:4px; height:34px; background:var(--p-primary); border-radius:0 2px 2px 0; }
.pal-name { display:block; font-weight:600; }
.pal-sub { display:block; font-size:13px; color:var(--p-muted); }
.pal-row { display:flex; gap:8px; align-items:center; flex-wrap:wrap; }
.pal-btn { background:var(--p-primary); color:var(--p-onPrimary); border-radius:999px; padding:6px 16px; font-weight:600; font-size:14px; }
.pal-chip { background:var(--p-primaryLite); color:var(--p-fg); border-radius:8px; padding:4px 10px; font-size:13px; }
.pal-switch { width:40px; height:24px; border-radius:12px; background:var(--p-primary); position:relative; }
.pal-switch::after { content:""; position:absolute; right:3px; top:3px; width:18px; height:18px; border-radius:50%; background:var(--p-onPrimary); }
.pal-ok { color:var(--p-success); font-size:13px; font-weight:600; }
.pal-err { color:var(--p-error); font-size:13px; font-weight:600; }
.check { font-size:12px; color:var(--muted); }
.selbar { position:fixed; left:0; right:0; bottom:0; background:var(--fg); color:var(--bg); padding:14px 24px; display:flex; gap:16px; align-items:center; justify-content:center; flex-wrap:wrap; }
.selbar button { font:inherit; font-weight:600; border:0; border-radius:999px; padding:8px 18px; cursor:pointer; background:var(--accent); color:#1a1408; }
.selbar button.ghost { background:none; color:var(--bg); border:1px solid color-mix(in srgb, var(--bg) 40%, transparent); }
.selbar output { min-width:22ch; text-align:center; }
@media (max-width:720px) { .motif-row, .ios-row { grid-template-columns:1fr; } .panorama { grid-template-columns:repeat(4, 1fr); } }
`;

const JS = `
const KEY = 'supporter-auswahl';
const saved = new Set(JSON.parse(localStorage.getItem(KEY) || '[]'));
const picks = [...document.querySelectorAll('.pick')];
const out = document.querySelector('#count');
const label = { icon: 'Icons', badge: 'Badges', background: 'Hintergründe', palette: 'Paletten' };
function sync() {
  picks.forEach((p) => p.setAttribute('aria-pressed', saved.has(p.dataset.kind + ':' + p.dataset.id)));
  out.value = saved.size === 0 ? 'Noch nichts ausgewählt' : saved.size + ' ausgewählt';
  localStorage.setItem(KEY, JSON.stringify([...saved]));
}
picks.forEach((p) => p.addEventListener('click', () => {
  const k = p.dataset.kind + ':' + p.dataset.id;
  saved.has(k) ? saved.delete(k) : saved.add(k);
  sync();
}));
document.querySelector('#copy').addEventListener('click', async () => {
  const groups = {};
  [...saved].forEach((k) => { const [kind, id] = k.split(':'); (groups[kind] ||= []).push(id); });
  const text = Object.entries(groups).map(([k, ids]) => label[k] + ': ' + ids.join(', ')).join('\\n');
  await navigator.clipboard.writeText(text || 'Keine Auswahl');
  out.value = 'Auswahl kopiert';
});
document.querySelector('#reset').addEventListener('click', () => { saved.clear(); sync(); });
const root = document.documentElement;
const modeButtons = document.querySelectorAll('.mode button');
function setMode(m) { root.dataset.mode = m; modeButtons.forEach((b) => b.setAttribute('aria-pressed', b.dataset.mode === m)); }
modeButtons.forEach((b) => b.addEventListener('click', () => setMode(b.dataset.mode)));
setMode(matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
sync();
`;

export function buildPreview({ ios } = {}) {
  const panorama = MOTIFS.map((m) => `<img src="icons/${m.id}-abend.svg" alt="${esc(m.label)} am Abend">`).join('');
  return `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Supporter-Designs – Entwürfe</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:wght@400;700&family=Bricolage+Grotesque:opsz,wdth,wght@12..96,75..100,400..700&display=swap" rel="stylesheet">
<style>${CSS}</style>
</head>
<body>
<div class="wrap">
<header class="top">
<div>
<h1>Supporter-Designs</h1>
<p>Entwürfe für App-Icons, Badges, Hintergründe und Farbpaletten. Tippe an, was dir gefällt; die Auswahl bleibt im Browser gespeichert und lässt sich unten als Liste kopieren.</p>
</div>
<div class="mode" role="group" aria-label="Darstellung"><button type="button" data-mode="light">Hell</button><button type="button" data-mode="dark">Dunkel</button></div>
</header>
<div class="panorama" aria-hidden="true">${panorama}</div>
${iconsSection()}
${iosSection(ios)}
${badgesSection()}
${backgroundsSection()}
${palettesSection()}
</div>
<div class="selbar"><output id="count" aria-live="polite"></output><button type="button" id="copy">Auswahl kopieren</button><button type="button" class="ghost" id="reset">Auswahl leeren</button></div>
<script>${JS}</script>
</body>
</html>
`;
}
