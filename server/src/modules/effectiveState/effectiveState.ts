import type { RawSnapshotDocument } from '../stammesSnapshot/persistence.js';
import {
    type CountByGender,
    type StammMetrics,
    type Stufe,
    STUFEN,
    SUPPORTED_SCHEMA_VERSION,
} from '../stammesSnapshot/schema.js';
import { subtractUtcMonths } from '../../shared/time.js';

// Snapshots zaehlen nur, wenn ihr Eingang beim Server hoechstens so lange zurueckliegt.
export const MAX_SNAPSHOT_AGE_MONTHS = 2;

export const snapshotWindowStart = (now: Date): Date => subtractUtcMonths(now, MAX_SNAPSHOT_AGE_MONTHS);

export const GESCHLECHTER = ['gesamt', 'maennlich', 'weiblich', 'divers', 'geschlecht_unbekannt'] as const;

// Haltefrist: Eine Installation, die einen Teil des Stammes in dieser Frist abgedeckt hat, gilt
// fuer diesen Teil als aktiv. Unter den aktiven gewinnt die, die den Stamm am laengsten kennt;
// neuere Werte anderer Installationen werden zurueckgehalten, bis sie auslaeuft. So kann eine
// fremde Installation einen aktiv teilnehmenden Stamm nicht ueberschreiben.
export const HALTEFRIST_DAYS = 14;

const DAY_MS = 24 * 60 * 60 * 1000;

export type GruppenZaehler = {
    mitglieder: CountByGender;
    leitende: CountByGender;
};

export type Herkunft = {
    received_at: Date;
    sender_pseudonym: string;
};

export type GruppenWert = GruppenZaehler & Herkunft;

export type EffectiveGruppe = {
    gruppe_pseudonym: string;
    stufe: Stufe;
    // Wert der Installation mit Vorrang; null, wenn niemand die Gruppe im Fenster abgedeckt hat.
    wert: GruppenWert | null;
    // Verschiedene Sender im Fenster, die diese Gruppe abgedeckt haben.
    abdeckende_sender: number;
};

// Eine Stufe ist ein eigener Teil: Ihre Summe stammt aus genau einer Installation, die alle
// Gruppen der Stufe abdeckt. Sonst liesse sich eine unvollstaendige Stufe mit erfundenen
// Gruppen auffuellen und die echte Gruppe aus der Summe herausrechnen.
export type EffectiveStufe = {
    stufe: Stufe;
    // null, wenn keine Installation alle Gruppen der Stufe abgedeckt hat.
    wert: (Herkunft & { gruppen: GruppenZaehler[] }) | null;
};

// Zusammengefuehrter Stand eines Stammes aus allen Snapshots im Fenster (siehe
// spec/stammes_snapshot.md, Abschnitt Effektiver Stand). Abgeleitete Kennzahlen werden
// erst bei der Aggregation gebildet, damit dort erneut das aktuelle Fenster gilt.
export type EffectiveStateDocument = {
    stamm_pseudonym: string;
    dv_id: string | null;
    bezirk_id: string | null;
    // Eingang des Snapshots, aus dem Struktur, DV und Bezirk stammen.
    struktur_as_of: Date;
    stammweit: (Herkunft & { metrics: StammMetrics }) | null;
    gruppen: EffectiveGruppe[];
    // Nur Stufen, die laut Struktur Gruppen haben.
    stufen: EffectiveStufe[];
    sender_count: number;
};

export type EffectiveStatesRepository = {
    upsert(state: EffectiveStateDocument): Promise<void>;
    remove(stammPseudonym: string): Promise<void>;
    replaceAll(states: EffectiveStateDocument[]): Promise<void>;
    findAll(): Promise<EffectiveStateDocument[]>;
};

type SnapshotRecency = Pick<RawSnapshotDocument, 'received_at'>;

// Aktualitaet bestimmt der Server: Zeitstempel des Clients koennten vordatiert sein.
export const isNewerSnapshot = (candidate: SnapshotRecency, current: SnapshotRecency): boolean =>
    candidate.received_at.getTime() > current.received_at.getTime();

const herkunft = (snapshot: RawSnapshotDocument): Herkunft => ({
    received_at: snapshot.received_at,
    sender_pseudonym: snapshot.sender_pseudonym,
});

// Seit wann die Installation den Stamm kennt. first_seen_at fehlt nur bei Altbestand.
const kenntSeitJeSender = (snapshots: RawSnapshotDocument[]): Map<string, number> => {
    const kenntSeit = new Map<string, number>();
    for (const snapshot of snapshots) {
        const seit = (snapshot.first_seen_at ?? snapshot.received_at).getTime();
        kenntSeit.set(snapshot.sender_pseudonym, Math.min(seit, kenntSeit.get(snapshot.sender_pseudonym) ?? seit));
    }
    return kenntSeit;
};

const nachSender = (a: RawSnapshotDocument, b: RawSnapshotDocument): number =>
    a.sender_pseudonym.localeCompare(b.sender_pseudonym);

const neuesterZuerst = (a: RawSnapshotDocument, b: RawSnapshotDocument): number =>
    b.received_at.getTime() - a.received_at.getTime() || nachSender(a, b);

// Waehlt fuer einen Teil des Stammes den Snapshot mit Vorrang unter den Kandidaten, die ihn abdecken.
const waehle = (
    kandidaten: RawSnapshotDocument[],
    kenntSeit: Map<string, number>,
    aktivAb: number,
): RawSnapshotDocument | undefined => {
    const aktive = kandidaten.filter((snapshot) => snapshot.received_at.getTime() >= aktivAb);

    if (aktive.length === 0) {
        return [...kandidaten].sort(neuesterZuerst)[0];
    }

    return aktive.sort((a, b) =>
        (kenntSeit.get(a.sender_pseudonym) ?? 0) - (kenntSeit.get(b.sender_pseudonym) ?? 0)
        || neuesterZuerst(a, b))[0];
};

const findeGruppe = (snapshot: RawSnapshotDocument, gruppePseudonym: string) =>
    snapshot.gruppen.find((candidate) => candidate.gruppe_pseudonym === gruppePseudonym && candidate.abgedeckt);

const zaehler = (gruppe: RawSnapshotDocument['gruppen'][number] | undefined): GruppenZaehler | null =>
    gruppe?.mitglieder != null && gruppe.leitende != null
        ? { mitglieder: gruppe.mitglieder, leitende: gruppe.leitende }
        : null;

export const mergeStammSnapshots = (
    snapshots: RawSnapshotDocument[],
    since: Date,
    now: Date,
): EffectiveStateDocument | null => {
    const fresh = snapshots.filter((snapshot) =>
        snapshot.schema_version === SUPPORTED_SCHEMA_VERSION
        && snapshot.received_at.getTime() >= since.getTime());
    const kenntSeit = kenntSeitJeSender(fresh);
    const aktivAb = now.getTime() - HALTEFRIST_DAYS * DAY_MS;
    const struktur = waehle(fresh, kenntSeit, aktivAb);

    if (struktur == null) {
        return null;
    }

    const stammSnapshot = waehle(
        fresh.filter((snapshot) => snapshot.abdeckung === 'stamm' && snapshot.metrics != null),
        kenntSeit,
        aktivAb,
    );

    const gruppen = struktur.gruppen.map((strukturGruppe): EffectiveGruppe => {
        const abdeckende = fresh.filter((snapshot) => findeGruppe(snapshot, strukturGruppe.gruppe_pseudonym) != null);
        const gewaehlt = waehle(abdeckende, kenntSeit, aktivAb);
        const werte = gewaehlt == null ? null : zaehler(findeGruppe(gewaehlt, strukturGruppe.gruppe_pseudonym));

        return {
            gruppe_pseudonym: strukturGruppe.gruppe_pseudonym,
            stufe: strukturGruppe.stufe,
            wert: gewaehlt != null && werte != null ? { ...werte, ...herkunft(gewaehlt) } : null,
            abdeckende_sender: new Set(abdeckende.map((snapshot) => snapshot.sender_pseudonym)).size,
        };
    });

    const stufen = STUFEN.flatMap((stufe): EffectiveStufe[] => {
        const ids = struktur.gruppen.filter((gruppe) => gruppe.stufe === stufe).map((gruppe) => gruppe.gruppe_pseudonym);
        if (ids.length === 0) {
            return [];
        }
        const vollstaendige = fresh.filter((snapshot) =>
            ids.every((id) => zaehler(findeGruppe(snapshot, id)) != null));
        const gewaehlt = waehle(vollstaendige, kenntSeit, aktivAb);

        return [{
            stufe,
            wert: gewaehlt == null
                ? null
                : {
                    ...herkunft(gewaehlt),
                    gruppen: ids.map((id) => zaehler(findeGruppe(gewaehlt, id)) as GruppenZaehler),
                },
        }];
    });

    return {
        stamm_pseudonym: struktur.stamm_pseudonym,
        dv_id: struktur.dv_id,
        bezirk_id: struktur.bezirk_id,
        struktur_as_of: struktur.received_at,
        stammweit: stammSnapshot?.metrics != null
            ? { metrics: stammSnapshot.metrics, ...herkunft(stammSnapshot) }
            : null,
        gruppen,
        stufen,
        sender_count: new Set(fresh.map((snapshot) => snapshot.sender_pseudonym)).size,
    };
};

export const groupSnapshotsByStamm = (snapshots: RawSnapshotDocument[]): Map<string, RawSnapshotDocument[]> => {
    const byStamm = new Map<string, RawSnapshotDocument[]>();

    for (const snapshot of snapshots) {
        const list = byStamm.get(snapshot.stamm_pseudonym) ?? [];
        list.push(snapshot);
        byStamm.set(snapshot.stamm_pseudonym, list);
    }

    return byStamm;
};

export const mergeAllStammSnapshots = (
    snapshots: RawSnapshotDocument[],
    since: Date,
    now: Date,
): EffectiveStateDocument[] =>
    [...groupSnapshotsByStamm(snapshots).values()]
        .map((stammSnapshots) => mergeStammSnapshots(stammSnapshots, since, now))
        .filter((state): state is EffectiveStateDocument => state != null);

// ------------------------------------------------------------ Ableitung

// Gruppen mit hoechstens so vielen Mitgliedern (ohne Leitende) gelten als nicht aktiv und
// zaehlen nirgends; Staemme mit weniger als MIN_STAMM_MITGLIEDER liefern nur Gruppenwerte.
// Beides haelt Kleinstwerte aus dem Aggregat, die sich Einzelpersonen naehern (S-13).
export const MAX_MITGLIEDER_INAKTIVE_GRUPPE = 2;
export const MIN_STAMM_MITGLIEDER = 5;

export type DerivedMetrics = StammMetrics
    & Record<Stufe | `leitende_${Stufe}`, CountByGender>
    & { alle_stufen: CountByGender };

export type GruppeMitWert = EffectiveGruppe & { wert: GruppenWert };

export type DerivedStammState = {
    state: EffectiveStateDocument;
    metrics: DerivedMetrics;
    // Aktive Gruppen mit gueltigem Wert im Fenster, Grundlage fuer die Gruppengroesse.
    gruppen: GruppeMitWert[];
    // Gruppen je Stufe laut Struktur, ohne bekannt inaktive Gruppen.
    gruppen_je_stufe: Record<Stufe, number>;
    art: 'vollstaendig' | 'nur_gruppen' | 'gemischt';
    oldest: Date;
    newest: Date;
    // Stufen mit Gruppen, die keine Installation vollstaendig abgedeckt hat.
    unvollstaendige_stufen: number;
};

const leereVerteilung = (): CountByGender => ({
    gesamt: null, maennlich: null, weiblich: null, divers: null, geschlecht_unbekannt: null,
});

const leereStammMetrics = (): StammMetrics => ({
    aktive_mitglieder: {
        gesamt: null,
        normaler_beitrag: null,
        familienermaessigter_beitrag: null,
        sozialermaessigter_beitrag: null,
    },
    passive_mitglieder: null,
    leitende: {
        gesamt: null,
        unter_21: null,
        von_21_bis_30: null,
        von_31_bis_40: null,
        von_41_bis_50: null,
        von_51_bis_60: null,
        ueber_60: null,
    },
    nicht_leitende_erwachsene: null,
    stammesvorstand: null,
    kuraten: null,
});

// Feldweise Summe; ein fehlender Teilwert macht das Feld unbekannt.
const summiere = (verteilungen: CountByGender[]): CountByGender => {
    const summe = leereVerteilung();
    for (const feld of GESCHLECHTER) {
        let wert: number | null = 0;
        for (const verteilung of verteilungen) {
            const teil = verteilung[feld];
            wert = wert == null || teil == null ? null : wert + teil;
        }
        summe[feld] = wert;
    }
    return summe;
};

// Unbekannte Groesse gilt nicht als inaktiv.
export const istAktiveGruppe = (gruppe: GruppenZaehler): boolean =>
    gruppe.mitglieder.gesamt == null || gruppe.mitglieder.gesamt > MAX_MITGLIEDER_INAKTIVE_GRUPPE;

// Leitet die Kennzahlen eines Stammes zum Zeitpunkt der Aggregation ab: Teile, die inzwischen
// aus dem Fenster gefallen sind, zaehlen nicht mehr.
export const deriveStammState = (state: EffectiveStateDocument, since: Date): DerivedStammState | null => {
    const istFrisch = (datum: Date) => datum.getTime() >= since.getTime();

    if (!istFrisch(state.struktur_as_of)) {
        return null;
    }

    const gruppen = state.gruppen.map((gruppe) => ({
        ...gruppe,
        wert: gruppe.wert != null && istFrisch(gruppe.wert.received_at) ? gruppe.wert : null,
    }));
    const mitWert = gruppen.filter((gruppe): gruppe is GruppeMitWert => gruppe.wert != null && istAktiveGruppe(gruppe.wert));
    const bekanntInaktiv = new Set(gruppen
        .filter((gruppe) => gruppe.wert != null && !istAktiveGruppe(gruppe.wert))
        .map((gruppe) => gruppe.gruppe_pseudonym));

    const stammweitImFenster = state.stammweit != null && istFrisch(state.stammweit.received_at)
        ? state.stammweit
        : null;
    const mitgliederImStamm = stammweitImFenster?.metrics.aktive_mitglieder.gesamt
        ?? mitWert.reduce((summe, gruppe) => summe + (gruppe.wert.mitglieder.gesamt ?? 0), 0);
    const istAktiverStamm = mitgliederImStamm >= MIN_STAMM_MITGLIEDER;
    const stammweit = istAktiverStamm ? stammweitImFenster : null;

    if (stammweit == null && mitWert.length === 0) {
        return null;
    }

    // Stufen ohne Gruppe, ohne aktive Gruppe oder in einem Kleinststamm bleiben unbekannt,
    // damit sie nicht als liefernder Stamm zaehlen.
    const stufenMetrics = {} as Record<Stufe | `leitende_${Stufe}`, CountByGender>;
    const alleStufen: CountByGender[] = [];
    let alleStufenBekannt = istAktiverStamm;
    let unvollstaendigeStufen = 0;
    for (const stufe of STUFEN) {
        stufenMetrics[stufe] = leereVerteilung();
        stufenMetrics[`leitende_${stufe}`] = leereVerteilung();
        const eintrag = state.stufen.find((kandidat) => kandidat.stufe === stufe);
        if (eintrag == null) {
            continue;
        }
        if (eintrag.wert == null || !istFrisch(eintrag.wert.received_at)) {
            unvollstaendigeStufen += 1;
            alleStufenBekannt = false;
            continue;
        }
        const aktive = eintrag.wert.gruppen.filter(istAktiveGruppe);
        if (!istAktiverStamm || aktive.length === 0) {
            continue;
        }
        stufenMetrics[stufe] = summiere(aktive.map((wert) => wert.mitglieder));
        stufenMetrics[`leitende_${stufe}`] = summiere(aktive.map((wert) => wert.leitende));
        alleStufen.push(stufenMetrics[stufe]);
    }

    const ausStammSnapshot = (wert: GruppenWert) =>
        stammweit != null
        && wert.sender_pseudonym === stammweit.sender_pseudonym
        && wert.received_at.getTime() === stammweit.received_at.getTime();
    const art = stammweit == null
        ? 'nur_gruppen'
        : mitWert.every((gruppe) => ausStammSnapshot(gruppe.wert)) ? 'vollstaendig' : 'gemischt';

    const zeiten = [
        ...(stammweit == null ? [] : [stammweit.received_at.getTime()]),
        ...mitWert.map((gruppe) => gruppe.wert.received_at.getTime()),
    ];

    return {
        state,
        metrics: {
            ...(stammweit?.metrics ?? leereStammMetrics()),
            ...stufenMetrics,
            alle_stufen: alleStufenBekannt ? summiere(alleStufen) : leereVerteilung(),
        },
        gruppen: mitWert,
        gruppen_je_stufe: Object.fromEntries(STUFEN.map((stufe) => [
            stufe,
            state.gruppen.filter((gruppe) => gruppe.stufe === stufe && !bekanntInaktiv.has(gruppe.gruppe_pseudonym)).length,
        ])) as Record<Stufe, number>,
        art,
        oldest: new Date(Math.min(...zeiten)),
        newest: new Date(Math.max(...zeiten)),
        unvollstaendige_stufen: unvollstaendigeStufen,
    };
};
