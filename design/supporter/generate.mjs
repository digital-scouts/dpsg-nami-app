// Erzeugt die Supporter-Designs (Icons, Badges, Hintergründe, Paletten, Übersicht):
// node design/supporter/generate.mjs
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { MOTIFS, TIMES, buildIcon } from './lib/icons.mjs';
import { BACKGROUNDS } from './lib/backgrounds.mjs';
import { PALETTES } from './lib/palettes.mjs';
import { buildSzene } from './lib/szenen.mjs';
import { buildPreview } from './lib/preview.mjs';
import { BADGE_COLORS, BADGE_MOTIFS, FOERDERER_BADGES, buildBadge, buildFoerdererBadge } from './lib/badges.mjs';

const root = dirname(fileURLToPath(import.meta.url));
const out = (rel, content) => {
  const file = join(root, rel);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, content);
};

const icons = [];
for (const motif of MOTIFS) {
  for (const time of Object.keys(TIMES)) {
    const id = `${motif.id}-${time}`;
    out(`icons/${id}.svg`, buildIcon(motif.id, time));
    icons.push({ id, motif: motif.id, motifLabel: motif.label, time, timeLabel: TIMES[time].label });
  }
}

const badges = [];
for (const motif of BADGE_MOTIFS) {
  for (const color of BADGE_COLORS) {
    const id = `${motif.id}-${color.id}`;
    out(`badges/${id}.svg`, buildBadge(motif.id, color.id));
    badges.push({ id, motif: motif.id, motifLabel: motif.label, color: color.id, colorLabel: color.label, tier: 'standard' });
  }
}
for (const badge of FOERDERER_BADGES) {
  out(`badges/${badge.id}.svg`, buildFoerdererBadge(badge));
  badges.push({ id: badge.id, motifLabel: badge.label, tier: 'foerderer' });
}

// Freigegebene Szenen; die App zeichnet sie nach:
// lib/presentation/widgets/supporter_background_painter.dart
for (const bg of BACKGROUNDS) {
  for (const mode of ['light', 'dark']) out(`backgrounds/${bg.id}-${mode}.svg`, buildSzene(`${bg.id}-${mode}`));
}
out('palettes.json', JSON.stringify(PALETTES, null, 2) + '\n');
const iosManifest = join(root, 'ios', 'icons.json');
const ios = existsSync(iosManifest) ? JSON.parse(readFileSync(iosManifest, 'utf8')) : null;
out('preview.html', buildPreview({ ios }));

console.log(`${badges.length} Badges erzeugt`);
console.log(`${icons.length} Icons erzeugt`);
