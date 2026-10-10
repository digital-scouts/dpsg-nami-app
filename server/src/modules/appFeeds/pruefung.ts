// Pruefregeln und Klartext der Wirkung fuer Meldungen und Versionen (spec/app_feeds.md).
// Fehler verhindern das Speichern, Warnungen nicht.

import { alsBerlinText, ausBerlinFeld } from '../../shared/berlinZeit.js';
import {
    APP_ZIELE,
    MELDUNG_PLATTFORMEN,
    MELDUNG_TYPEN,
    type MeldungDocument,
    type MeldungPlattform,
    type MeldungTyp,
    type Plattform,
    PLATTFORM_NAMEN,
    PLATTFORMEN,
    type VersionDocument,
} from './model.js';

export type Befund = { stufe: 'fehler' | 'warnung'; text: string; feld?: string };
export type Wirkung = { text: string; kritisch?: boolean };
export type MeldungStatus = 'aktiv' | 'geplant' | 'abgelaufen';

const SEMVER = /^(\d+)\.(\d+)\.(\d+)$/;
const ID_MUSTER = /^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$/;
const TITEL_MAX = 120;
const TEXT_MAX = 1000;
const STORE_HOSTS: Record<Plattform, string> = { android: 'play.google.com', ios: 'apps.apple.com' };

export const vergleicheVersion = (a: string, b: string): number => {
    const x = SEMVER.exec(a)!.slice(1).map(Number);
    const y = SEMVER.exec(b)!.slice(1).map(Number);
    return x[0] - y[0] || x[1] - y[1] || x[2] - y[2];
};

const istHttps = (value: string): boolean => {
    try {
        const url = new URL(value);
        return url.protocol === 'https:' && url.hostname !== '';
    } catch {
        return false;
    }
};

export const meldungStatus = (m: Pick<MeldungDocument, 'starts_at' | 'ends_at'>, now: Date): MeldungStatus =>
    m.ends_at != null && m.ends_at <= now ? 'abgelaufen' : m.starts_at != null && m.starts_at > now ? 'geplant' : 'aktiv';

// Vorschlag fuer die ID einer neuen Meldung aus dem deutschen Titel.
export const idAusTitel = (titel: string): string =>
    titel
        .toLowerCase()
        .replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue').replace(/ß/g, 'ss')
        .normalize('NFKD').replace(/[̀-ͯ]/g, '')
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+/, '')
        .slice(0, 48)
        .replace(/-+$/, '');

// Formularfelder einer Meldung, so wie der Browser sie schickt.
export type MeldungEingabe = {
    id: string;
    type: string;
    platform: string;
    title_de: string;
    title_en: string;
    body_de: string;
    body_en: string;
    starts_at: string;
    ends_at: string;
    deep_link: string;
    external_link: string;
};

// Regeln, die fuer gespeicherte Meldungen gelten; auch fuer die Pruefung auf /admin/betrieb.
export const pruefeMeldung = (m: MeldungDocument, now: Date): Befund[] => {
    const befunde: Befund[] = [];
    for (const [feld, wert, name] of [['title_de', m.title.de, 'Titel Deutsch'], ['title_en', m.title.en, 'Titel Englisch']] as const) {
        if (wert === '') {
            befunde.push({ stufe: 'fehler', feld, text: `${name} fehlt.` });
        } else if (wert.length > TITEL_MAX) {
            befunde.push({ stufe: 'fehler', feld, text: `${name} ist länger als ${TITEL_MAX} Zeichen.` });
        }
    }
    for (const [feld, wert, name] of [['body_de', m.body.de, 'Text Deutsch'], ['body_en', m.body.en, 'Text Englisch']] as const) {
        if (wert.length > TEXT_MAX) {
            befunde.push({ stufe: 'fehler', feld, text: `${name} ist länger als ${TEXT_MAX} Zeichen.` });
        }
    }
    if ((m.body.de === '') !== (m.body.en === '')) {
        befunde.push({ stufe: 'warnung', feld: m.body.de === '' ? 'body_de' : 'body_en', text: 'Text nur in einer Sprache.' });
    }
    if (m.starts_at != null && m.ends_at != null && m.ends_at <= m.starts_at) {
        befunde.push({ stufe: 'fehler', feld: 'ends_at', text: '„Bis“ liegt nicht nach „Ab“.' });
    } else if (meldungStatus(m, now) === 'abgelaufen') {
        befunde.push({ stufe: 'warnung', feld: 'ends_at', text: 'Abgelaufen, die App zeigt sie nicht mehr. Kann gelöscht werden.' });
    }
    if (m.external_link != null && !istHttps(m.external_link)) {
        befunde.push({ stufe: 'fehler', feld: 'external_link', text: 'Externer Link muss mit https:// beginnen.' });
    }
    if (m.deep_link != null && !APP_ZIELE.some((ziel) => ziel.pfad === m.deep_link)) {
        befunde.push({ stufe: 'fehler', feld: 'deep_link', text: 'Unbekanntes Ziel in der App.' });
    }
    if (m.deep_link != null && m.external_link != null) {
        befunde.push({ stufe: 'warnung', feld: 'external_link', text: 'Mit Ziel in der App öffnet die App den externen Link nicht.' });
    }
    return befunde;
};

// Liest das Formular. Neue Meldungen ohne ID bekommen eine aus dem Titel, bei Kollision mit Zahl.
export const leseMeldung = (
    eingabe: MeldungEingabe,
    bisher: MeldungDocument | null,
    vergebeneIds: ReadonlySet<string>,
    now: Date,
): { meldung: MeldungDocument; befunde: Befund[] } => {
    const befunde: Befund[] = [];
    let id = bisher?.id ?? eingabe.id.trim();
    if (bisher == null) {
        if (id === '') {
            const basis = idAusTitel(eingabe.title_de) || 'meldung';
            id = basis;
            for (let n = 2; vergebeneIds.has(id); n += 1) {
                id = `${basis}-${n}`;
            }
        } else if (!ID_MUSTER.test(id)) {
            befunde.push({ stufe: 'fehler', feld: 'id', text: 'ID: nur Kleinbuchstaben, Ziffern und Bindestriche, höchstens 64 Zeichen.' });
        } else if (vergebeneIds.has(id)) {
            befunde.push({ stufe: 'fehler', feld: 'id', text: `ID „${id}“ ist schon vergeben.` });
        }
    }

    const type = MELDUNG_TYPEN.find((t) => t === eingabe.type);
    if (type == null) {
        befunde.push({ stufe: 'fehler', feld: 'type', text: 'Typ fehlt.' });
    }
    const platform = MELDUNG_PLATTFORMEN.find((p) => p === eingabe.platform);
    if (platform == null) {
        befunde.push({ stufe: 'fehler', feld: 'platform', text: 'Plattform fehlt.' });
    }
    const zeit = (feld: 'starts_at' | 'ends_at', name: string): Date | null => {
        const wert = ausBerlinFeld(eingabe[feld]);
        if (wert === 'ungueltig') {
            befunde.push({ stufe: 'fehler', feld, text: `„${name}“ ist kein gültiger Zeitpunkt.` });
            return null;
        }
        return wert;
    };
    const leer = (wert: string) => (wert.trim() === '' ? null : wert.trim());

    const meldung: MeldungDocument = {
        id,
        type: type ?? ('info' as MeldungTyp),
        platform: platform ?? ('all' as MeldungPlattform),
        title: { de: eingabe.title_de.trim(), en: eingabe.title_en.trim() },
        body: { de: eingabe.body_de.trim(), en: eingabe.body_en.trim() },
        starts_at: zeit('starts_at', 'Ab'),
        ends_at: zeit('ends_at', 'Bis'),
        external_link: leer(eingabe.external_link),
        deep_link: leer(eingabe.deep_link),
        created_at: bisher?.created_at ?? now,
        updated_at: now,
    };
    return { meldung, befunde: [...befunde, ...pruefeMeldung(meldung, now)] };
};

// Formularfelder einer Plattform.
export type VersionEingabe = {
    latest: string;
    min_supported: string;
    store_url: string;
    security_aktiv: string;
    security_min_version: string;
    security_betrifft: string;
    security_betrifft_en: string;
    security_daten_loeschen: string;
};

export const pruefeVersion = (v: VersionDocument): Befund[] => {
    const befunde: Befund[] = [];
    const name = PLATTFORM_NAMEN[v.plattform];
    for (const [feld, wert] of [['latest', v.latest], ['min_supported', v.min_supported]] as const) {
        if (!SEMVER.test(wert)) {
            befunde.push({ stufe: 'fehler', feld, text: `${name}: ${feld} „${wert}“ ist keine Version x.y.z.` });
        }
    }
    if (SEMVER.test(v.latest) && SEMVER.test(v.min_supported) && vergleicheVersion(v.latest, v.min_supported) < 0) {
        befunde.push({ stufe: 'fehler', feld: 'min_supported', text: `${name}: min_supported liegt über latest, niemand kann die Version laden.` });
    }
    let storeOk = false;
    try {
        const url = new URL(v.store_url);
        storeOk = url.protocol === 'https:' && url.hostname === STORE_HOSTS[v.plattform];
    } catch {
        storeOk = false;
    }
    if (!storeOk) {
        befunde.push({ stufe: 'fehler', feld: 'store_url', text: `${name}: Store-Adresse muss ein https-Link auf ${STORE_HOSTS[v.plattform]} sein.` });
    }
    const s = v.security;
    if (s != null) {
        if (!SEMVER.test(s.min_version)) {
            befunde.push({ stufe: 'fehler', feld: 'security_min_version', text: `${name}: erste behobene Version „${s.min_version}“ ist keine Version x.y.z.` });
        } else if (SEMVER.test(v.latest) && vergleicheVersion(s.min_version, v.latest) > 0) {
            befunde.push({ stufe: 'warnung', feld: 'latest', text: `${name}: latest liegt unter der ersten behobenen Version, der Hinweis „Update verfügbar“ fehlt.` });
        }
        if (s.betrifft === '') {
            befunde.push({ stufe: 'fehler', feld: 'security_betrifft', text: `${name}: „Betrifft“ auf Deutsch fehlt.` });
        }
        if (s.betrifft_en === '') {
            befunde.push({ stufe: 'warnung', feld: 'security_betrifft_en', text: `${name}: „Betrifft“ auf Englisch fehlt, die App zeigt den deutschen Text.` });
        }
    }
    return befunde;
};

export const leseVersion = (
    plattform: Plattform,
    eingabe: VersionEingabe,
    bisher: VersionDocument | null,
    now: Date,
): { version: VersionDocument; befunde: Befund[] } => {
    const version: VersionDocument = {
        plattform,
        latest: eingabe.latest.trim(),
        min_supported: eingabe.min_supported.trim(),
        store_url: eingabe.store_url.trim(),
        security: eingabe.security_aktiv === 'ja'
            ? {
                min_version: eingabe.security_min_version.trim(),
                betrifft: eingabe.security_betrifft.trim(),
                betrifft_en: eingabe.security_betrifft_en.trim(),
                daten_loeschen: eingabe.security_daten_loeschen === 'ja',
            }
            : null,
        updated_at: now,
    };
    const befunde = pruefeVersion(version);
    const neuAktiv = version.security != null
        && (bisher?.security == null || bisher.security.min_version !== version.security.min_version);
    if (neuAktiv && SEMVER.test(version.security!.min_version)) {
        befunde.push({
            stufe: 'warnung',
            feld: 'security_min_version',
            text: `${PLATTFORM_NAMEN[plattform]}: Ist ${version.security!.min_version} schon im Store? Sonst kann niemand die Sperre durch ein Update lösen.`,
        });
    }
    return { version, befunde };
};

// Pruefung des gesamten Bestands fuer /admin/betrieb.
export const pruefeBestand = (meldungen: MeldungDocument[], versionen: VersionDocument[], now: Date): Befund[] => [
    ...meldungen.flatMap((m) => pruefeMeldung(m, now).map((b) => ({ ...b, text: `Meldung „${m.id}“: ${b.text}` }))),
    ...PLATTFORMEN.flatMap((plattform): Befund[] => {
        const version = versionen.find((v) => v.plattform === plattform);
        return version == null
            ? [{ stufe: 'fehler', text: `Versionen ${PLATTFORM_NAMEN[plattform]} fehlen, die App prüft dort keine Updates.` }]
            : pruefeVersion(version);
    }),
];

const PLATTFORM_TEXT: Record<MeldungPlattform, string> = { all: 'Android und iOS', android: 'Android', ios: 'iOS' };
const PLATTFORM_KURZ: Record<MeldungPlattform, string> = { all: 'alle', android: 'Android', ios: 'iOS' };

export const zeitraumText = (m: Pick<MeldungDocument, 'starts_at' | 'ends_at'>): string => {
    const ab = m.starts_at == null ? 'ab sofort' : `ab ${alsBerlinText(m.starts_at)}`;
    const bis = m.ends_at == null ? 'unbegrenzt' : `bis ${alsBerlinText(m.ends_at)}`;
    return `${ab}, ${bis}`;
};

const ORT: Record<MeldungTyp, string> = {
    urgent: 'erscheint als Banner oben in der App',
    warn: 'erscheint als Warnung in der Meldungsliste',
    info: 'erscheint als Info in der Meldungsliste',
};

const linkText = (m: MeldungDocument): string =>
    m.deep_link != null
        ? `Ziel in der App: ${APP_ZIELE.find((ziel) => ziel.pfad === m.deep_link)?.name ?? m.deep_link}`
        : m.external_link ?? 'kein Link';

// Kurzzeile fuer Telegram und Listen, z. B. „Wartung“ (urgent, alle, ab sofort, unbegrenzt).
export const meldungKurz = (m: MeldungDocument): string =>
    `„${m.title.de || m.id}“ (${m.type}, ${PLATTFORM_KURZ[m.platform]}, ${zeitraumText(m)})`;

export const beschreibeMeldung = (alt: MeldungDocument | null, neu: MeldungDocument | null): Wirkung[] => {
    if (neu == null) {
        return alt == null ? [] : [{ text: `Meldung ${meldungKurz(alt)} gelöscht: Sie verschwindet beim nächsten Abruf aus allen Apps.` }];
    }
    const kopf: Wirkung = { text: `${neu.type}-Meldung ${ORT[neu.type]} auf ${PLATTFORM_TEXT[neu.platform]}.`, kritisch: neu.type === 'urgent' };
    if (alt == null) {
        return [
            { ...kopf, text: `Neue ${kopf.text}` },
            { text: `Sichtbar ${zeitraumText(neu)} (deutsche Zeit).` },
            { text: `Link: ${linkText(neu)}.` },
            { text: 'Apps laden sie beim nächsten Abruf.' },
        ];
    }
    const aenderungen: Wirkung[] = [];
    const vergleich = (name: string, a: string, b: string) => {
        if (a !== b) {
            aenderungen.push({ text: `${name}: ${a || '–'} → ${b || '–'}` });
        }
    };
    vergleich('Typ', alt.type, neu.type);
    vergleich('Plattform', PLATTFORM_KURZ[alt.platform], PLATTFORM_KURZ[neu.platform]);
    vergleich('Titel Deutsch', alt.title.de, neu.title.de);
    vergleich('Titel Englisch', alt.title.en, neu.title.en);
    if (alt.body.de !== neu.body.de) {
        aenderungen.push({ text: 'Text Deutsch geändert' });
    }
    if (alt.body.en !== neu.body.en) {
        aenderungen.push({ text: 'Text Englisch geändert' });
    }
    vergleich('Zeitraum', zeitraumText(alt), zeitraumText(neu));
    vergleich('Link', linkText(alt), linkText(neu));
    if (aenderungen.length === 0) {
        return [{ text: 'Keine Änderung.' }];
    }
    return [
        kopf,
        ...aenderungen,
        { text: 'Wer die Meldung schon bestätigt hat, sieht die Änderung nicht. Für alle neu: als neue Meldung anlegen.' },
    ];
};

export const beschreibeVersion = (alt: VersionDocument | null, neu: VersionDocument): Wirkung[] => {
    const name = PLATTFORM_NAMEN[neu.plattform];
    const zeilen: Wirkung[] = [];
    const s = neu.security;
    const sperre = (sec: NonNullable<VersionDocument['security']>): Wirkung[] => [
        {
            kritisch: true,
            text: `Sicherheitsupdate: ${name}-Apps unter ${sec.min_version} fragen zweimal nach, zeigen dann einen Countdown und sperren sich danach bis zum Update.`,
        },
        sec.daten_loeschen
            ? { kritisch: true, text: 'Beim Sperren meldet die App ab und löscht die Mitgliederdaten. Es gibt keinen Notfallzugang.' }
            : { text: 'Daten bleiben beim Sperren erhalten, Notfallkontakte bleiben lesbar.' },
    ];
    if (alt == null) {
        zeilen.push({ text: `${name} neu: latest ${neu.latest}, min_supported ${neu.min_supported}.` });
        return s == null ? zeilen : [...zeilen, ...sperre(s)];
    }
    if (alt.latest !== neu.latest) {
        zeilen.push({ text: `latest ${alt.latest} → ${neu.latest}: Hinweis „Update verfügbar“ für ${name}-Apps unter ${neu.latest}.` });
    }
    if (alt.min_supported !== neu.min_supported) {
        zeilen.push({ text: `min_supported ${alt.min_supported} → ${neu.min_supported}: ${name}-Apps darunter zeigen „Update erforderlich“, ohne Sperre.` });
    }
    if (alt.store_url !== neu.store_url) {
        zeilen.push({ text: `Store-Adresse geändert: ${neu.store_url}` });
    }
    const a = alt.security;
    if (a == null && s != null) {
        zeilen.push(...sperre(s).map((z, i) => (i === 0 ? { ...z, text: z.text.replace('Sicherheitsupdate:', 'Sicherheitsupdate neu:') } : z)));
    } else if (a != null && s == null) {
        zeilen.push({ text: 'Sicherheitsupdate entfernt: Nachfrage, Countdown und Sperre verschwinden beim nächsten Abruf.' });
    } else if (a != null && s != null && JSON.stringify(a) !== JSON.stringify(s)) {
        zeilen.push(...sperre(s).map((z, i) => (i === 0 ? { ...z, text: z.text.replace('Sicherheitsupdate:', 'Sicherheitsupdate geändert:') } : z)));
    }
    return zeilen.length === 0 ? [{ text: 'Keine Änderung.' }] : zeilen;
};
