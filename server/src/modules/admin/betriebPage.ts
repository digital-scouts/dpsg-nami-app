import { type MeldungDocument, PLATTFORM_NAMEN, type VersionDocument } from '../appFeeds/model.js';
import { type Befund, meldungStatus } from '../appFeeds/pruefung.js';
import { ADMIN_STYLE, adminNav, datum, escapeHtml } from './page.js';

// Betriebsuebersicht unter /admin/betrieb (design/entscheidung/2026-10-10-admin-betrieb.md,
// 2026-10-10-admin-pflege.md): Pruefung zuerst, dann Betrieb, dann eine Karte mit Meldungen und
// Versionen fuer die App und Links zu ihrer Pflege.

export type BetriebsDaten = {
    stand: Date;
    version: string;
    datenbank: 'ok' | 'fehler';
    letztesBackup: Date | null;
    letztesAggregat: Date | null;
    letzterMonatsreport: string | null;
    letzterSnapshot: Date | null;
    snapshotsLetzte7Tage: number;
    naechsteSnapshotLoeschung: Date | null;
    naechsteSenderLoeschung: Date | null;
    anzahlSender: number;
    meldungen: MeldungDocument[];
    versionen: VersionDocument[];
    befunde: Befund[];
};

const STYLE = `
.kpis.klein{align-items:start}.kpis.klein .kpi b{font-size:20px}
.kpi{position:relative}.kpi details.info{position:absolute;top:10px;right:10px}
details.info summary{list-style:none;cursor:pointer;width:22px;height:22px;border-radius:50%;background:#e8edf5;color:#003056;font:700 13px/22px Georgia,serif;text-align:center}
details.info summary::-webkit-details-marker{display:none}
details.info[open]{position:static}details.info[open] summary{position:absolute;top:10px;right:10px;background:#003056;color:#fff}
details.info p{margin:10px 0 0;font-size:13px;line-height:1.45;color:#3a3a3c}
.inhalte .zeile{display:flex;justify-content:space-between;gap:12px;padding:8px 0;font-size:14px}
.inhalte .zeile+.zeile{border-top:1px solid #f0f0f3}.inhalte .zeile a{white-space:nowrap}`;

const vorher = (stand: Date, zeitpunkt: Date | null): string => {
    if (zeitpunkt == null) {
        return 'nie';
    }
    const minuten = Math.max(0, Math.round((stand.getTime() - zeitpunkt.getTime()) / 60000));
    if (minuten < 60) {
        return `vor ${minuten} Min.`;
    }
    const stunden = Math.round(minuten / 60);
    return stunden < 48 ? `vor ${stunden} Std.` : `vor ${Math.round(stunden / 24)} Tagen`;
};

const tag = (date: Date): string => datum(date).split(',')[0];

// Info ohne Skript: <details> klappt die Erklaerung in der Kachel auf.
const kachel = (wert: string, label: string, unter = '', info = '') =>
    `<div class="kpi"><b>${wert}</b><span>${escapeHtml(label)}</span>${unter ? `<small>${escapeHtml(unter)}</small>` : ''}`
    + `${info ? `<details class="info"><summary aria-label="Erklärung zu ${escapeHtml(label)}">i</summary><p>${escapeHtml(info)}</p></details>` : ''}</div>`;

const INFO = {
    mongodb: 'Wird bei jedem Aufruf dieser Seite angepingt. Ohne Datenbank nimmt der Server keine Snapshots an und liefert kein Bundesaggregat aus.',
    snapshot: 'Eingang des neuesten Stammes-Snapshots (aktuelle Schema-Version, letzte 30 Tage). Apps senden nur mit Einwilligung. Bleibt der Wert lange stehen, hat keine App gesendet oder der Ingest klemmt.',
    backup: 'backup.sh läuft per Cron täglich um 03:15 Uhr Serverzeit, schreibt einen mongodump nach /opt/nami-statistics/backups und löscht dabei Archive, die älter als 14 Tage sind. Älter als ein Tag heißt: Cron oder Backup-Log prüfen.',
    aggregat: 'Der Server prüft stündlich, ob ein Lauf fällig ist. Nachtlauf täglich 03:00 UTC nimmt neue Stämme auf, Wochenlauf montags 03:00 UTC rechnet alle neu. Ändert sich nichts, bleibt der Zeitpunkt stehen. Die App liest nur dieses Aggregat.',
    report: 'Bericht über den Kreis der Teilnehmenden je abgeschlossenem Monat. Der Server prüft alle 6 Stunden, ob der Vormonat fehlt, und rechnet bis zu 12 Monate nach. Danach optional eine Telegram-Nachricht.',
    loeschung: 'MongoDB löscht laufend über TTL-Indizes (Prüfung etwa jede Minute): Rohsnapshots 14 Monate nach Eingang, Installationen 14 Monate nach ihrer letzten erfolgreichen Sendung, ohne Sendung ab Anlage. Auf Anfrage löscht npm run installation sofort. Monatsberichte und Aggregate enthalten nur Zählwerte und bleiben. Backups löscht backup.sh nach 14 Tagen.',
};

const pruefung = (befunde: Befund[]): string => {
    const fehler = befunde.filter((b) => b.stufe === 'fehler').length;
    const warnungen = befunde.length - fehler;
    const zusammenfassung = befunde.length === 0
        ? '<span class="pill p-ok">alles in Ordnung</span>'
        : `${fehler > 0 ? `<span class="pill p-er">${fehler} Fehler</span>` : ''}${warnungen > 0 ? `<span class="pill p-wa">${warnungen} ${warnungen === 1 ? 'Warnung' : 'Warnungen'}</span>` : ''}`;
    const sortiert = [...befunde].sort((a, b) => (a.stufe === b.stufe ? 0 : a.stufe === 'fehler' ? -1 : 1));
    return `<div class="sum">${zusammenfassung}</div>${sortiert.map((b) => `<div class="befund ${b.stufe}">${escapeHtml(b.text)}</div>`).join('')}`;
};

const loeschung = (d: BetriebsDaten): { wert: string; unter: string } => {
    const termine = [d.naechsteSnapshotLoeschung, d.naechsteSenderLoeschung].filter((t): t is Date => t != null);
    const naechste = termine.length === 0 ? null : new Date(Math.min(...termine.map((t) => t.getTime())));
    const unter = [
        `Snapshots ${d.naechsteSnapshotLoeschung ? tag(d.naechsteSnapshotLoeschung) : '–'}`,
        `Installationen ${d.naechsteSenderLoeschung ? tag(d.naechsteSenderLoeschung) : '–'} (${d.anzahlSender} gespeichert)`,
    ].join(' · ');
    return { wert: naechste == null ? 'keine' : tag(naechste), unter };
};

const betrieb = (d: BetriebsDaten): string => {
    const l = loeschung(d);
    return `<div class="kpis klein">
    ${kachel(d.datenbank === 'ok' ? '<span class="pill p-ok">erreichbar</span>' : '<span class="pill p-er">nicht erreichbar</span>', 'MongoDB', '', INFO.mongodb)}
    ${kachel(escapeHtml(vorher(d.stand, d.letzterSnapshot)), 'letzter Snapshot', `${d.snapshotsLetzte7Tage} in den letzten 7 Tagen`, INFO.snapshot)}
    ${kachel(escapeHtml(vorher(d.stand, d.letztesBackup)), 'letztes Backup', '', INFO.backup)}
    ${kachel(escapeHtml(vorher(d.stand, d.letztesAggregat)), 'letztes Bundesaggregat', '', INFO.aggregat)}
    ${kachel(escapeHtml(d.letzterMonatsreport ?? 'keiner'), 'letzter Monatsreport', '', INFO.report)}
    ${kachel(escapeHtml(l.wert), 'nächste Löschung', l.unter, INFO.loeschung)}
</div>`;
};

// Zusammenfassung der Inhalte fuer die App; gepflegt werden sie unter /admin/meldungen und /admin/versionen.
const inhalte = (d: BetriebsDaten): string => {
    const zaehler = { aktiv: 0, geplant: 0, abgelaufen: 0 };
    for (const m of d.meldungen) {
        zaehler[meldungStatus(m, d.stand)] += 1;
    }
    const meldungen = d.meldungen.length === 0
        ? 'keine Meldungen'
        : `${d.meldungen.length} ${d.meldungen.length === 1 ? 'Meldung' : 'Meldungen'} · `
            + (['aktiv', 'geplant', 'abgelaufen'] as const).filter((s) => zaehler[s] > 0).map((s) => `${zaehler[s]} ${s}`).join(', ');
    const versionen = d.versionen.length === 0
        ? 'keine Versionen'
        : [...d.versionen].sort((a, b) => a.plattform.localeCompare(b.plattform)).map((v) =>
            `${PLATTFORM_NAMEN[v.plattform]} ${v.latest}${v.security == null ? '' : ' · Sicherheitsupdate aktiv'}`).join(' · ');
    const zeiten = [...d.meldungen, ...d.versionen].map((x) => x.updated_at.getTime());
    return `<div class="card inhalte">
    <div class="zeile"><span>${escapeHtml(meldungen)}</span><a href="/admin/meldungen">Meldungen →</a></div>
    <div class="zeile"><span>${escapeHtml(versionen)}</span><a href="/admin/versionen">Versionen →</a></div>
    <div class="zeile"><span class="muted">Zuletzt geändert</span><span>${zeiten.length === 0 ? 'nie' : escapeHtml(datum(new Date(Math.max(...zeiten))))}</span></div>
</div>`;
};

export const renderBetriebPage = (d: BetriebsDaten): string => `<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>NaMi-Betrieb</title>
<style>
${ADMIN_STYLE}${STYLE}
</style></head><body><main>
<h1>NaMi-Betrieb</h1>
<p class="muted">Stand ${escapeHtml(datum(d.stand))} · Version ${escapeHtml(d.version)}</p>
${adminNav('betrieb')}
<h2>Prüfung</h2>
${pruefung(d.befunde)}
<h2>Betrieb</h2>
${betrieb(d)}
<h2>Inhalte für die App</h2>
${inhalte(d)}
</main></body></html>`;
