import { toIsoWeek } from '../../shared/time.js';
import {
    type DerivedStammState,
    deriveStammState,
    type EffectiveStateDocument,
    GESCHLECHTER,
    snapshotWindowStart,
} from '../effectiveState/effectiveState.js';
import { type Stufe, STUFEN } from '../stammesSnapshot/schema.js';

export { MAX_SNAPSHOT_AGE_MONTHS } from '../effectiveState/effectiveState.js';

export const BUND_AGGREGATION_TYPE = 'bund';

export type MetricAggregate = {
    // null nur in ausgelieferten Antworten, wenn die Kennzahl unterdrueckt wurde.
    sum: number | null;
    stamm_count: number;
    median: number | null;
};

export type AggregatedMetrics = {
    [metric: string]: MetricAggregate | AggregatedMetrics;
};

// Kennzahl ueber Gruppen: Median je Gruppe, unterdrueckt wird nach Anzahl der Staemme.
export type GruppenMetricAggregate = MetricAggregate & {
    gruppen_count: number;
};

type Geschlecht = (typeof GESCHLECHTER)[number];

export type StufenGruppenAggregat = {
    gruppen_count: number;
    stamm_count: number;
    gruppen_pro_stamm: MetricAggregate;
    mitglieder: Record<Geschlecht, GruppenMetricAggregate>;
    leitende: Record<Geschlecht, GruppenMetricAggregate>;
};

export type GruppenJeStufe = Record<Stufe, StufenGruppenAggregat>;

export type WeeklyAggregateDocument = {
    aggregation_week: string;
    aggregation_type: typeof BUND_AGGREGATION_TYPE;
    generated_at: Date;
    participating_stamm_count: number;
    oldest_data_as_of: Date | null;
    newest_data_as_of: Date | null;
    metrics: AggregatedMetrics | null;
    gruppen_je_stufe: GruppenJeStufe | null;
};

export type WeeklyAggregatesRepository = {
    upsert(document: WeeklyAggregateDocument): Promise<void>;
    findLatest(aggregationType: typeof BUND_AGGREGATION_TYPE): Promise<WeeklyAggregateDocument | null>;
};

export const isMetricAggregate = (value: MetricAggregate | AggregatedMetrics): value is MetricAggregate =>
    typeof value.stamm_count === 'number';

const median = (values: number[]): number | null => {
    if (values.length === 0) {
        return null;
    }

    const sorted = [...values].sort((a, b) => a - b);
    const middle = Math.floor(sorted.length / 2);

    return sorted.length % 2 === 0
        ? ((sorted[middle - 1] ?? 0) + (sorted[middle] ?? 0)) / 2
        : sorted[middle] ?? null;
};

const aggregateLeaf = (values: unknown[]): MetricAggregate => {
    const numbers = values.filter((value): value is number => typeof value === 'number');

    return {
        sum: numbers.reduce((total, value) => total + value, 0),
        stamm_count: numbers.length,
        median: median(numbers),
    };
};

// Die abgeleiteten Kennzahlen haben bei allen Staemmen dieselbe Struktur; die Struktur des
// ersten Eintrags dient als Vorlage.
const aggregateNode = (template: Record<string, unknown>, nodes: Array<Record<string, unknown>>): AggregatedMetrics => {
    const result: AggregatedMetrics = {};

    for (const [key, templateValue] of Object.entries(template)) {
        const children = nodes.map((node) => node[key]);

        result[key] = templateValue != null && typeof templateValue === 'object'
            ? aggregateNode(
                templateValue as Record<string, unknown>,
                children.map((child) => (child ?? {}) as Record<string, unknown>),
            )
            : aggregateLeaf(children);
    }

    return result;
};

const aggregateGruppenLeaf = (eintraege: Array<{ stamm: string; wert: number | null }>): GruppenMetricAggregate => {
    const mitWert = eintraege.filter((eintrag): eintrag is { stamm: string; wert: number } => eintrag.wert != null);
    const werte = mitWert.map((eintrag) => eintrag.wert);

    return {
        sum: werte.reduce((total, value) => total + value, 0),
        stamm_count: new Set(mitWert.map((eintrag) => eintrag.stamm)).size,
        gruppen_count: werte.length,
        median: median(werte),
    };
};

export const computeGruppenJeStufe = (derived: DerivedStammState[]): GruppenJeStufe => {
    const result = {} as GruppenJeStufe;

    for (const stufe of STUFEN) {
        const gruppen = derived.flatMap((stamm) =>
            stamm.gruppen
                .filter((gruppe) => gruppe.stufe === stufe)
                .map((gruppe) => ({ stamm: stamm.state.stamm_pseudonym, wert: gruppe.wert })));
        const proStamm = derived
            .map((stamm) => stamm.state.gruppen.filter((gruppe) => gruppe.stufe === stufe).length)
            .filter((anzahl) => anzahl > 0);
        const verteilung = (art: 'mitglieder' | 'leitende') =>
            Object.fromEntries(GESCHLECHTER.map((feld) => [
                feld,
                aggregateGruppenLeaf(gruppen.map((gruppe) => ({ stamm: gruppe.stamm, wert: gruppe.wert[art][feld] }))),
            ])) as Record<Geschlecht, GruppenMetricAggregate>;

        result[stufe] = {
            gruppen_count: gruppen.length,
            stamm_count: new Set(gruppen.map((gruppe) => gruppe.stamm)).size,
            gruppen_pro_stamm: aggregateLeaf(proStamm),
            mitglieder: verteilung('mitglieder'),
            leitende: verteilung('leitende'),
        };
    }

    return result;
};

export const deriveAllStammStates = (states: EffectiveStateDocument[], now: Date): DerivedStammState[] => {
    const since = snapshotWindowStart(now);

    return states
        .map((state) => deriveStammState(state, since))
        .filter((derived): derived is DerivedStammState => derived != null);
};

export const computeBundAggregate = (
    states: EffectiveStateDocument[],
    now: Date,
): WeeklyAggregateDocument => {
    const derived = deriveAllStammStates(states, now);
    const metricNodes = derived.map((stamm) => stamm.metrics as unknown as Record<string, unknown>);
    const template = metricNodes[0];

    return {
        aggregation_week: toIsoWeek(now),
        aggregation_type: BUND_AGGREGATION_TYPE,
        generated_at: now,
        participating_stamm_count: derived.length,
        oldest_data_as_of: derived.length > 0
            ? new Date(Math.min(...derived.map((stamm) => stamm.oldest.getTime())))
            : null,
        newest_data_as_of: derived.length > 0
            ? new Date(Math.max(...derived.map((stamm) => stamm.newest.getTime())))
            : null,
        metrics: template == null ? null : aggregateNode(template, metricNodes),
        gruppen_je_stufe: derived.length > 0 ? computeGruppenJeStufe(derived) : null,
    };
};

const suppressLeaf = <T extends MetricAggregate>(value: T, minStammCount: number): T =>
    value.stamm_count >= minStammCount ? value : { ...value, sum: null, median: null };

// Kennzahlen, zu denen weniger als minStammCount Staemme Werte geliefert haben, werden
// nicht ausgeliefert, damit einzelne Staemme nicht rueckfuehrbar sind.
export const suppressSmallCounts = (metrics: AggregatedMetrics, minStammCount: number): AggregatedMetrics => {
    const result: AggregatedMetrics = {};

    for (const [key, value] of Object.entries(metrics)) {
        result[key] = isMetricAggregate(value)
            ? suppressLeaf(value, minStammCount)
            : suppressSmallCounts(value, minStammCount);
    }

    return result;
};

// Auch bei Gruppen zaehlen verschiedene Staemme, sonst waeren z. B. fuenf Meuten eines
// einzigen Stammes rueckfuehrbar.
export const suppressSmallGruppenCounts = (gruppenJeStufe: GruppenJeStufe, minStammCount: number): GruppenJeStufe => {
    const result = {} as GruppenJeStufe;

    for (const stufe of STUFEN) {
        const aggregat = gruppenJeStufe[stufe];
        const verteilung = (werte: Record<Geschlecht, GruppenMetricAggregate>) =>
            Object.fromEntries(GESCHLECHTER.map((feld) => [feld, suppressLeaf(werte[feld], minStammCount)])) as Record<
                Geschlecht,
                GruppenMetricAggregate
            >;

        result[stufe] = {
            ...aggregat,
            gruppen_pro_stamm: suppressLeaf(aggregat.gruppen_pro_stamm, minStammCount),
            mitglieder: verteilung(aggregat.mitglieder),
            leitende: verteilung(aggregat.leitende),
        };
    }

    return result;
};
