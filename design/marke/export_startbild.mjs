// Exportiert das native Startbild der Startbühne (#279): senkrechter Verlauf
// in der Standard-Primärfarbe und mittig die Person ohne Halstuch, 160 pt.
// Flutter übernimmt davon pixelgleich (`StartbuehneFlaeche`, `StartbuehnePerson`).
//
//   node design/marke/export_startbild.mjs
//
// - iOS: LaunchFlaeche.imageset (hell, dunkel) und LaunchImage.imageset
// - Android: drawable-*/startbild_person.png, Farben in values(-night)/startbild_farben.xml
//
// Braucht Google Chrome (Rastern).
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { rasterize } from '../supporter/lib/raster.mjs';
import { startFlaeche, startPerson, startVerlauf } from './lib/marke.mjs';

const root = dirname(fileURLToPath(import.meta.url));
const repo = join(root, '..', '..');
const tmp = join(root, '.build');
const PUNKTE = 160;

// ---------- iOS ----------
const assets = join(repo, 'ios/Runner/Assets.xcassets');
const imageset = (name, dateien) => {
  const ordner = join(assets, `${name}.imageset`);
  rmSync(ordner, { recursive: true, force: true });
  mkdirSync(ordner, { recursive: true });
  writeFileSync(join(ordner, 'Contents.json'), `${JSON.stringify({ images: dateien, info: { author: 'xcode', version: 1 } }, null, 2)}\n`);
  return ordner;
};

const flaeche = imageset('LaunchFlaeche', [
  { filename: 'LaunchFlaeche.png', idiom: 'universal' },
  { appearances: [{ appearance: 'luminosity', value: 'dark' }], filename: 'LaunchFlaeche-dunkel.png', idiom: 'universal' },
]);
rasterize(startFlaeche('hell'), join(flaeche, 'LaunchFlaeche.png'), 512, tmp);
rasterize(startFlaeche('dunkel'), join(flaeche, 'LaunchFlaeche-dunkel.png'), 512, tmp);

const person = imageset(
  'LaunchImage',
  [1, 2, 3].map((f) => ({ filename: `LaunchImage${f > 1 ? `@${f}x` : ''}.png`, idiom: 'universal', scale: `${f}x` })),
);
for (const f of [1, 2, 3]) {
  rasterize(startPerson(), join(person, `LaunchImage${f > 1 ? `@${f}x` : ''}.png`), PUNKTE * f, tmp);
}

// ---------- Android ----------
const res = join(repo, 'android/app/src/main/res');
const DICHTEN = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
for (const [dichte, f] of Object.entries(DICHTEN)) {
  const ordner = join(res, `drawable-${dichte}`);
  mkdirSync(ordner, { recursive: true });
  rasterize(startPerson(), join(ordner, 'startbild_person.png'), PUNKTE * f, tmp);
}
for (const [modus, ordner] of [['hell', 'values'], ['dunkel', 'values-night']]) {
  const [oben, mitte, unten] = startVerlauf(modus);
  mkdirSync(join(res, ordner), { recursive: true });
  writeFileSync(
    join(res, ordner, 'startbild_farben.xml'),
    `<?xml version="1.0" encoding="utf-8"?>
<!-- Verlauf der Startbühne (${modus}), erzeugt von design/marke/export_startbild.mjs -->
<resources>
    <color name="startflaeche_oben">${oben}</color>
    <color name="startflaeche_mitte">${mitte}</color>
    <color name="startflaeche_unten">${unten}</color>
</resources>
`,
  );
}

rmSync(tmp, { recursive: true, force: true });
console.log('Startbild für iOS (LaunchFlaeche, LaunchImage) und Android (startbild_person, startbild_farben) exportiert');
