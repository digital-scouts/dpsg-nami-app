import { alsBerlinFeld } from '../../shared/berlinZeit.js';
import {
    APP_ZIELE,
    type MeldungDocument,
    type MeldungTyp,
    type Plattform,
    PLATTFORM_NAMEN,
    PLATTFORMEN,
    type VersionDocument,
} from '../appFeeds/model.js';
import {
    type Befund,
    type MeldungEingabe,
    meldungStatus,
    type VersionEingabe,
    type Wirkung,
    zeitraumText,
} from '../appFeeds/pruefung.js';
import { ADMIN_STYLE, type AdminBereich, adminNav, datum, escapeHtml } from './page.js';

// Pflege von Meldungen und Versionen (design/entscheidung/2026-10-10-admin-pflege.md): Formulare
// ohne Skripte, jede Aenderung ueber eine Vorschau mit Wirkung und Pruefbefunden. Alle Eingaben
// werden escaped, auch die eigenen.

const STYLE = `
.kopfzeile{display:flex;justify-content:space-between;align-items:center;gap:10px;margin:28px 0 10px}.kopfzeile h2{margin:0}
.btn{display:inline-block;border:0;border-radius:10px;padding:9px 15px;font:600 14px system-ui,sans-serif;background:#003056;color:#fff;text-decoration:none;cursor:pointer}
.btn.zweit{background:#e8edf5;color:#003056}.btn.klein{padding:5px 11px;font-size:13px}
.btn.gefahr{background:#fdecee;color:#7a1020}.btn.gefahr.voll{background:#b3261e;color:#fff}
.aktionen{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-top:14px}.aktionen .rechts{margin-left:auto}
.item .akt{margin-top:8px}
form .card,.karten>.card{margin-bottom:12px}.card h3{margin:0 0 12px}
.feld{display:flex;flex-direction:column;gap:4px;margin-bottom:12px;min-width:0}
.feld>label,.feld>.label{font-size:12.5px;font-weight:600;color:#5f5f66}
.hilfe{font-size:12.5px;color:#8e8e93}.fehltext{font-size:12.5px;color:#7a1020}.warntext{font-size:12.5px;color:#795b00}
input[type=text],input[type=url],input[type=datetime-local],textarea,select{font:15px system-ui,sans-serif;border:1px solid #d1d1d6;border-radius:9px;padding:8px 10px;background:#fff;color:#1c1c1e;width:100%;box-sizing:border-box}
textarea{min-height:84px;resize:vertical}
.err input,.err textarea,.err select{border-color:#b3261e;background:#fffafa}
.reihe{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:0 14px}
.sprache{font-size:12px;font-weight:700;color:#003056;letter-spacing:.06em;margin:0 0 8px}
.seg{display:flex;gap:6px;flex-wrap:wrap}.seg label{position:relative}
.seg input{position:absolute;opacity:0;inset:0;margin:0;cursor:pointer}
.seg span{display:inline-block;border:1px solid #d1d1d6;border-radius:999px;padding:5px 13px;font-size:14px;background:#fff}
.seg input:checked+span{background:#003056;border-color:#003056;color:#fff}
.seg input[value=urgent]:checked+span{background:#b3261e;border-color:#b3261e}.seg input[value=warn]:checked+span{background:#b07a00;border-color:#b07a00}
.seg input:focus-visible+span{outline:2px solid #003056;outline-offset:2px}
.check{display:flex;gap:8px;align-items:flex-start;font-size:14px;margin:8px 0}.check input{margin-top:3px}
details.sicher{border:1px dashed #d1d1d6;border-radius:12px;padding:10px 12px;margin-top:4px}
details.sicher.aktiv{border:2px solid #b3261e;background:#fffafa}
details.sicher summary{cursor:pointer;font-weight:600;font-size:14px}details.sicher summary .pill{margin-left:8px}
details.sicher[open] summary{margin-bottom:10px}
.spalten{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:14px;align-items:start}
.wirkung{list-style:none;margin:0;padding:0}
.wirkung li{padding:7px 0 7px 26px;position:relative}
.wirkung li::before{content:'→';position:absolute;left:4px;color:#003056;font-weight:700}
.wirkung li.kritisch{color:#7a1020;font-weight:600}
.wirkung li.kritisch::before{content:'!';color:#fff;background:#b3261e;border-radius:50%;width:18px;height:18px;text-align:center;line-height:18px;font-size:12px;left:0;top:9px}
.appkarten{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:12px}
.appkarte{background:#fff;border-radius:14px;display:flex;overflow:hidden;border:1px solid #e5e5ea}
.appkarte .streifen{width:5px;flex:none}.appkarte .inh{padding:10px 12px;min-width:0}
.appkarte .lbl{font-size:12px;font-weight:700;letter-spacing:.05em;text-transform:uppercase}
.appkarte b{display:block;margin:2px 0}.appkarte p{margin:0;font-size:13.5px;color:#5f5f66;white-space:pre-line;overflow-wrap:anywhere}
.appkarte .knoepfe{margin-top:8px;display:flex;gap:6px}.appkarte .knoepfe span{font-size:12.5px;font-weight:600;background:#e8edf5;color:#003056;border-radius:8px;padding:4px 10px}
.t-urgent .streifen{background:#b3261e}.t-urgent .lbl{color:#b3261e}.t-warn .streifen{background:#b07a00}.t-warn .lbl{color:#795b00}
.t-info .streifen{background:#003056}.t-info .lbl{color:#003056}
.hinweis{background:#e3f3df;color:#24561a;border-radius:12px;padding:9px 12px;margin:14px 0 0;font-size:14px}`;

export type Kopf = { stand: Date; version: string; csrf: string; hinweis?: string | null };

const seite = (titel: string, bereich: AdminBereich, kopf: Kopf, inhalt: string): string => `<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>${escapeHtml(titel)} · NaMi-Admin</title>
<style>
${ADMIN_STYLE}${STYLE}
</style></head><body><main>
<h1>${escapeHtml(titel)}</h1>
<p class="muted">Stand ${escapeHtml(datum(kopf.stand))} · Version ${escapeHtml(kopf.version)}</p>
${adminNav(bereich)}
${kopf.hinweis ? `<div class="hinweis">${escapeHtml(kopf.hinweis)}</div>` : ''}
${inhalt}
</main></body></html>`;

const versteckt = (name: string, wert: string) => `<input type="hidden" name="${name}" value="${escapeHtml(wert)}">`;

const befundeAm = (befunde: Befund[], feld: string) => befunde.filter((b) => b.feld === feld);

const feldHinweise = (befunde: Befund[], feld: string): string =>
    befundeAm(befunde, feld).map((b) => `<div class="${b.stufe === 'fehler' ? 'fehltext' : 'warntext'}">${escapeHtml(b.text)}</div>`).join('');

const feldKlasse = (befunde: Befund[], feld: string) =>
    befundeAm(befunde, feld).some((b) => b.stufe === 'fehler') ? 'feld err' : 'feld';

const textfeld = (
    name: string,
    label: string,
    wert: string,
    befunde: Befund[],
    opts: { hilfe?: string; typ?: 'text' | 'url' | 'datetime-local'; mehrzeilig?: boolean; extra?: string } = {},
): string => {
    const id = `f-${name}`;
    const eingabe = opts.mehrzeilig
        ? `<textarea id="${id}" name="${name}"${opts.extra ?? ''}>${escapeHtml(wert)}</textarea>`
        : `<input id="${id}" type="${opts.typ ?? 'text'}" name="${name}" value="${escapeHtml(wert)}"${opts.extra ?? ''}>`;
    return `<div class="${feldKlasse(befunde, name)}"><label for="${id}">${escapeHtml(label)}</label>${eingabe}`
        + `${feldHinweise(befunde, name)}${opts.hilfe ? `<div class="hilfe">${escapeHtml(opts.hilfe)}</div>` : ''}</div>`;
};

const knopfreihe = (name: string, label: string, wert: string, optionen: Array<[string, string]>, befunde: Befund[], hilfe = ''): string =>
    `<div class="${feldKlasse(befunde, name)}"><span class="label">${escapeHtml(label)}</span><div class="seg" role="radiogroup" aria-label="${escapeHtml(label)}">${optionen
        .map(([v, text]) => `<label><input type="radio" name="${name}" value="${escapeHtml(v)}"${v === wert ? ' checked' : ''}><span>${escapeHtml(text)}</span></label>`)
        .join('')}</div>${feldHinweise(befunde, name)}${hilfe ? `<div class="hilfe">${escapeHtml(hilfe)}</div>` : ''}</div>`;

const befundListe = (befunde: Befund[]): string => {
    if (befunde.length === 0) {
        return '<div class="befund ok">Keine Fehler, keine Warnungen.</div>';
    }
    const sortiert = [...befunde].sort((a, b) => (a.stufe === b.stufe ? 0 : a.stufe === 'fehler' ? -1 : 1));
    return sortiert.map((b) => `<div class="befund ${b.stufe}">${escapeHtml(b.text)}</div>`).join('');
};

// Oben im Formular: Anzahl der Fehler und Befunde ohne eigenes Feld (z. B. ein Konflikt).
const fehlerZusammenfassung = (befunde: Befund[]): string => {
    const fehler = befunde.filter((b) => b.stufe === 'fehler').length;
    const ohneFeld = befunde.filter((b) => b.feld == null);
    return (fehler === 0 ? '' : `<div class="befund fehler" style="margin-top:14px">${fehler} Fehler – bitte korrigieren.</div>`)
        + ohneFeld.map((b) => `<div class="befund ${b.stufe}">${escapeHtml(b.text)}</div>`).join('');
};

const wirkungListe = (wirkung: Wirkung[]): string =>
    `<ul class="wirkung">${wirkung.map((w) => `<li${w.kritisch ? ' class="kritisch"' : ''}>${escapeHtml(w.text)}</li>`).join('')}</ul>`;

// ---- Meldungen ----

const STATUS_PILLE = { aktiv: 'p-ok', geplant: 'p-wa', abgelaufen: '' } as const;
const PLATTFORM_KURZ = { all: 'alle', android: 'Android', ios: 'iOS' } as const;

const meldungKarte = (m: MeldungDocument, now: Date): string => {
    const status = meldungStatus(m, now);
    const link = m.deep_link != null ? `Ziel: ${APP_ZIELE.find((z) => z.pfad === m.deep_link)?.name ?? m.deep_link}` : m.external_link;
    return `<div class="item">
    <span class="pill ${STATUS_PILLE[status]}">${status}</span><b>${escapeHtml(m.title.de || '(ohne Titel)')}</b>
    <div class="z">${m.title.en ? escapeHtml(m.title.en) : '<span class="pill p-wa" style="float:none">EN fehlt</span>'}</div>
    <div class="z">${[m.id, m.type, PLATTFORM_KURZ[m.platform], zeitraumText(m), link ?? ''].filter((x) => x !== '').map(escapeHtml).join(' · ')}</div>
    <div class="akt"><a class="btn klein zweit" href="/admin/meldungen/${encodeURIComponent(m.id)}">Bearbeiten</a></div>
</div>`;
};

export const renderMeldungenListe = (kopf: Kopf, meldungen: MeldungDocument[]): string =>
    seite('Meldungen', 'meldungen', kopf, `<div class="kopfzeile"><h2>${meldungen.length} ${meldungen.length === 1 ? 'Meldung' : 'Meldungen'}</h2>`
        + `<a class="btn klein" href="/admin/meldungen/neu">+ Neue Meldung</a></div>`
        + (meldungen.length === 0
            ? '<p class="muted">Keine Meldungen. Die App zeigt dann nur ihre eigenen Hinweise.</p>'
            : meldungen.map((m) => meldungKarte(m, kopf.stand)).join(''))
        + '<p class="muted">Die App lädt Meldungen höchstens stündlich und merkt sich bestätigte Meldungen über ihre ID. Zeiten in deutscher Zeit.</p>');

export const meldungAlsEingabe = (m: MeldungDocument): MeldungEingabe => ({
    id: m.id,
    type: m.type,
    platform: m.platform,
    title_de: m.title.de,
    title_en: m.title.en,
    body_de: m.body.de,
    body_en: m.body.en,
    starts_at: m.starts_at == null ? '' : alsBerlinFeld(m.starts_at),
    ends_at: m.ends_at == null ? '' : alsBerlinFeld(m.ends_at),
    deep_link: m.deep_link ?? '',
    external_link: m.external_link ?? '',
});

export const LEERE_MELDUNG: MeldungEingabe = {
    id: '', type: 'info', platform: 'all', title_de: '', title_en: '', body_de: '', body_en: '', starts_at: '', ends_at: '', deep_link: '', external_link: '',
};

const MELDUNG_FELDER: Array<keyof MeldungEingabe> = Object.keys(LEERE_MELDUNG) as Array<keyof MeldungEingabe>;

// Pfad der Meldung: neue unter /admin/meldungen/neu, bestehende unter ihrer ID.
const meldungPfad = (bestehend: string | null) => `/admin/meldungen/${bestehend == null ? 'neu' : encodeURIComponent(bestehend)}`;

export type MeldungFormular = {
    bestehend: string | null;
    eingabe: MeldungEingabe;
    stand: string;
    befunde: Befund[];
};

export const renderMeldungFormular = (kopf: Kopf, f: MeldungFormular): string => {
    const e = f.eingabe;
    const b = f.befunde;
    const idFeld = f.bestehend == null
        ? textfeld('id', 'ID', e.id, b, { hilfe: 'Leer lassen: wird aus dem deutschen Titel gebildet. Nach dem Speichern fest.', extra: ' pattern="[a-z0-9-]*" maxlength="64"' })
        : `<div class="feld"><span class="label">ID</span><div>${escapeHtml(f.bestehend)}</div><div class="hilfe">Fest, die App merkt sich Bestätigungen über die ID.</div></div>`;
    const ziele: Array<[string, string]> = [['', 'keins'], ...APP_ZIELE.map((z): [string, string] => [z.pfad, z.name])];
    const zielWert = ziele.some(([v]) => v === e.deep_link) ? e.deep_link : '';
    return seite(f.bestehend == null ? 'Neue Meldung' : 'Meldung bearbeiten', 'meldungen', kopf, `${fehlerZusammenfassung(b)}
<form method="post" action="${meldungPfad(f.bestehend)}/vorschau" style="margin-top:14px">
${versteckt('csrf', kopf.csrf)}${versteckt('stand', f.stand)}
<div class="card"><h3>Einstellungen</h3>
${idFeld}
<div class="reihe">
${knopfreihe('type', 'Typ', e.type, [['info', 'info'], ['warn', 'warn'], ['urgent', 'urgent']], b, 'urgent erscheint als Banner oben in der App, info und warn nur in der Meldungsliste.')}
${knopfreihe('platform', 'Plattform', e.platform, [['all', 'alle'], ['android', 'Android'], ['ios', 'iOS']], b)}
</div></div>
<div class="card"><h3>Text</h3><div class="reihe">
<div><div class="sprache">DEUTSCH</div>${textfeld('title_de', 'Titel', e.title_de, b, { extra: ' maxlength="120"' })}${textfeld('body_de', 'Text', e.body_de, b, { mehrzeilig: true })}</div>
<div><div class="sprache">ENGLISCH</div>${textfeld('title_en', 'Titel', e.title_en, b, { extra: ' maxlength="120"' })}${textfeld('body_en', 'Text', e.body_en, b, { mehrzeilig: true })}</div>
</div></div>
<div class="card"><h3>Zeitraum</h3><div class="reihe">
${textfeld('starts_at', 'Ab', e.starts_at, b, { typ: 'datetime-local', hilfe: 'Leer = sofort' })}
${textfeld('ends_at', 'Bis', e.ends_at, b, { typ: 'datetime-local', hilfe: 'Leer = unbegrenzt' })}
</div><div class="hilfe">Deutsche Zeit.</div></div>
<div class="card"><h3>Link</h3><div class="reihe">
<div class="${feldKlasse(b, 'deep_link')}"><label for="f-deep_link">Ziel in der App</label><select id="f-deep_link" name="deep_link">${ziele
        .map(([v, name]) => `<option value="${escapeHtml(v)}"${v === zielWert ? ' selected' : ''}>${escapeHtml(name)}</option>`).join('')}</select>${feldHinweise(b, 'deep_link')}</div>
${textfeld('external_link', 'oder externer Link', e.external_link, b, { typ: 'url', hilfe: 'Nur https, öffnet im In-App-Browser.', extra: ' placeholder="https://…"' })}
</div></div>
<div class="aktionen"><button class="btn" type="submit">Weiter zur Vorschau</button><a class="btn zweit" href="/admin/meldungen">Abbrechen</a>${f.bestehend == null
        ? '' : `<a class="btn gefahr rechts" href="${meldungPfad(f.bestehend)}/loeschen">Löschen</a>`}</div>
</form>`);
};

const LABEL: Record<MeldungTyp, [string, string]> = { urgent: ['Dringend', 'Urgent'], warn: ['Hinweis', 'Notice'], info: ['Information', 'Information'] };

const appKarte = (m: MeldungDocument, sprache: 'de' | 'en'): string => {
    const titel = m.title[sprache] || m.title.de;
    const text = m.body[sprache] || m.body.de;
    const hatLink = m.deep_link != null || m.external_link != null;
    return `<div class="appkarte t-${m.type}"><div class="streifen"></div><div class="inh">
<div class="lbl">${escapeHtml(LABEL[m.type][sprache === 'de' ? 0 : 1])}</div><b>${escapeHtml(titel)}</b>${text ? `<p>${escapeHtml(text)}</p>` : ''}
<div class="knoepfe">${hatLink ? `<span>${sprache === 'de' ? 'Mehr erfahren' : 'Learn more'}</span>` : ''}<span>${sprache === 'de' ? 'Bestätigen' : 'Acknowledge'}</span></div>
</div></div>`;
};

export type MeldungVorschau = {
    bestehend: string | null;
    eingabe: MeldungEingabe;
    stand: string;
    meldung: MeldungDocument;
    befunde: Befund[];
    wirkung: Wirkung[];
};

export const renderMeldungVorschau = (kopf: Kopf, v: MeldungVorschau): string =>
    seite('Vorschau', 'meldungen', kopf, `<h2>Wirkung</h2><div class="card">${wirkungListe(v.wirkung)}</div>
<h2>So erscheint sie in der App</h2><div class="appkarten">${appKarte(v.meldung, 'de')}${appKarte(v.meldung, 'en')}</div>
<p class="muted">ID ${escapeHtml(v.meldung.id)} · ${escapeHtml(PLATTFORM_KURZ[v.meldung.platform])} · ${escapeHtml(zeitraumText(v.meldung))}</p>
<h2>Prüfung</h2>${befundListe(v.befunde)}
<form method="post" action="${meldungPfad(v.bestehend)}">
${versteckt('csrf', kopf.csrf)}${versteckt('stand', v.stand)}${MELDUNG_FELDER.map((feld) => versteckt(feld, feld === 'id' ? v.meldung.id : v.eingabe[feld])).join('')}
<div class="aktionen"><button class="btn" type="submit" name="aktion" value="speichern">Speichern</button><button class="btn zweit" type="submit" name="aktion" value="zurueck">Zurück zum Formular</button></div>
</form>
<p class="muted">Nach dem Speichern geht eine Telegram-Nachricht an den Betreiber, sofern Telegram eingerichtet ist.</p>`);

export const renderMeldungLoeschen = (kopf: Kopf, m: MeldungDocument, wirkung: Wirkung[]): string =>
    seite('Meldung löschen', 'meldungen', kopf, `<div class="card" style="margin-top:14px"><b>${escapeHtml(m.title.de || m.id)}</b>
<div class="muted">${[m.id, m.type, PLATTFORM_KURZ[m.platform], zeitraumText(m)].map(escapeHtml).join(' · ')}</div></div>
<div class="card" style="margin-top:12px">${wirkungListe([...wirkung, {
        text: `Die ID „${m.id}“ wird frei. Eine neue Meldung mit derselben ID gilt für Apps, die diese bestätigt haben, als schon gelesen.`,
    }])}</div>
<form method="post" action="${meldungPfad(m.id)}/loeschen">${versteckt('csrf', kopf.csrf)}${versteckt('stand', m.updated_at.toISOString())}
<div class="aktionen"><button class="btn gefahr voll" type="submit">Endgültig löschen</button><a class="btn zweit" href="${meldungPfad(m.id)}">Abbrechen</a></div>
</form>`);

// ---- Versionen ----

export const versionAlsEingabe = (v: VersionDocument | null): VersionEingabe => ({
    latest: v?.latest ?? '',
    min_supported: v?.min_supported ?? '',
    store_url: v?.store_url ?? '',
    security_aktiv: v?.security == null ? '' : 'ja',
    security_min_version: v?.security?.min_version ?? '',
    security_betrifft: v?.security?.betrifft ?? '',
    security_betrifft_en: v?.security?.betrifft_en ?? '',
    security_daten_loeschen: v?.security?.daten_loeschen ? 'ja' : '',
});

const VERSION_FELDER = Object.keys(versionAlsEingabe(null)) as Array<keyof VersionEingabe>;

export type VersionFormular = { eingabe: VersionEingabe; stand: string; befunde: Befund[] };

const checkbox = (name: string, wert: string, text: string) =>
    `<label class="check"><input type="checkbox" name="${name}" value="ja"${wert === 'ja' ? ' checked' : ''}><span>${escapeHtml(text)}</span></label>`;

const versionKarte = (kopf: Kopf, plattform: Plattform, f: VersionFormular): string => {
    const e = f.eingabe;
    const b = f.befunde;
    const aktiv = e.security_aktiv === 'ja';
    const sicherFehler = b.some((x) => x.feld?.startsWith('security_') && x.stufe === 'fehler');
    return `<form class="card" method="post" action="/admin/versionen/${plattform}/vorschau">
${versteckt('csrf', kopf.csrf)}${versteckt('stand', f.stand)}
<h3>${PLATTFORM_NAMEN[plattform]}</h3>
${f.stand === '' ? '<div class="befund warnung">Noch nicht angelegt, die App prüft hier keine Updates.</div>' : ''}
${textfeld('latest', 'latest', e.latest, b, { hilfe: 'Neueste Version im Store. Darunter zeigt die App „Update verfügbar“.', extra: ' inputmode="decimal" placeholder="1.0.0"' })}
${textfeld('min_supported', 'min_supported', e.min_supported, b, { hilfe: 'Darunter einmal je Start der Dialog „Update erforderlich“ und eine dauerhafte dringende Meldung mit Store-Link. Keine Sperre.', extra: ' inputmode="decimal" placeholder="1.0.0"' })}
${textfeld('store_url', 'Store-Adresse', e.store_url, b, { typ: 'url' })}
<details class="sicher${aktiv ? ' aktiv' : ''}"${aktiv || sicherFehler ? ' open' : ''}><summary>Sicherheitsupdate${aktiv ? '<span class="pill p-er">aktiv</span>' : '<span class="pill">aus</span>'}</summary>
<p class="hilfe" style="margin-top:0">Apps unter der ersten behobenen Version fragen zweimal nach, zeigen dann einen Countdown und sperren sich danach bis zum Update. Nur nutzen, wenn die Version im Store ist.</p>
${checkbox('security_aktiv', e.security_aktiv, 'aktiv – sperrt ältere Versionen nach Countdown')}
${textfeld('security_min_version', 'Erste behobene Version', e.security_min_version, b, { extra: ' inputmode="decimal" placeholder="1.0.1"' })}
${textfeld('security_betrifft', 'Betrifft (DE)', e.security_betrifft, b, { hilfe: 'z. B. „Anmeldung bei Hitobito“' })}
${textfeld('security_betrifft_en', 'Betrifft (EN)', e.security_betrifft_en, b)}
${checkbox('security_daten_loeschen', e.security_daten_loeschen, 'Daten beim Sperren löschen (nur bei Datenleck)')}
<div class="hilfe">Dann meldet die App beim Sperren ab und löscht die Mitgliederdaten, ohne Notfallzugang.</div>
</details>
<div class="aktionen"><button class="btn" type="submit">Weiter zur Vorschau</button></div>
</form>`;
};

export const renderVersionen = (kopf: Kopf, formulare: Record<Plattform, VersionFormular>): string =>
    seite('Versionen', 'versionen', kopf, `${PLATTFORMEN.map((p) => fehlerZusammenfassung(formulare[p].befunde)).join('')}
<div class="spalten" style="margin-top:14px">${PLATTFORMEN.map((p) => versionKarte(kopf, p, formulare[p])).join('')}</div>
<p class="muted">Die App fragt höchstens alle 12 Stunden; „Erneut prüfen“ auf der Sperre fragt sofort.</p>`);

export type VersionVorschau = {
    plattform: Plattform;
    eingabe: VersionEingabe;
    stand: string;
    befunde: Befund[];
    wirkung: Wirkung[];
};

export const renderVersionVorschau = (kopf: Kopf, v: VersionVorschau): string =>
    seite('Vorschau', 'versionen', kopf, `<h2>Wirkung – ${PLATTFORM_NAMEN[v.plattform]}</h2><div class="card">${wirkungListe(v.wirkung)}</div>
<h2>Prüfung</h2>${befundListe(v.befunde)}
<form method="post" action="/admin/versionen/${v.plattform}">
${versteckt('csrf', kopf.csrf)}${versteckt('stand', v.stand)}${VERSION_FELDER.map((feld) => versteckt(feld, v.eingabe[feld])).join('')}
<div class="aktionen"><button class="btn" type="submit" name="aktion" value="speichern">Speichern</button><button class="btn zweit" type="submit" name="aktion" value="zurueck">Zurück zum Formular</button></div>
</form>
<p class="muted">Nach dem Speichern geht eine Telegram-Nachricht an den Betreiber, sofern Telegram eingerichtet ist.</p>`);

export const KONFLIKT: Befund = { stufe: 'fehler', text: 'Inzwischen von anderer Stelle geändert. Bitte die Seite neu laden und die Änderung wiederholen.' };
