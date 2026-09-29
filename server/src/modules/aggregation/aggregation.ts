import { subtractUtcMonths, toIsoWeek } from '../../shared/time.js';
import type { EffectiveStateDocument } from '../effectiveState/effectiveState.js';

export const BUND_AGGREGATION_TYPE = 'bund';

// Ein Stamm zaehlt nur, wenn sein neuester gueltiger Snapshot hoechstens so alt ist.
export const MAX_SNAPSHOT_AGE_MONTHS = 2;

export type MetricAggregate = {
    // null nur in ausgelieferten Antworten, wenn die Kennzahl unterdrueckt wurde.
    sum: number | null;
    stamm_count: number;
    median: number | null;
};

export type AggregatedMetrics = {
    [metric: string]: MetricAggregate | AggregatedMetrics;
};

export type WeeklyAggregateDocument = {
    aggregation_week: string;
    aggregation_type: typeof BUND_AGGREGATION_TYPE;
    generated_at: Date;
    participating_stamm_count: number;
    oldest_source_data_as_of: Date | null;
    newest_source_data_as_of: Date | null;
    metrics: AggregatedMetrics | null;
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

// Die Kennzahlen sind durch das Ingest-Schema normalisiert und haben daher bei allen
// Staemmen dieselbe Struktur; die Struktur des ersten Eintrags dient als Vorlage.
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

export const computeBundAggregate = (
    states: EffectiveStateDocument[],
    now: Date,
): WeeklyAggregateDocument => {
    const cutoff = subtractUtcMonths(now, MAX_SNAPSHOT_AGE_MONTHS).getTime();
    const qualifying = states.filter((state) => state.source_data_as_of.getTime() >= cutoff);
    const sourceTimes = qualifying.map((state) => state.source_data_as_of.getTime());
    const metricNodes = qualifying.map((state) => state.metrics as unknown as Record<string, unknown>);
    const template = metricNodes[0];

    return {
        aggregation_week: toIsoWeek(now),
        aggregation_type: BUND_AGGREGATION_TYPE,
        generated_at: now,
        participating_stamm_count: qualifying.length,
        oldest_source_data_as_of: sourceTimes.length > 0 ? new Date(Math.min(...sourceTimes)) : null,
        newest_source_data_as_of: sourceTimes.length > 0 ? new Date(Math.max(...sourceTimes)) : null,
        metrics: template == null ? null : aggregateNode(template, metricNodes),
    };
};

// Kennzahlen, zu denen weniger als minStammCount Staemme Werte geliefert haben, werden
// nicht ausgeliefert, damit einzelne Staemme nicht rueckfuehrbar sind.
export const suppressSmallCounts = (metrics: AggregatedMetrics, minStammCount: number): AggregatedMetrics => {
    const result: AggregatedMetrics = {};

    for (const [key, value] of Object.entries(metrics)) {
        if (isMetricAggregate(value)) {
            result[key] = value.stamm_count >= minStammCount
                ? value
                : { sum: null, stamm_count: value.stamm_count, median: null };
        } else {
            result[key] = suppressSmallCounts(value, minStammCount);
        }
    }

    return result;
};
