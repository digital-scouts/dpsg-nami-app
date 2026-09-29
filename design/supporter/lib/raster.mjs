// SVG -> PNG ueber Chrome headless (transparenter Hintergrund).
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const CHROME = process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

export function rasterize(svg, pngPath, size, tmpDir, { radius = 0 } = {}) {
  mkdirSync(tmpDir, { recursive: true });
  const svgPath = join(tmpDir, 'layer.svg');
  const htmlPath = join(tmpDir, 'layer.html');
  writeFileSync(svgPath, svg);
  writeFileSync(
    htmlPath,
    `<html><body style="margin:0;background:transparent"><img src="layer.svg" width="${size}" height="${size}" style="display:block;border-radius:${radius}px"></body></html>`,
  );
  execFileSync(
    CHROME,
    [
      '--headless',
      '--disable-gpu',
      '--hide-scrollbars',
      '--allow-file-access-from-files',
      '--default-background-color=00000000',
      '--force-device-scale-factor=1',
      `--window-size=${size},${size}`,
      `--screenshot=${pngPath}`,
      `file://${htmlPath}`,
    ],
    { stdio: 'ignore' },
  );
}
