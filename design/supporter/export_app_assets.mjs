// Kopiert die freigegebenen Entwuerfe in die App.
// Voraussetzung: build_ios_icons.mjs wurde ausgefuehrt.
// node design/supporter/export_app_assets.mjs
import { cpSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { BADGE_COLORS, BADGE_MOTIFS, FOERDERER_BADGES, buildBadge, buildFoerdererBadge } from './lib/badges.mjs';
import { MOTIFS, buildIcon } from './lib/icons.mjs';
import { rasterize } from './lib/raster.mjs';

const root = dirname(fileURLToPath(import.meta.url));
const repo = join(root, '..', '..');
const tmpDir = join(root, '.build');
const res = join(repo, 'android/app/src/main/res');

const snake = (id) => id.replaceAll('-', '_');
const pascal = (id) =>
  id
    .split('-')
    .map((p) => p[0].toUpperCase() + p.slice(1))
    .join('');

// Badges fuer Flutter: ohne SMIL-Schimmer (flutter_svg animiert nicht).
const stripShimmer = (svg) =>
  svg
    .replace(/<linearGradient id="shine"[\s\S]*?<\/linearGradient>/, '')
    .replace(/<path [^>]*fill="url\(#shine\)"\/>/g, '');

const badgeDir = join(repo, 'assets/supporter/badges');
rmSync(badgeDir, { recursive: true, force: true });
mkdirSync(badgeDir, { recursive: true });
for (const motif of BADGE_MOTIFS) {
  for (const color of BADGE_COLORS) {
    writeFileSync(join(badgeDir, `${motif.id}-${color.id}.svg`), buildBadge(motif.id, color.id));
  }
}
for (const badge of FOERDERER_BADGES) {
  writeFileSync(join(badgeDir, `${badge.id}.svg`), stripShimmer(buildFoerdererBadge(badge)));
}

// Android: adaptives Icon (Szene als Hintergrund, leerer Vordergrund) und
// Legacy-Icon fuer API 24/25. Namen: ic_launcher_<motiv>_<zeit>.
const ANDROID_TIMES = ['morgen', 'abend', 'nacht'];
mkdirSync(join(res, 'drawable-nodpi'), { recursive: true });
mkdirSync(join(res, 'mipmap-anydpi-v26'), { recursive: true });
mkdirSync(join(res, 'mipmap-xxxhdpi'), { recursive: true });
const aliases = [];
for (const motif of MOTIFS) {
  for (const time of ANDROID_TIMES) {
    const name = `ic_launcher_${snake(motif.id)}_${time}`;
    const svg = buildIcon(motif.id, time);
    rasterize(svg, join(res, 'drawable-nodpi', `${name}_background.png`), 432, tmpDir);
    rasterize(svg, join(res, 'mipmap-xxxhdpi', `${name}.png`), 192, tmpDir, { radius: 36 });
    writeFileSync(
      join(res, 'mipmap-anydpi-v26', `${name}.xml`),
      `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@drawable/${name}_background" />
  <foreground android:drawable="@android:color/transparent" />
</adaptive-icon>
`,
    );
    aliases.push({ alias: `.Icon${pascal(motif.id)}${pascal(time)}`, icon: `@mipmap/${name}` });
  }
}

// Vorschaubilder fuer die Auswahl in der App (Erscheinungsbild).
const thumbDir = join(repo, 'assets/supporter/icons');
rmSync(thumbDir, { recursive: true, force: true });
mkdirSync(thumbDir, { recursive: true });
for (const motif of MOTIFS) {
  for (const time of ANDROID_TIMES) {
    rasterize(buildIcon(motif.id, time), join(thumbDir, `${pascal(motif.id)}${pascal(time)}.png`), 192, tmpDir);
  }
}

// iOS: Icon-Composer-Bundles neben NamiAppIcon.icon.
const iosRunner = join(repo, 'ios/Runner');
const iosNames = [];
for (const motif of MOTIFS) {
  for (const suffix of ['Morgen', 'Abend', 'Nacht', 'Automatisch']) {
    const name = `${pascal(motif.id)}${suffix}`;
    const target = join(iosRunner, `${name}.icon`);
    rmSync(target, { recursive: true, force: true });
    cpSync(join(root, 'ios', `${name}.icon`), target, { recursive: true });
    iosNames.push(name);
  }
}

rmSync(tmpDir, { recursive: true, force: true });
writeFileSync(join(root, 'ios', 'app_export.json'), JSON.stringify({ iosNames, aliases }, null, 2) + '\n');
console.log(`${iosNames.length} iOS-Icons, ${aliases.length} Android-Icons, Badges exportiert`);
