#!/usr/bin/env node
// Prueft die Store-Texte aus content.js und legt Metadaten und Screenshots
// fuer Fastlane (deliver/supply) unter fastlane/build/ ab.
//
// Nutzung (Node 22, keine Pakete):
//   node assets/workfiles/store/export_fastlane.mjs              # pruefen + exportieren
//   node assets/workfiles/store/export_fastlane.mjs --nur-pruefen # nur Texte pruefen
//
// Voraussetzung fuer den Export: render.sh hat out/<sprache>/ erzeugt.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const DIR = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(DIR, '../../..');
const OUT = path.join(DIR, 'out');
const BUILD = path.join(ROOT, 'fastlane', 'build');
const nurPruefen = process.argv.includes('--nur-pruefen');

// Store-Sprachcodes je Sprache aus content.js.
const LOCALES = { de: 'de-DE', en: 'en-US' };
// Hoechstzahl Screenshots je Geraeteklasse.
const MAX_SHOTS = { appStore: 10, play: 8 };

const context = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(DIR, 'content.js'), 'utf8'), context);
const STORE = context.window.STORE;

const fehler = [];
const hinweise = [];
const laenge = (s) => [...s].length;

// Aktiver Text einer Zeile: erste Variante oder der referenzierte Langtext.
function aktiv(entry, lang) {
  return entry.ref ? STORE[entry.ref]?.[lang] : entry[lang]?.[0];
}

function pruefeTexte(lang) {
  for (const [store, list] of Object.entries(STORE.texts)) {
    for (const entry of list) {
      const varianten = entry.ref ? [STORE[entry.ref]?.[lang]] : entry[lang] ?? [];
      if (varianten.length === 0 || varianten.some((v) => !v || !v.trim())) {
        fehler.push(`${store}/${entry.key} [${lang}]: Text fehlt`);
        continue;
      }
      varianten.forEach((v, i) => {
        const n = laenge(v);
        if (n > entry.limit) {
          fehler.push(`${store}/${entry.key} [${lang}] Variante ${i + 1}: ${n} von ${entry.limit} Zeichen`);
        }
      });
    }
  }
  const keywords = STORE.texts.appStore.find((e) => e.file === 'keywords');
  const kw = keywords && aktiv(keywords, lang);
  if (kw && /,\s/.test(kw)) fehler.push(`appStore/Keywords [${lang}]: Leerzeichen nach Komma verschenkt Zeichen`);
  STORE.slides.forEach((s, i) => {
    if (!s[lang]?.headline || !s[lang]?.subline) fehler.push(`Slide ${i + 1} (${s.scene}) [${lang}]: headline/subline fehlt`);
  });
  if (!STORE.featureGraphic.claim?.[lang]) fehler.push(`featureGraphic.claim [${lang}] fehlt`);
  if (!STORE.appStore.header.claim?.[lang]) fehler.push(`appStore.header.claim [${lang}] fehlt`);
  if (!STORE.appStore.search[lang]?.headline) fehler.push(`appStore.search [${lang}] fehlt`);
}

for (const lang of STORE.languages) pruefeTexte(lang);
if (STORE.slides.length > MAX_SHOTS.play) {
  fehler.push(`${STORE.slides.length} Slides, Google Play erlaubt höchstens ${MAX_SHOTS.play}`);
}

if (fehler.length) {
  console.error('FEHLER in content.js:');
  for (const f of fehler) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(`Texte ok (${STORE.languages.join(', ')}).`);
if (nurPruefen) process.exit(0);

// ---------- Export ----------

function pngs(dir, prefix) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter((f) => f.startsWith(prefix) && f.endsWith('.png')).sort();
}

function schreibe(datei, inhalt) {
  fs.mkdirSync(path.dirname(datei), { recursive: true });
  fs.writeFileSync(datei, `${inhalt.trim()}\n`);
}

function kopiere(von, nach) {
  fs.mkdirSync(path.dirname(nach), { recursive: true });
  fs.copyFileSync(von, nach);
}

fs.rmSync(BUILD, { recursive: true, force: true });
const zusammenfassung = [];

for (const lang of STORE.languages) {
  const locale = LOCALES[lang];
  const out = path.join(OUT, lang);
  if (!fs.existsSync(out)) {
    console.error(`FEHLER: ${path.relative(ROOT, out)} fehlt – zuerst render.sh <stil> ${lang} ausführen.`);
    process.exit(1);
  }

  // App Store (deliver): nur Felder aus content.js; URLs und
  // Datenschutzangaben bleiben unangetastet, weil die Dateien fehlen.
  const iosMeta = path.join(BUILD, 'metadata', 'ios', locale);
  for (const entry of STORE.texts.appStore) schreibe(path.join(iosMeta, `${entry.file}.txt`), aktiv(entry, lang));

  const iosShots = path.join(BUILD, 'screenshots', 'ios', locale);
  for (const geraet of ['iphone', 'ipad']) {
    const dateien = pngs(path.join(out, geraet), `${geraet}-`);
    if (dateien.length === 0) {
      console.error(`FEHLER: keine Screenshots in ${path.relative(ROOT, path.join(out, geraet))}`);
      process.exit(1);
    }
    if (dateien.length > MAX_SHOTS.appStore) {
      console.error(`FEHLER: ${dateien.length} ${geraet}-Screenshots, App Store erlaubt höchstens ${MAX_SHOTS.appStore}`);
      process.exit(1);
    }
    for (const f of dateien) kopiere(path.join(out, geraet, f), path.join(iosShots, f));
  }

  // Google Play (supply).
  const play = path.join(BUILD, 'metadata', 'android', locale);
  for (const entry of STORE.texts.play) schreibe(path.join(play, `${entry.file}.txt`), aktiv(entry, lang));
  const phone = pngs(path.join(out, 'play'), 'play-');
  const tablet = pngs(path.join(out, 'playtablet'), 'playtablet-');
  phone.forEach((f, i) => kopiere(path.join(out, 'play', f), path.join(play, 'images', 'phoneScreenshots', `${i + 1}_${f}`)));
  tablet.forEach((f, i) => kopiere(path.join(out, 'playtablet', f), path.join(play, 'images', 'tenInchScreenshots', `${i + 1}_${f}`)));
  kopiere(path.join(out, 'play', 'feature-graphic.png'), path.join(play, 'images', 'featureGraphic.png'));

  zusammenfassung.push(`  ${locale}: App Store ${pngs(path.join(out, 'iphone'), 'iphone-').length} iPhone + ${pngs(path.join(out, 'ipad'), 'ipad-').length} iPad, Play ${phone.length} Phone + ${tablet.length} Tablet + Vorstellungsgrafik`);

  // Formate, die deliver nicht kennt: von Hand in App Store Connect.
  const hand = ['appstore/header.png', 'appstore/search.png'];
  if (fs.existsSync(path.join(out, 'duo'))) hand.push('duo/');
  hinweise.push(`  ${locale}: ${hand.map((h) => `out/${lang}/${h}`).join(', ')}`);
}

console.log(`Export nach ${path.relative(ROOT, BUILD)}/:`);
for (const z of zusammenfassung) console.log(z);
console.log('Von Hand in App Store Connect hochladen (kein Fastlane-Format):');
for (const h of hinweise) console.log(h);
