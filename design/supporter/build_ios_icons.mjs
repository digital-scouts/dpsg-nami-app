// Baut finale Icon-Composer-Bundles (iOS 26/27, Liquid Glass) aus den Szenen.
// node design/supporter/build_ios_icons.mjs
//
// Pro Motiv (ein Paket) entsteht je Tageszeit ein festes Icon, dazu ein
// automatisches Icon, das dem Systemmodus folgt: hell = Morgen, dunkel = Nacht.
import { execFileSync } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LAYER_NAMES, MOTIFS, TIMES, buildIconLayers } from './lib/icons.mjs';
import { rasterize } from './lib/raster.mjs';

const root = dirname(fileURLToPath(import.meta.url));
const iosDir = join(root, 'ios');
const tmpDir = join(root, '.build');
const ICTOOL =
  process.env.ICTOOL ?? '/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool';

const pascal = (id) =>
  id
    .split('-')
    .map((p) => p[0].toUpperCase() + p.slice(1))
    .join('');

const rasterizeLayer = (svg, pngPath) => rasterize(svg, pngPath, 1024, tmpDir);

// Gruppen von vorne nach hinten; Icon Composer zeichnet die erste Gruppe oben.
const GROUP_STYLE = {
  vorne: { shadow: { kind: 'neutral', opacity: 0.5 }, translucency: { enabled: false, value: 0 } },
  mitte: { shadow: { kind: 'neutral', opacity: 0.25 }, translucency: { enabled: false, value: 0 } },
  hinten: { shadow: { kind: 'none', opacity: 0 }, translucency: { enabled: false, value: 0 } },
};

function layer(image, hidden) {
  const l = { 'image-name': image, name: image.replace('.png', '') };
  if (hidden === 'light') l['hidden-specializations'] = [{ appearance: 'dark', value: true }];
  if (hidden === 'dark') l['hidden-specializations'] = [{ value: true }, { appearance: 'dark', value: false }];
  return l;
}

function iconJson(groups) {
  return {
    fill: 'automatic',
    groups: [...LAYER_NAMES].reverse().map((name) => ({ layers: groups[name], ...GROUP_STYLE[name] })),
    'supported-platforms': { squares: 'shared' },
  };
}

function writeBundle(name, groups, assets) {
  const bundle = join(iosDir, `${name}.icon`);
  rmSync(bundle, { recursive: true, force: true });
  mkdirSync(join(bundle, 'Assets'), { recursive: true });
  for (const [file, svg] of assets) rasterizeLayer(svg, join(bundle, 'Assets', file));
  writeFileSync(join(bundle, 'icon.json'), JSON.stringify(iconJson(groups), null, 2) + '\n');
  return bundle;
}

const RENDITIONS = ['Default', 'Dark', 'TintedLight', 'ClearLight'];

function renderPreviews(bundle, name) {
  for (const r of RENDITIONS) {
    execFileSync(ICTOOL, [
      bundle,
      '--export-image',
      '--output-file',
      join(iosDir, 'previews', `${name}-${r}.png`),
      '--platform',
      'iOS',
      '--rendition',
      r,
      '--width',
      '256',
      '--height',
      '256',
      '--scale',
      '1',
      '--design-generation',
      '27',
    ]);
  }
}

rmSync(iosDir, { recursive: true, force: true });
mkdirSync(join(iosDir, 'previews'), { recursive: true });
mkdirSync(tmpDir, { recursive: true });

const built = [];
for (const motif of MOTIFS) {
  const layersByTime = Object.fromEntries(Object.keys(TIMES).map((t) => [t, buildIconLayers(motif.id, t)]));

  for (const time of Object.keys(TIMES)) {
    const name = `${pascal(motif.id)}${pascal(time)}`;
    const assets = LAYER_NAMES.map((l, i) => [`${l}.png`, layersByTime[time][i]]);
    const groups = Object.fromEntries(LAYER_NAMES.map((l) => [l, [layer(`${l}.png`)]]));
    renderPreviews(writeBundle(name, groups, assets), name);
    built.push(name);
  }

  {
    const day = 'morgen';
    const name = `${pascal(motif.id)}Automatisch`;
    const assets = [];
    const groups = {};
    LAYER_NAMES.forEach((l, i) => {
      assets.push([`${l}-tag.png`, layersByTime[day][i]], [`${l}-nacht.png`, layersByTime.nacht[i]]);
      groups[l] = [layer(`${l}-nacht.png`, 'dark'), layer(`${l}-tag.png`, 'light')];
    });
    renderPreviews(writeBundle(name, groups, assets), name);
    built.push(name);
  }
}

rmSync(tmpDir, { recursive: true, force: true });
writeFileSync(join(iosDir, 'icons.json'), JSON.stringify({ renditions: RENDITIONS, icons: built }, null, 2) + '\n');
console.log(`${built.length} Icon-Composer-Bundles unter ios/ erzeugt`);
