// Feeds der App fuer /admin/betrieb: notifications.json und version.json liegen auf GitHub Pages
// und werden nur gelesen und geprueft. Der Server haengt nicht von ihnen ab.

export type FeedFetcher = {
    // Liefert den geparsten JSON-Inhalt oder wirft bei Netz-, Status- oder JSON-Fehler.
    fetchJson(url: string): Promise<unknown>;
};

const FETCH_TIMEOUT_MS = 5000;

export const httpFeedFetcher: FeedFetcher = {
    async fetchJson(url) {
        const response = await fetch(url, {
            signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
            headers: { accept: 'application/json' },
            redirect: 'error',
        });
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        return response.json();
    },
};

export type Befund = { stufe: 'fehler' | 'warnung'; text: string };

export type MeldungStatus = 'aktiv' | 'geplant' | 'abgelaufen';

export type MeldungZeile = {
    id: string;
    type: string;
    platform: string;
    titelDe: string;
    titelEn: string;
    startsAt: Date | null;
    endsAt: Date | null;
    status: MeldungStatus;
    link: string | null;
};

export type PlattformVersion = {
    plattform: 'android' | 'ios';
    latest: string | null;
    minSupported: string | null;
    storeUrl: string | null;
    ok: boolean;
};

const TYPEN = ['info', 'warn', 'urgent'];
const PLATTFORMEN = ['all', 'android', 'ios'];
const STORE_HOSTS: Record<PlattformVersion['plattform'], string> = {
    android: 'play.google.com',
    ios: 'apps.apple.com',
};
const SEMVER = /^(\d+)\.(\d+)\.(\d+)$/;

const istObjekt = (value: unknown): value is Record<string, unknown> =>
    typeof value === 'object' && value != null && !Array.isArray(value);

const text = (value: unknown): string => (typeof value === 'string' ? value.trim() : '');

// Titel und Text sind {de, en} oder (Altformat) ein einzelner String fuer beide Sprachen.
const sprachen = (value: unknown): { de: string; en: string } =>
    typeof value === 'string' ? { de: value.trim(), en: value.trim() } : istObjekt(value) ? { de: text(value.de), en: text(value.en) } : { de: '', en: '' };

const datumOderFehler = (value: unknown): Date | null | 'ungueltig' => {
    if (value == null) {
        return null;
    }
    if (typeof value !== 'string') {
        return 'ungueltig';
    }
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'ungueltig' : date;
};

const istHttps = (value: string): boolean => {
    try {
        return new URL(value).protocol === 'https:';
    } catch {
        return false;
    }
};

export const pruefeMeldungen = (data: unknown, now: Date): { zeilen: MeldungZeile[]; befunde: Befund[] } => {
    const befunde: Befund[] = [];
    const items = Array.isArray(data) ? data : istObjekt(data) && Array.isArray(data.items) ? data.items : null;
    if (items == null) {
        return { zeilen: [], befunde: [{ stufe: 'fehler', text: 'notifications.json: weder Liste noch {"items": [...]}.' }] };
    }

    const gesehen = new Set<string>();
    const zeilen: MeldungZeile[] = [];
    items.forEach((item: unknown, index) => {
        if (!istObjekt(item)) {
            befunde.push({ stufe: 'fehler', text: `Eintrag ${index + 1}: kein Objekt.` });
            return;
        }
        const id = text(item.id);
        const name = id === '' ? `Eintrag ${index + 1}` : `Meldung „${id}“`;
        if (id === '') {
            befunde.push({ stufe: 'fehler', text: `${name}: id fehlt, die App verwirft den Feed.` });
        } else if (gesehen.has(id)) {
            befunde.push({ stufe: 'fehler', text: `${name}: id doppelt, Bestätigungen gelten dann für beide.` });
        }
        gesehen.add(id);

        const type = text(item.type) || 'info';
        if (!TYPEN.includes(type)) {
            befunde.push({ stufe: 'warnung', text: `${name}: unbekannter type „${type}“, die App zeigt ihn als info.` });
        }
        const platform = text(item.platform) || 'all';
        if (!PLATTFORMEN.includes(platform.toLowerCase())) {
            befunde.push({ stufe: 'warnung', text: `${name}: unbekannte platform „${platform}“, die Meldung erscheint nirgends.` });
        }

        const titel = sprachen(item.title);
        const body = sprachen(item.body);
        for (const [feld, werte] of [['title', titel], ['body', body]] as const) {
            if (werte.de === '') {
                befunde.push({ stufe: 'warnung', text: `${name}: ${feld}.de fehlt.` });
            }
            if (werte.en === '') {
                befunde.push({ stufe: 'warnung', text: `${name}: ${feld}.en fehlt.` });
            }
        }

        const start = datumOderFehler(item.starts_at);
        const ende = datumOderFehler(item.ends_at);
        if (start === 'ungueltig' || ende === 'ungueltig') {
            befunde.push({ stufe: 'fehler', text: `${name}: starts_at oder ends_at ist kein gültiges Datum.` });
        }
        const startsAt = start === 'ungueltig' ? null : start;
        const endsAt = ende === 'ungueltig' ? null : ende;
        if (startsAt != null && endsAt != null && endsAt <= startsAt) {
            befunde.push({ stufe: 'fehler', text: `${name}: ends_at liegt nicht nach starts_at.` });
        }

        const status: MeldungStatus = endsAt != null && endsAt <= now ? 'abgelaufen' : startsAt != null && startsAt > now ? 'geplant' : 'aktiv';
        if (status === 'abgelaufen') {
            befunde.push({ stufe: 'warnung', text: `${name}: abgelaufen, kann aus dem Feed entfernt werden.` });
        }

        const externalLink = text(item.external_link);
        if (externalLink !== '' && !istHttps(externalLink)) {
            befunde.push({ stufe: 'warnung', text: `${name}: external_link ist nicht https, die App öffnet ihn nicht.` });
        }
        const deepLink = text(item.deep_link);
        if (deepLink !== '' && !deepLink.startsWith('/')) {
            befunde.push({ stufe: 'warnung', text: `${name}: deep_link beginnt nicht mit „/“.` });
        }

        zeilen.push({
            id,
            type,
            platform,
            titelDe: titel.de,
            titelEn: titel.en,
            startsAt,
            endsAt,
            status,
            link: deepLink || externalLink || null,
        });
    });
    return { zeilen, befunde };
};

const vergleiche = (a: string, b: string): number => {
    const x = SEMVER.exec(a)!.slice(1).map(Number);
    const y = SEMVER.exec(b)!.slice(1).map(Number);
    return x[0] - y[0] || x[1] - y[1] || x[2] - y[2];
};

export const pruefeVersionen = (data: unknown): { plattformen: PlattformVersion[]; befunde: Befund[] } => {
    const befunde: Befund[] = [];
    if (!istObjekt(data)) {
        return { plattformen: [], befunde: [{ stufe: 'fehler', text: 'version.json: kein Objekt.' }] };
    }
    const plattformen = (['android', 'ios'] as const).map((plattform): PlattformVersion => {
        const name = plattform === 'android' ? 'Android' : 'iOS';
        const eintrag = data[plattform];
        if (!istObjekt(eintrag)) {
            befunde.push({ stufe: 'fehler', text: `Version ${name}: Eintrag fehlt, die App prüft dort keine Updates.` });
            return { plattform, latest: null, minSupported: null, storeUrl: null, ok: false };
        }
        const latest = text(eintrag.latest);
        const minSupported = text(eintrag.min_supported);
        const storeUrl = text(eintrag.store_url);
        const vorher = befunde.length;
        for (const [feld, wert] of [['latest', latest], ['min_supported', minSupported]] as const) {
            if (!SEMVER.test(wert)) {
                befunde.push({ stufe: 'fehler', text: `Version ${name}: ${feld} „${wert}“ ist keine Version x.y.z.` });
            }
        }
        if (SEMVER.test(latest) && SEMVER.test(minSupported) && vergleiche(latest, minSupported) < 0) {
            befunde.push({ stufe: 'fehler', text: `Version ${name}: latest ${latest} liegt unter min_supported ${minSupported}, niemand kann aktualisieren.` });
        }
        let storeOk = false;
        try {
            const url = new URL(storeUrl);
            storeOk = url.protocol === 'https:' && url.hostname === STORE_HOSTS[plattform];
        } catch {
            storeOk = false;
        }
        if (!storeOk) {
            befunde.push({ stufe: 'warnung', text: `Version ${name}: store_url ist kein https-Link auf ${STORE_HOSTS[plattform]}.` });
        }
        return {
            plattform,
            latest: latest || null,
            minSupported: minSupported || null,
            storeUrl: storeUrl || null,
            ok: befunde.length === vorher,
        };
    });
    return { plattformen, befunde };
};
