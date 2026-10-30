// Exportiert das Standard-App-Icon in die App:
// - iOS: Icon-Composer-Bundle ios/Runner/NamiAppIcon.icon (Liquid Glass, Ebenen
//   je Gruppe, eigene Ebenen für dunkel), Kontrollbilder nach design/marke/vorschau/
// - Android: adaptives Icon mit Verlauf, Vordergrund und Monochrom-Ebene sowie
//   Legacy-Icons für API 24/25
// - Flutter: assets/icon/icon.png (Sperre, Sichtschutz, Startbühne, Erscheinungsbild)
//
//   node design/marke/export_app_icons.mjs
//
// Braucht Google Chrome (Rastern) und Xcode 26 oder neuer (ictool).
import { execFileSync } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { rasterize } from '../supporter/lib/raster.mjs';
import { FARBEN, icon } from './lib/marke.mjs';

const root = dirname(fileURLToPath(import.meta.url));
const repo = join(root, '..', '..');
const tmp = join(root, '.build');
const vorschau = join(root, 'vorschau');
const ICTOOL =
  process.env.ICTOOL ?? '/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool';

const srgb = (hex) => {
  const [r, g, b] = hex.match(/\w\w/g).map((h) => (parseInt(h, 16) / 255).toFixed(5));
  return `srgb:${r},${g},${b},1.00000`;
};

// ---------- iOS ----------
// Gruppen von vorne nach hinten; Icon Composer zeichnet die erste oben.
const GRUPPEN = [
  { name: 'knoten', ebenen: ['knoten'], schatten: 0.35 },
  { name: 'tuch', ebenen: ['zipfel', 'tuch'], schatten: 0.3 },
  { name: 'personen', ebenen: ['person'], schatten: 0.45 },
  { name: 'zeilen', ebenen: ['zeilen'], schatten: 0.15 },
];

const bundle = join(repo, 'ios/Runner/NamiAppIcon.icon');
rmSync(bundle, { recursive: true, force: true });
mkdirSync(join(bundle, 'Assets'), { recursive: true });
const groups = [];
for (const g of GRUPPEN) {
  for (const modus of ['hell', 'dunkel']) {
    rasterize(icon(modus, { ebenen: g.ebenen }), join(bundle, 'Assets', `${g.name}-${modus}.png`), 1024, tmp);
  }
  groups.push({
    layers: [
      { 'image-name': `${g.name}-dunkel.png`, name: `${g.name}-dunkel`, 'hidden-specializations': [{ value: true }, { appearance: 'dark', value: false }] },
      { 'image-name': `${g.name}-hell.png`, name: `${g.name}-hell`, 'hidden-specializations': [{ appearance: 'dark', value: true }] },
    ],
    shadow: { kind: 'neutral', opacity: g.schatten },
    translucency: { enabled: false, value: 0 },
  });
}
writeFileSync(
  join(bundle, 'icon.json'),
  `${JSON.stringify(
    {
      fill: {
        'linear-gradient': FARBEN.hell.grund.map(srgb),
        orientation: { start: { x: 0.35, y: 0 }, stop: { x: 0.65, y: 1 } },
      },
      groups,
      'supported-platforms': { squares: 'shared' },
    },
    null,
    2,
  )}\n`,
);

rmSync(vorschau, { recursive: true, force: true });
mkdirSync(vorschau, { recursive: true });
const RENDITIONS = ['Default', 'Dark', 'TintedLight', 'TintedDark', 'ClearLight', 'ClearDark'];
for (const r of RENDITIONS) {
  execFileSync(ICTOOL, [bundle, '--export-image', '--output-file', join(vorschau, `ios-${r}.png`), '--platform', 'iOS', '--rendition', r, '--width', '256', '--height', '256', '--scale', '1', '--design-generation', '27']);
}

// ---------- Android ----------
const res = join(repo, 'android/app/src/main/res');
// Adaptiv: 108 dp Fläche, davon 72 dp sichtbar; der Rand ergänzt 29 Einheiten je Seite.
const RAND = 29;
const DICHTEN = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
for (const [dichte, f] of Object.entries(DICHTEN)) {
  const ordner = join(res, `mipmap-${dichte}`);
  mkdirSync(ordner, { recursive: true });
  rasterize(icon('hell', { ebenen: ['person', 'zeilen', 'zipfel', 'tuch', 'knoten'], rand: RAND }), join(ordner, 'ic_launcher_foreground.png'), 108 * f, tmp);
  rasterize(icon('hell', { ebenen: ['person', 'zeilen'], rand: RAND, mono: true }), join(ordner, 'ic_launcher_monochrome.png'), 108 * f, tmp);
  rasterize(icon('hell'), join(ordner, 'ic_launcher.png'), 48 * f, tmp, { radius: 9 * f });
  rasterize(icon('hell'), join(ordner, 'ic_launcher_round.png'), 48 * f, tmp, { radius: 24 * f });
}
const [oben, unten] = FARBEN.hell.grund;
writeFileSync(
  join(res, 'drawable/ic_launcher_verlauf.xml'),
  `<?xml version="1.0" encoding="utf-8"?>
<!-- Hintergrund des Standard-App-Icons, erzeugt von design/marke/export_app_icons.mjs -->
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
  <gradient android:angle="270" android:startColor="${oben}" android:endColor="${unten}" />
</shape>
`,
);
const adaptiv = `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@drawable/ic_launcher_verlauf" />
  <foreground android:drawable="@mipmap/ic_launcher_foreground" />
  <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
`;
writeFileSync(join(res, 'mipmap-anydpi-v26/ic_launcher.xml'), adaptiv);
writeFileSync(join(res, 'mipmap-anydpi-v26/ic_launcher_round.xml'), adaptiv);

// ---------- Flutter ----------
rasterize(icon('hell'), join(repo, 'assets/icon/icon.png'), 1080, tmp);

// Kontrollbilder Android: Vordergrund auf Verlauf, rund und als Kachel maskiert.
for (const [name, radius] of [['android-kreis', 96], ['android-kachel', 36]]) {
  rasterize(icon('hell', { rand: RAND }), join(vorschau, `${name}.png`), 192, tmp, { radius });
}
rasterize(icon('hell', { ebenen: ['person', 'zeilen'], rand: RAND, mono: true }), join(vorschau, 'android-monochrom.png'), 192, tmp, { radius: 96 });

rmSync(tmp, { recursive: true, force: true });
console.log(`iOS: ${bundle}\nAndroid: ${Object.keys(DICHTEN).length} Dichten\nFlutter: assets/icon/icon.png\nKontrollbilder: ${vorschau}`);
