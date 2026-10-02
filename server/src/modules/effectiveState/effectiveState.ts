import type { RawSnapshotDocument } from '../stammesSnapshot/persistence.js';
import {
    type CountByGender,
    type StammMetrics,
    type Stufe,
    STUFEN,
    SUPPORTED_SCHEMA_VERSION,
} from '../stammesSnapshot/schema.js';
import { subtractUtcMonths } from '../../shared/time.js';

// Snapshots zaehlen nur, wenn ihr Datenstand hoechstens so alt ist.
export const MAX_SNAPSHOT_AGE_MONTHS = 2;

export const snapshotWindowStart = (now: Date): Date => subtractUtcMonths(now, MAX_SNAPSHOT_AGE_MONTHS);

export const GESCHLECHTER = ['gesamt', 'maennlich', 'weiblich', 'divers', 'geschlecht_unbekannt'] as const;

export type GruppenWert = {
    mitglieder: CountByGender;
    leitende: CountByGender;
    source_data_as_of: Date;
    sender_pseudonym: string;
};

export type EffectiveGruppe = {
    gruppe_pseudonym: string;
    stufe: Stufe;
    // Neuester abdeckender Wert im Fenster; null, wenn niemand die Gruppe abgedeckt hat.
    wert: GruppenWert | null;
    // Verschiedene Sender im Fenster, die diese Gruppe abgedeckt haben.
    abdeckende_sender: number;
};

// Zusammengefuehrter Stand eines Stammes aus allen Snapshots im Fenster (siehe
// spec/stammes_snapshot.md, Abschnitt Effektiver Stand). Abgeleitete Kennzahlen werden
// erst bei der Aggregation gebildet, damit dort erneut das aktuelle Fenster gilt.
export type EffectiveStateDocument = {
    stamm_pseudonym: string;
    dv_id: string | null;
    bezirk_id: string | null;
    struktur_as_of: Date;
    stammweit: {
        metrics: StammMetrics;
        source_data_as_of: Date;
        sender_pseudonym: string;
    } | null;
    gruppen: EffectiveGruppe[];
    sender_count: number;
};

export type EffectiveStatesRepository = {
    upsert(state: EffectiveStateDocument): Promise<void>;
    remove(stammPseudonym: string): Promise<void>;
    replaceAll(states: EffectiveStateDocument[]): Promise<void>;
    findAll(): Promise<EffectiveStateDocument[]>;
};

type SnapshotRecency = Pick<RawSnapshotDocument, 'source_data_as_of' | 'sent_at'>;

// Primaer entscheidet source_data_as_of, nur bei Gleichstand sent_at.
export const isNewerSnapshot = (candidate: SnapshotRecency, current: SnapshotRecency): boolean => {
    const candidateSource = candidate.source_data_as_of.getTime();
    const currentSource = current.source_data_as_of.getTime();

    if (candidateSource !== currentSource) {
        return candidateSource > currentSource;
    }

    return candidate.sent_at.getTime() > current.sent_at.getTime();
};

const newestFirst = (a: SnapshotRecency, b: SnapshotRecency): number => {
    if (isNewerSnapshot(a, b)) return -1;
    if (isNewerSnapshot(b, a)) return 1;
    return 0;
};

export const mergeStammSnapshots = (
    snapshots: RawSnapshotDocument[],
    since: Date,
): EffectiveStateDocument | null => {
    const fresh = snapshots
        .filter((snapshot) =>
            snapshot.schema_version === SUPPORTED_SCHEMA_VERSION
            && snapshot.source_data_as_of.getTime() >= since.getTime())
        .sort(newestFirst);
    const newest = fresh[0];

    if (newest == null) {
        return null;
    }

    const stammSnapshot = fresh.find((snapshot) => snapshot.abdeckung === 'stamm' && snapshot.metrics != null);

    const gruppen = newest.gruppen.map((strukturGruppe): EffectiveGruppe => {
        const abdeckende = fresh.flatMap((snapshot) => {
            const gruppe = snapshot.gruppen.find((candidate) =>
                candidate.gruppe_pseudonym === strukturGruppe.gruppe_pseudonym && candidate.abgedeckt);
            return gruppe == null ? [] : [{ snapshot, gruppe }];
        });
        const neueste = abdeckende[0];

        return {
            gruppe_pseudonym: strukturGruppe.gruppe_pseudonym,
            stufe: strukturGruppe.stufe,
            wert: neueste?.gruppe.mitglieder != null && neueste.gruppe.leitende != null
                ? {
                    mitglieder: neueste.gruppe.mitglieder,
                    leitende: neueste.gruppe.leitende,
                    source_data_as_of: neueste.snapshot.source_data_as_of,
                    sender_pseudonym: neueste.snapshot.sender_pseudonym,
                }
                : null,
            abdeckende_sender: new Set(abdeckende.map(({ snapshot }) => snapshot.sender_pseudonym)).size,
        };
    });

    return {
        stamm_pseudonym: newest.stamm_pseudonym,
        dv_id: newest.dv_id,
        bezirk_id: newest.bezirk_id,
        struktur_as_of: newest.source_data_as_of,
        stammweit: stammSnapshot?.metrics != null
            ? {
                metrics: stammSnapshot.metrics,
                source_data_as_of: stammSnapshot.source_data_as_of,
                sender_pseudonym: stammSnapshot.sender_pseudonym,
            }
            : null,
        gruppen,
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

export const mergeAllStammSnapshots = (snapshots: RawSnapshotDocument[], since: Date): EffectiveStateDocument[] =>
    [...groupSnapshotsByStamm(snapshots).values()]
        .map((stammSnapshots) => mergeStammSnapshots(stammSnapshots, since))
        .filter((state): state is EffectiveStateDocument => state != null);

// ------------------------------------------------------------ Ableitung

export type DerivedMetrics = StammMetrics & Record<Stufe | `leitende_${Stufe}`, CountByGender>;

export type GruppeMitWert = EffectiveGruppe & { wert: GruppenWert };

export type DerivedStammState = {
    state: EffectiveStateDocument;
    metrics: DerivedMetrics;
    // Gruppen mit gueltigem Wert im Fenster, Grundlage fuer die Gruppengroesse.
    gruppen: GruppeMitWert[];
    art: 'vollstaendig' | 'nur_gruppen' | 'gemischt';
    oldest: Date;
    newest: Date;
    // Stufen mit Gruppen, von denen mindestens eine keinen Wert hat.
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

// Feldweise Summe; ein fehlender Teilwert macht das Feld unbekannt. Ohne Gruppen ist die Summe 0.
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

// Leitet die Kennzahlen eines Stammes zum Zeitpunkt der Aggregation ab: Teile, die inzwischen
// aus dem Fenster gefallen sind, zaehlen nicht mehr.
export const deriveStammState = (state: EffectiveStateDocument, since: Date): DerivedStammState | null => {
    const istFrisch = (datum: Date) => datum.getTime() >= since.getTime();

    if (!istFrisch(state.struktur_as_of)) {
        return null;
    }

    const stammweit = state.stammweit != null && istFrisch(state.stammweit.source_data_as_of)
        ? state.stammweit
        : null;
    const gruppen = state.gruppen.map((gruppe) => ({
        ...gruppe,
        wert: gruppe.wert != null && istFrisch(gruppe.wert.source_data_as_of) ? gruppe.wert : null,
    }));
    const mitWert = gruppen.filter((gruppe): gruppe is GruppeMitWert => gruppe.wert != null);

    if (stammweit == null && mitWert.length === 0) {
        return null;
    }

    const stufenMetrics = {} as Record<Stufe | `leitende_${Stufe}`, CountByGender>;
    let unvollstaendigeStufen = 0;
    for (const stufe of STUFEN) {
        const stufenGruppen = gruppen.filter((gruppe) => gruppe.stufe === stufe);
        const werte = stufenGruppen.flatMap((gruppe) => (gruppe.wert == null ? [] : [gruppe.wert]));
        if (werte.length < stufenGruppen.length) {
            unvollstaendigeStufen += 1;
            stufenMetrics[stufe] = leereVerteilung();
            stufenMetrics[`leitende_${stufe}`] = leereVerteilung();
            continue;
        }
        stufenMetrics[stufe] = summiere(werte.map((wert) => wert.mitglieder));
        stufenMetrics[`leitende_${stufe}`] = summiere(werte.map((wert) => wert.leitende));
    }

    const ausStammSnapshot = (wert: GruppenWert) =>
        stammweit != null
        && wert.sender_pseudonym === stammweit.sender_pseudonym
        && wert.source_data_as_of.getTime() === stammweit.source_data_as_of.getTime();
    const art = stammweit == null
        ? 'nur_gruppen'
        : mitWert.every((gruppe) => ausStammSnapshot(gruppe.wert)) ? 'vollstaendig' : 'gemischt';

    const zeiten = [
        ...(stammweit == null ? [] : [stammweit.source_data_as_of.getTime()]),
        ...mitWert.map((gruppe) => gruppe.wert.source_data_as_of.getTime()),
    ];

    return {
        state,
        metrics: { ...(stammweit?.metrics ?? leereStammMetrics()), ...stufenMetrics },
        gruppen: mitWert,
        art,
        oldest: new Date(Math.min(...zeiten)),
        newest: new Date(Math.max(...zeiten)),
        unvollstaendige_stufen: unvollstaendigeStufen,
    };
};
