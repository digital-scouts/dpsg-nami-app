// Erzeugt alle Supporter-Entwuerfe: node design/supporter/generate.mjs
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { MOTIFS, TIMES, buildIcon } from './lib/icons.mjs';
import { BACKGROUNDS } from './lib/backgrounds.mjs';
import { PALETTES } from './lib/palettes.mjs';
import { RUNDE3, SZENEN, buildRunde3Entwurf, buildRunde3Page, buildSzenenEntwurf, buildSzenenPage, buildWaldseeKohte } from './lib/entwurf_szenen.mjs';
import { ENTWUERFE, buildLagerfeuerNachtEntwurf, buildLagerfeuerNachtPage } from './lib/entwurf_lagerfeuer_nacht.mjs';
import { buildPreview } from './lib/preview.mjs';
import { buildEntwurfIconsPage, entwurfIconFiles } from './lib/entwurf_icons.mjs';
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

// Freigegebene Szenen (Feedback-Runden 1-5, Waldsee mit Kohte aus Icons-Runde 1). Die App zeichnet diese nach:
// lib/presentation/widgets/supporter_background_painter.dart
const FINAL_BACKGROUNDS = {
  'lagerfeuer-light': () => buildRunde3Entwurf(RUNDE3.find((e) => e.id === 'lagerfeuer-tag')),
  'lagerfeuer-dark': () => buildLagerfeuerNachtEntwurf('b'),
  'nachthimmel-light': () => buildRunde3Entwurf(RUNDE3.find((e) => e.id === 'himmel-tag')),
  'nachthimmel-dark': () => buildRunde3Entwurf(RUNDE3.find((e) => e.id === 'himmel-nacht')),
  'waldsee-light': () => buildWaldseeKohte(false, 'links'),
  'waldsee-dark': () => buildWaldseeKohte(true, 'links'),
};
for (const bg of BACKGROUNDS) {
  for (const mode of ['light', 'dark']) out(`backgrounds/${bg.id}-${mode}.svg`, FINAL_BACKGROUNDS[`${bg.id}-${mode}`]());
}
for (const entwurf of ENTWUERFE) {
  out(`backgrounds/entwurf-lagerfeuer-nacht-${entwurf.id}.svg`, buildLagerfeuerNachtEntwurf(entwurf.id));
}
out('entwurf-lagerfeuer-nacht.html', buildLagerfeuerNachtPage());
for (const szene of SZENEN) {
  for (const variant of szene.variants) {
    out(`backgrounds/entwurf-${szene.id}-${variant.id}.svg`, buildSzenenEntwurf(szene, variant));
  }
}
out('entwurf-szenen.html', buildSzenenPage());
for (const entry of RUNDE3.filter((e) => e.build)) {
  out(`backgrounds/entwurf3-${entry.id}.svg`, buildRunde3Entwurf(entry));
}
out('entwurf-szenen-4.html', buildRunde3Page());
for (const file of entwurfIconFiles()) out(file.path, file.content);
out('entwurf-icons-runde-2.html', buildEntwurfIconsPage());
out('palettes.json', JSON.stringify(PALETTES, null, 2) + '\n');
const iosManifest = join(root, 'ios', 'icons.json');
const ios = existsSync(iosManifest) ? JSON.parse(readFileSync(iosManifest, 'utf8')) : null;
out('preview.html', buildPreview({ ios }));

console.log(`${badges.length} Badges erzeugt`);
console.log(`${icons.length} Icons erzeugt`);
