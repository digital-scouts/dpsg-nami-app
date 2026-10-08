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
    // Letzte Aenderung des ausgelieferten Inhalts (Wochenlauf oder neue Staemme im Nachtlauf).
    generated_at: Date;
    // Letzter Wochenlauf: Bis zum naechsten bleiben die Werte bestehender Staemme eingefroren.
    full_refresh_at: Date;
    // Letzte Pruefung im Nachtlauf, auch wenn keine neuen Staemme dazukamen.
    checked_at: Date;
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
            .map((stamm) => stamm.gruppen_je_stufe[stufe])
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
): WeeklyAggregateDocument => computeBundAggregateFromDerived(deriveAllStammStates(states, now), now, now);

// Aggregat aus bereits abgeleiteten Staenden, z. B. eingefrorenen Staenden des letzten
// Wochenlaufs plus neuen Staemmen aus dem Nachtlauf.
export const computeBundAggregateFromDerived = (
    derived: DerivedStammState[],
    now: Date,
    fullRefreshAt: Date,
): WeeklyAggregateDocument => {
    const metricNodes = derived.map((stamm) => stamm.metrics as unknown as Record<string, unknown>);
    const template = metricNodes[0];

    return {
        aggregation_week: toIsoWeek(now),
        aggregation_type: BUND_AGGREGATION_TYPE,
        generated_at: now,
        full_refresh_at: fullRefreshAt,
        checked_at: now,
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

// ------------------------------------------------------------ Auslieferung

// Ausgeliefert werden nur gerundete Ergebnisse, keine Summen und keine Zahl der Staemme oder
// Gruppen je Kennzahl. Exakte Zaehlwerte machten die Differenz zweier Abrufe zum exakten
// Beitrag einzelner Staemme (S-01, S-12).
export type KennzahlErgebnis = {
    // Durchschnitt je Stamm bzw. je Gruppe, eine Nachkommastelle.
    durchschnitt: number | null;
    // Ganze Zahl.
    median: number | null;
    // Anteil am Feld `gesamt` derselben Verteilung in ganzen Prozent; nur bei Verteilungen.
    anteil?: number | null;
};

export type AggregatErgebnisse = {
    [metric: string]: KennzahlErgebnis | AggregatErgebnisse;
};

export type StufenGruppenErgebnis = {
    gruppen_pro_stamm: KennzahlErgebnis;
    mitglieder: Record<Geschlecht, KennzahlErgebnis>;
    leitende: Record<Geschlecht, KennzahlErgebnis>;
};

const UNTERDRUECKT: KennzahlErgebnis = { durchschnitt: null, median: null };

const rundeEineStelle = (wert: number): number => Math.round(wert * 10) / 10;

// Kennzahlen, zu denen weniger als minStammCount Staemme Werte geliefert haben, werden nicht
// ausgeliefert. Auch bei Gruppen zaehlen verschiedene Staemme, sonst waeren z. B. fuenf
// Meuten eines einzigen Stammes rueckfuehrbar.
const istSichtbar = (wert: MetricAggregate, minStammCount: number): boolean =>
    wert.stamm_count >= minStammCount && wert.sum != null && wert.median != null;

const ergebnis = (
    wert: MetricAggregate,
    anzahl: number,
    minStammCount: number,
    gesamt: MetricAggregate | null,
): KennzahlErgebnis => {
    const sichtbar = istSichtbar(wert, minStammCount) && anzahl > 0;
    const basis = gesamt == null ? null : {
        anteil: sichtbar && istSichtbar(gesamt, minStammCount) && (gesamt.sum ?? 0) > 0
            ? Math.round(((wert.sum ?? 0) / (gesamt.sum ?? 1)) * 100)
            : null,
    };

    return {
        ...(sichtbar
            ? { durchschnitt: rundeEineStelle((wert.sum ?? 0) / anzahl), median: Math.round(wert.median ?? 0) }
            : UNTERDRUECKT),
        ...basis,
    };
};

// Verteilungen erkennt man am Feld `gesamt`: Alle anderen Felder bekommen einen Anteil daran.
export const formatAggregatedMetrics = (metrics: AggregatedMetrics, minStammCount: number): AggregatErgebnisse => {
    const gesamt = metrics.gesamt != null && isMetricAggregate(metrics.gesamt) ? metrics.gesamt : null;
    const result: AggregatErgebnisse = {};

    for (const [key, value] of Object.entries(metrics)) {
        result[key] = isMetricAggregate(value)
            ? ergebnis(value, value.stamm_count, minStammCount, key === 'gesamt' ? null : gesamt)
            : formatAggregatedMetrics(value, minStammCount);
    }

    return result;
};

export const formatGruppenJeStufe = (
    gruppenJeStufe: GruppenJeStufe,
    minStammCount: number,
): Record<Stufe, StufenGruppenErgebnis> => {
    const result = {} as Record<Stufe, StufenGruppenErgebnis>;

    for (const stufe of STUFEN) {
        const aggregat = gruppenJeStufe[stufe];
        const verteilung = (werte: Record<Geschlecht, GruppenMetricAggregate>) =>
            Object.fromEntries(GESCHLECHTER.map((feld) => [
                feld,
                ergebnis(werte[feld], werte[feld].gruppen_count, minStammCount, feld === 'gesamt' ? null : werte.gesamt),
            ])) as Record<Geschlecht, KennzahlErgebnis>;

        result[stufe] = {
            gruppen_pro_stamm: ergebnis(
                aggregat.gruppen_pro_stamm,
                aggregat.gruppen_pro_stamm.stamm_count,
                minStammCount,
                null,
            ),
            mitglieder: verteilung(aggregat.mitglieder),
            leitende: verteilung(aggregat.leitende),
        };
    }

    return result;
};

// Teilnehmende Staemme nur als Bereich "ueber X": X ist das groesste Vielfache von 5 (ueber 50
// von 10), das echt kleiner ist als die Zahl der Staemme.
export const teilnahmeUeber = (staemme: number): number =>
    staemme <= 50 ? Math.floor((staemme - 1) / 5) * 5 : Math.floor((staemme - 1) / 10) * 10;

// Datenstand nur tagesgenau, die App zeigt ohnehin nur das Datum.
export const tagesgenau = (datum: Date): Date =>
    new Date(Date.UTC(datum.getUTCFullYear(), datum.getUTCMonth(), datum.getUTCDate()));
