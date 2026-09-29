import { describe, expect, test } from 'vitest';

import {
    computeBundAggregate,
    type MetricAggregate,
    suppressSmallCounts,
} from '../src/modules/aggregation/aggregation.js';
import {
    isNewerSnapshot,
    selectEffectiveSnapshots,
} from '../src/modules/effectiveState/effectiveState.js';
import { buildRawSnapshotDocument, type RawSnapshotDocument } from '../src/modules/stammesSnapshot/persistence.js';
import { pseudonymizeStammesSnapshot } from '../src/modules/stammesSnapshot/pseudonymize.js';
import { parseStammesSnapshotPayload } from '../src/modules/stammesSnapshot/schema.js';
import { toIsoWeek } from '../src/shared/time.js';
import { createValidPayload } from './support/fixtures.js';

const snapshot = (overrides: Record<string, unknown>): RawSnapshotDocument =>
    buildRawSnapshotDocument(
        pseudonymizeStammesSnapshot(
            parseStammesSnapshotPayload(createValidPayload(overrides), new Date('2026-09-30T00:00:00Z')),
            'test-secret',
        ),
        new Date('2026-09-30T00:00:00Z'),
    );

describe('isNewerSnapshot', () => {
    test('uses source_data_as_of as primary criterion', () => {
        const older = snapshot({ source_data_as_of: '2026-04-01T00:00:00Z', sent_at: '2026-04-20T00:00:00Z' });
        const newer = snapshot({ source_data_as_of: '2026-04-02T00:00:00Z', sent_at: '2026-04-03T00:00:00Z' });

        expect(isNewerSnapshot(newer, older)).toBe(true);
        expect(isNewerSnapshot(older, newer)).toBe(false);
    });

    test('uses sent_at only as tie breaker', () => {
        const first = snapshot({ source_data_as_of: '2026-04-01T00:00:00Z', sent_at: '2026-04-02T00:00:00Z' });
        const second = snapshot({ source_data_as_of: '2026-04-01T00:00:00Z', sent_at: '2026-04-03T00:00:00Z' });

        expect(isNewerSnapshot(second, first)).toBe(true);
        expect(isNewerSnapshot(first, first)).toBe(false);
    });
});

describe('selectEffectiveSnapshots', () => {
    test('keeps exactly one snapshot per stamm regardless of arrival order', () => {
        const newest = snapshot({ stamm_id: 's1', source_data_as_of: '2026-04-05T00:00:00Z', sent_at: '2026-04-05T00:00:00Z' });
        const oldest = snapshot({ stamm_id: 's1', source_data_as_of: '2026-04-01T00:00:00Z', sent_at: '2026-04-09T00:00:00Z' });
        const other = snapshot({ stamm_id: 's2' });

        const selected = selectEffectiveSnapshots([newest, oldest, other]);

        expect(selected).toHaveLength(2);
        expect(selected).toContain(newest);
        expect(selected).toContain(other);
    });
});

describe('computeBundAggregate', () => {
    const now = new Date('2026-06-10T12:00:00Z');

    test('aggregates sum, count and median per metric and skips null values', () => {
        const states = [
            snapshot({ stamm_id: 's1', source_data_as_of: '2026-06-01T00:00:00Z', metrics: { biber: { gesamt: 4 }, woelflinge: { gesamt: 10 } } }),
            snapshot({ stamm_id: 's2', source_data_as_of: '2026-06-02T00:00:00Z', metrics: { biber: { gesamt: 8 } } }),
            snapshot({ stamm_id: 's3', source_data_as_of: '2026-06-03T00:00:00Z', metrics: { biber: { gesamt: 1 } } }),
        ];

        const aggregate = computeBundAggregate(states, now);
        const biber = aggregate.metrics?.biber as Record<string, MetricAggregate>;
        const woelflinge = aggregate.metrics?.woelflinge as Record<string, MetricAggregate>;

        expect(aggregate.aggregation_type).toBe('bund');
        expect(aggregate.aggregation_week).toBe('2026-W24');
        expect(aggregate.participating_stamm_count).toBe(3);
        expect(aggregate.oldest_source_data_as_of).toEqual(new Date('2026-06-01T00:00:00Z'));
        expect(aggregate.newest_source_data_as_of).toEqual(new Date('2026-06-03T00:00:00Z'));
        expect(biber.gesamt).toEqual({ sum: 13, stamm_count: 3, median: 4 });
        expect(woelflinge.gesamt).toEqual({ sum: 10, stamm_count: 1, median: 10 });
        expect(woelflinge.maennlich).toEqual({ sum: 0, stamm_count: 0, median: null });
    });

    test('averages the two middle values for an even median', () => {
        const states = [2, 4, 6, 100].map((gesamt, index) =>
            snapshot({ stamm_id: `s${index}`, source_data_as_of: '2026-06-01T00:00:00Z', metrics: { biber: { gesamt } } }),
        );

        const biber = computeBundAggregate(states, now).metrics?.biber as Record<string, MetricAggregate>;

        expect(biber.gesamt?.median).toBe(5);
    });

    test('excludes stamms whose newest snapshot is older than two months', () => {
        const states = [
            snapshot({ stamm_id: 'fresh', source_data_as_of: '2026-04-10T12:00:00Z' }),
            snapshot({ stamm_id: 'stale', source_data_as_of: '2026-04-10T11:59:59Z' }),
        ];

        const aggregate = computeBundAggregate(states, now);

        expect(aggregate.participating_stamm_count).toBe(1);
    });

    test('produces an empty aggregate without qualifying stamms', () => {
        const aggregate = computeBundAggregate([], now);

        expect(aggregate.participating_stamm_count).toBe(0);
        expect(aggregate.metrics).toBeNull();
        expect(aggregate.oldest_source_data_as_of).toBeNull();
    });
});

describe('suppressSmallCounts', () => {
    test('hides sum and median of metrics reported by too few stamms', () => {
        const suppressed = suppressSmallCounts({
            biber: {
                gesamt: { sum: 30, stamm_count: 5, median: 6 },
                divers: { sum: 1, stamm_count: 1, median: 1 },
            },
            kuraten: { sum: 2, stamm_count: 2, median: 1 },
        }, 5);

        expect(suppressed).toEqual({
            biber: {
                gesamt: { sum: 30, stamm_count: 5, median: 6 },
                divers: { sum: null, stamm_count: 1, median: null },
            },
            kuraten: { sum: null, stamm_count: 2, median: null },
        });
    });
});

describe('toIsoWeek', () => {
    test.each([
        ['2026-01-01T00:00:00Z', '2026-W01'],
        ['2027-01-01T00:00:00Z', '2026-W53'],
        ['2026-12-28T00:00:00Z', '2026-W53'],
        ['2024-12-30T00:00:00Z', '2025-W01'],
        ['2026-09-29T23:59:59Z', '2026-W40'],
    ])('%s is in %s', (date, expectedWeek) => {
        expect(toIsoWeek(new Date(date))).toBe(expectedWeek);
    });
});
