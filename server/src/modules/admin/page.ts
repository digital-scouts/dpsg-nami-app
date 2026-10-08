import type { MonthlyReportDocument, ReportFigures } from '../report/report.js';
import { STUFEN, type Stufe } from '../stammesSnapshot/schema.js';

// Serverseitig gerenderte Uebersicht ohne Skripte. DV- und Bezirks-IDs stammen aus den
// Snapshots der Apps und werden deshalb immer escaped.

const escapeHtml = (value: string): string =>
    value.replace(/[&<>"']/g, (zeichen) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[zeichen] ?? zeichen);

const STUFEN_NAMEN: Record<Stufe, string> = {
    biber: 'Biber',
    woelflinge: 'Wölflinge',
    jungpfadfinder: 'Jungpfadfinder',
    pfadfinder: 'Pfadfinder',
    rover: 'Rover',
};

const datum = (date: Date): string =>
    `${String(date.getUTCDate()).padStart(2, '0')}.${String(date.getUTCMonth() + 1).padStart(2, '0')}.${date.getUTCFullYear()}, `
    + `${String(date.getUTCHours()).padStart(2, '0')}:${String(date.getUTCMinutes()).padStart(2, '0')} UTC`;

const kennzahlen = (figures: ReportFigures): string => {
    const kachel = (wert: number, label: string, unter = '') =>
        `<div class="kpi"><b>${wert}</b><span>${escapeHtml(label)}</span>${unter ? `<small>${escapeHtml(unter)}</small>` : ''}</div>`;
    const { installationen, staemme, gruppen } = figures;
    return `<div class="kpis">
        ${kachel(staemme.teilnehmend, 'Stämme', `vollständig ${staemme.vollstaendig} · nur Gruppen ${staemme.nur_gruppen} · gemischt ${staemme.gemischt} · ohne verwertbare Werte ${staemme.ohne_werte ?? 0}`)}
        ${kachel(installationen.aktiv, 'aktive Installationen', `neu ${installationen.neu} · gesamt ${installationen.gesamt}`)}
        ${kachel(gruppen.mit_wert, 'Gruppen mit Wert', STUFEN.map((stufe) => `${STUFEN_NAMEN[stufe]} ${gruppen.je_stufe[stufe]}`).join(' · '))}
        ${kachel(staemme.mehrere_sender, 'Stämme mit mehreren Sendern', `Gruppen mehrfach abgedeckt ${gruppen.mehrfach_abgedeckt} · nicht verwendete Werte ${gruppen.verworfene_werte}`)}
    </div>`;
};

const regionen = (titel: string, werte: Record<string, number>, minStammCount: number): string => {
    const zeilen = Object.entries(werte).sort(([a, x], [b, y]) => y - x || a.localeCompare(b));
    if (zeilen.length === 0) {
        return `<section><h3>${escapeHtml(titel)}</h3><p class="muted">keine</p></section>`;
    }
    return `<section><h3>${escapeHtml(titel)}</h3><table><thead><tr><th>ID</th><th class="r">Stämme</th></tr></thead><tbody>${zeilen
        .map(([id, wert]) => `<tr><td>${escapeHtml(id)}</td><td class="r">${wert}${id !== 'unbekannt' && wert >= minStammCount ? ' <span class="ok">✓</span>' : ''}</td></tr>`)
        .join('')}</tbody></table></section>`;
};

// Linienverlauf von Staemmen und aktiven Installationen, aelteste Monate links.
const verlauf = (berichte: MonthlyReportDocument[]): string => {
    const punkte = [...berichte].reverse();
    if (punkte.length < 2) {
        return '';
    }
    const breite = 640;
    const hoehe = 160;
    const max = Math.max(1, ...punkte.flatMap((b) => [b.figures.staemme.teilnehmend, b.figures.installationen.aktiv]));
    const x = (i: number) => 36 + (i / (punkte.length - 1)) * (breite - 64);
    const y = (wert: number) => hoehe - 24 - (wert / max) * (hoehe - 40);
    const linie = (werte: number[], farbe: string) =>
        `<polyline fill="none" stroke="${farbe}" stroke-width="2.5" points="${werte.map((w, i) => `${x(i).toFixed(1)},${y(w).toFixed(1)}`).join(' ')}"/>`;
    const achse = punkte.map((b, i) =>
        `<text x="${x(i).toFixed(1)}" y="${hoehe - 6}" text-anchor="middle">${escapeHtml(b.month.slice(2))}</text>`).join('');
    return `<svg viewBox="0 0 ${breite} ${hoehe}" role="img" aria-label="Verlauf">
        <line x1="36" x2="${breite - 28}" y1="${hoehe - 24}" y2="${hoehe - 24}" stroke="#ddd"/>
        <text x="4" y="${y(max) + 4}">${max}</text>
        ${linie(punkte.map((b) => b.figures.staemme.teilnehmend), '#003056')}
        ${linie(punkte.map((b) => b.figures.installationen.aktiv), '#ff6400')}
        ${achse}
    </svg><p class="legende"><span style="color:#003056">■</span> Stämme <span style="color:#ff6400">■</span> aktive Installationen</p>`;
};

const tabelle = (berichte: MonthlyReportDocument[]): string => `<table><thead><tr>
    <th>Monat</th><th class="r">Stämme</th><th class="r">vollst.</th><th class="r">nur Gr.</th><th class="r">gemischt</th><th class="r">ohne W.</th>
    <th class="r">aktive Inst.</th><th class="r">neu</th><th class="r">Gruppen</th><th class="r">mehrfach</th><th class="r">verworfen</th>
    </tr></thead><tbody>${berichte.map(({ month, figures: f }) => `<tr><td>${escapeHtml(month)}</td>
    <td class="r">${f.staemme.teilnehmend}</td><td class="r">${f.staemme.vollstaendig}</td><td class="r">${f.staemme.nur_gruppen}</td><td class="r">${f.staemme.gemischt}</td><td class="r">${f.staemme.ohne_werte ?? 0}</td>
    <td class="r">${f.installationen.aktiv}</td><td class="r">${f.installationen.neu}</td><td class="r">${f.gruppen.mit_wert}</td>
    <td class="r">${f.gruppen.mehrfach_abgedeckt}</td><td class="r">${f.gruppen.verworfene_werte}</td></tr>`).join('')}</tbody></table>`;

export const renderAdminPage = (
    aktuell: ReportFigures,
    berichte: MonthlyReportDocument[],
    minStammCount: number,
    version: string,
): string => `<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>NaMi-Statistik</title>
<style>
body{font:15px/1.45 system-ui,sans-serif;margin:0;background:#f5f5f7;color:#1c1c1e}
main{max-width:960px;margin:0 auto;padding:24px 16px 48px}
h1{font-size:24px;margin:0 0 4px}h2{font-size:18px;margin:32px 0 10px}h3{font-size:15px;margin:0 0 8px}
.muted,.legende{color:#8e8e93;font-size:13px}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px}
.kpi{background:#fff;border-radius:14px;padding:14px 16px;display:flex;flex-direction:column}
.kpi b{font-size:30px;color:#003056}.kpi small{color:#8e8e93;font-size:12.5px;margin-top:4px}
table{width:100%;border-collapse:collapse;background:#fff;border-radius:14px;overflow:hidden;font-size:14px}
th,td{padding:7px 10px;border-bottom:1px solid #ececf0;text-align:left;font-variant-numeric:tabular-nums}
th{font-size:12px;color:#8e8e93;font-weight:600}.r{text-align:right}.ok{color:#24561a;font-weight:700}
.regionen{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}
svg{width:100%;height:auto;background:#fff;border-radius:14px}svg text{font-size:9px;fill:#8e8e93}
</style></head><body><main>
<h1>NaMi-Statistik</h1>
<p class="muted">Stand ${escapeHtml(datum(aktuell.stichtag))} · Version ${escapeHtml(version)} · nur Zählwerte, keine Stammes- oder Personendaten</p>
<h2>Laufender Monat ${escapeHtml(aktuell.month)} (bis heute)</h2>
${kennzahlen(aktuell)}
<h2>Regionen</h2>
<p class="muted">✓ ab ${minStammCount} Stämmen, ab dann wären regionale Vergleiche möglich.</p>
<div class="regionen">${regionen('Stämme je DV', aktuell.staemme_je_dv, minStammCount)}${regionen('Stämme je Bezirk', aktuell.staemme_je_bezirk, minStammCount)}</div>
<h2>Verlauf</h2>
${berichte.length === 0 ? '<p class="muted">Noch keine abgeschlossenen Monate.</p>' : `${verlauf(berichte)}${tabelle(berichte)}`}
<p class="muted">Stichtag eines Monats ist sein letzter Tag; es zählen Snapshots der zwei Monate davor.</p>
</main></body></html>`;
