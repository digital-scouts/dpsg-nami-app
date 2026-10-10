// Meldungen und Versionen fuer die App (spec/app_feeds.md). Der Betreiber pflegt sie unter
// /admin/meldungen und /admin/versionen, die App liest sie ueber /app/notifications und /app/version.
// Die Daten sind nicht personenbezogen und haben deshalb keine Speicherfrist.

export const MELDUNG_TYPEN = ['info', 'warn', 'urgent'] as const;
export type MeldungTyp = (typeof MELDUNG_TYPEN)[number];

export const MELDUNG_PLATTFORMEN = ['all', 'android', 'ios'] as const;
export type MeldungPlattform = (typeof MELDUNG_PLATTFORMEN)[number];

export const PLATTFORMEN = ['android', 'ios'] as const;
export type Plattform = (typeof PLATTFORMEN)[number];

export const PLATTFORM_NAMEN: Record<Plattform, string> = { android: 'Android', ios: 'iOS' };

// Ziele, die die App per deep_link oeffnet (erlaubteMeldungsZiele in
// lib/presentation/notifications/notification_links.dart). Andere ignoriert sie.
export const APP_ZIELE: ReadonlyArray<{ pfad: string; name: string }> = [
    { pfad: '/settings/messages', name: 'Meldungen' },
    { pfad: '/settings/notifications', name: 'Mitteilungen' },
    { pfad: '/settings/qualifikationen', name: 'Qualifikationen' },
    { pfad: '/achievements', name: 'Erfolge' },
    { pfad: '/supporter', name: 'Unterstützen' },
];

export type Sprachen = { de: string; en: string };

export type MeldungDocument = {
    id: string;
    type: MeldungTyp;
    platform: MeldungPlattform;
    title: Sprachen;
    body: Sprachen;
    starts_at: Date | null;
    ends_at: Date | null;
    external_link: string | null;
    deep_link: string | null;
    created_at: Date;
    updated_at: Date;
};

export type SicherheitsUpdate = {
    min_version: string;
    betrifft: string;
    betrifft_en: string;
    daten_loeschen: boolean;
};

export type VersionDocument = {
    plattform: Plattform;
    latest: string;
    min_supported: string;
    store_url: string;
    security: SicherheitsUpdate | null;
    updated_at: Date;
};

// Gespeichert wird nur, wenn der Stand noch der gelesene ist (erwartet = updated_at beim Lesen,
// null beim Anlegen). Sonst false, damit zwei offene Tabs sich nicht ueberschreiben.
export type MeldungenRepository = {
    findAll(): Promise<MeldungDocument[]>;
    find(id: string): Promise<MeldungDocument | null>;
    save(document: MeldungDocument, erwartet: Date | null): Promise<boolean>;
    delete(id: string, erwartet: Date): Promise<boolean>;
};

export type VersionenRepository = {
    findAll(): Promise<VersionDocument[]>;
    save(document: VersionDocument, erwartet: Date | null): Promise<boolean>;
};

const iso = (date: Date | null) => (date == null ? undefined : date.toISOString());

// Format von notifications.json, das die App seit jeher liest; leere Felder fallen weg.
export const meldungFuerApp = (m: MeldungDocument) => ({
    id: m.id,
    type: m.type,
    platform: m.platform,
    title: m.title,
    body: m.body,
    starts_at: iso(m.starts_at),
    ends_at: iso(m.ends_at),
    external_link: m.external_link ?? undefined,
    deep_link: m.deep_link ?? undefined,
    created_at: m.created_at.toISOString(),
    updated_at: m.updated_at.toISOString(),
});

// Format von version.json je Plattform.
export const versionFuerApp = (v: VersionDocument) => ({
    latest: v.latest,
    min_supported: v.min_supported,
    store_url: v.store_url,
    ...(v.security == null ? {} : { security: v.security }),
});

export const sortiereMeldungen = (meldungen: MeldungDocument[]): MeldungDocument[] =>
    [...meldungen].sort((a, b) => b.created_at.getTime() - a.created_at.getTime() || a.id.localeCompare(b.id));
