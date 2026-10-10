import type { Befund, MeldungZeile, PlattformVersion } from './feeds.js';
import { ADMIN_STYLE, adminNav, datum, escapeHtml } from './page.js';

// Betriebsuebersicht unter /admin/betrieb (design/entscheidung/2026-10-10-admin-betrieb.md):
// Pruefung zuerst, dann Betrieb, Pull-Notifications als Karten, Versionen mit Store-Check.
// Feed-Inhalte kommen aus GitHub Pages und werden immer escaped.

export type FeedErgebnis<T> = { ok: true; daten: T } | { ok: false; fehler: string };

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
    feedAbgerufen: Date;
    meldungen: FeedErgebnis<MeldungZeile[]>;
    versionen: FeedErgebnis<PlattformVersion[]>;
    befunde: Befund[];
    notificationsUrl: string;
    versionUrl: string;
};

const STYLE = `
.pill{display:inline-block;font-size:12px;font-weight:700;padding:2px 9px;border-radius:999px;background:#e5e5ea;color:#3a3a3c}
.p-ok{background:#e3f3df;color:#24561a}.p-wa{background:#fff3cd;color:#795b00}.p-er{background:#fdecee;color:#7a1020}
.sum{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 10px}
.befund{border-radius:12px;padding:9px 12px;margin-bottom:6px;font-size:14px}
.befund.fehler{background:#fdecee;color:#7a1020}.befund.warnung{background:#fff3cd;color:#795b00}
.kpis.klein{align-items:start}.kpis.klein .kpi b{font-size:20px}
.kpi{position:relative}.kpi details.info{position:absolute;top:10px;right:10px}
details.info summary{list-style:none;cursor:pointer;width:22px;height:22px;border-radius:50%;background:#e8edf5;color:#003056;font:700 13px/22px Georgia,serif;text-align:center}
details.info summary::-webkit-details-marker{display:none}
details.info[open]{position:static}details.info[open] summary{position:absolute;top:10px;right:10px;background:#003056;color:#fff}
details.info p{margin:10px 0 0;font-size:13px;line-height:1.45;color:#3a3a3c}
.item{background:#fff;border-radius:14px;padding:10px 14px;margin-bottom:8px;font-size:13.5px}
.item b{font-size:15px}.item .pill{float:right}.item .z{color:#8e8e93;margin-top:3px;overflow-wrap:anywhere}
.spalten{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:12px}
.card{background:#fff;border-radius:14px;padding:12px 14px}
dl{display:grid;grid-template-columns:auto 1fr;gap:4px 14px;margin:8px 0 0;font-size:13.5px}dt{color:#8e8e93}dd{margin:0;overflow-wrap:anywhere}
a{color:#003056}`;

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
    feeds: 'notifications.json und version.json kommen von GitHub Pages. Der Server holt sie höchstens alle 5 Minuten und hält sie nur im Speicher.',
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
    ${kachel(escapeHtml(vorher(d.stand, d.feedAbgerufen)), 'Feeds abgerufen', '', INFO.feeds)}
</div>`;
};

const zeitraum = (z: MeldungZeile): string => {
    if (z.startsAt != null && z.endsAt != null) {
        return `${tag(z.startsAt)}–${tag(z.endsAt)}`;
    }
    if (z.startsAt != null) {
        return `ab ${tag(z.startsAt)}`;
    }
    return z.endsAt != null ? `bis ${tag(z.endsAt)}` : 'unbefristet';
};

const STATUS_PILLE: Record<MeldungZeile['status'], string> = { aktiv: 'p-wa', geplant: '', abgelaufen: '' };

const meldungKarte = (z: MeldungZeile): string => `<div class="item">
    <span class="pill ${STATUS_PILLE[z.status]}">${z.status}</span><b>${escapeHtml(z.titelDe || '(ohne Titel)')}</b>
    <div class="z">${z.titelEn ? escapeHtml(z.titelEn) : '<span class="pill p-wa" style="float:none">EN fehlt</span>'}</div>
    <div class="z">${[z.id || '(ohne id)', z.type, z.platform, zeitraum(z)].map(escapeHtml).join(' · ')}${z.link ? ` · ${escapeHtml(z.link)}` : ''}</div>
</div>`;

const meldungen = (d: BetriebsDaten): string => {
    const quelle = `<p class="muted">Quelle: ${escapeHtml(d.notificationsUrl)}</p>`;
    if (!d.meldungen.ok) {
        return `${quelle}<div class="befund fehler">Nicht abrufbar: ${escapeHtml(d.meldungen.fehler)}</div>`;
    }
    return d.meldungen.daten.length === 0
        ? `${quelle}<p class="muted">Keine Meldungen im Feed.</p>`
        : `${quelle}${d.meldungen.daten.map(meldungKarte).join('')}`;
};

const versionen = (d: BetriebsDaten): string => {
    const quelle = `<p class="muted">Quelle: ${escapeHtml(d.versionUrl)}</p>`;
    if (!d.versionen.ok) {
        return `${quelle}<div class="befund fehler">Nicht abrufbar: ${escapeHtml(d.versionen.fehler)}</div>`;
    }
    const karte = (p: PlattformVersion) => `<div class="card">
        <b>${p.plattform === 'android' ? 'Android' : 'iOS'}</b> <span class="pill ${p.ok ? 'p-ok' : 'p-er'}">${p.ok ? 'ok' : 'prüfen'}</span>
        <dl><dt>latest</dt><dd>${escapeHtml(p.latest ?? '–')}</dd><dt>min_supported</dt><dd>${escapeHtml(p.minSupported ?? '–')}</dd>
        <dt>Store</dt><dd>${p.storeUrl ? escapeHtml(p.storeUrl) : '–'}</dd></dl>
    </div>`;
    return `${quelle}<div class="spalten">${d.versionen.daten.map(karte).join('')}</div>`;
};

export const renderBetriebPage = (d: BetriebsDaten): string => `<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>NaMi-Betrieb</title>
<style>
${ADMIN_STYLE}${STYLE}
</style></head><body><main>
<h1>NaMi-Betrieb</h1>
<p class="muted">Stand ${escapeHtml(datum(d.stand))} · Version ${escapeHtml(d.version)} · nur Lesezugriff</p>
${adminNav('betrieb')}
<h2>Prüfung</h2>
${pruefung(d.befunde)}
<h2>Betrieb</h2>
${betrieb(d)}
<h2>Pull-Notifications${d.meldungen.ok ? ` · ${d.meldungen.daten.length}` : ''}</h2>
${meldungen(d)}
<h2>Versionen und Store-Check</h2>
${versionen(d)}
</main></body></html>`;
