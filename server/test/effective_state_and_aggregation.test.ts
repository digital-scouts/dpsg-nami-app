import { describe, expect, test } from 'vitest';

import {
    computeBundAggregate,
    type MetricAggregate,
    suppressSmallCounts,
    suppressSmallGruppenCounts,
} from '../src/modules/aggregation/aggregation.js';
import {
    deriveStammState,
    type EffectiveStateDocument,
    isNewerSnapshot,
    mergeAllStammSnapshots,
    mergeStammSnapshots,
} from '../src/modules/effectiveState/effectiveState.js';
import { buildRawSnapshotDocument, type RawSnapshotDocument } from '../src/modules/stammesSnapshot/persistence.js';
import { buildPseudonym, pseudonymizeStammesSnapshot } from '../src/modules/stammesSnapshot/pseudonymize.js';
import { parseStammesSnapshotPayload } from '../src/modules/stammesSnapshot/schema.js';
import { toIsoWeek } from '../src/shared/time.js';
import { createValidPayload, fremdeGruppe, gruppe } from './support/fixtures.js';

const snapshot = (overrides: Record<string, unknown>): RawSnapshotDocument =>
    buildRawSnapshotDocument(
        pseudonymizeStammesSnapshot(
            parseStammesSnapshotPayload(createValidPayload(overrides), new Date('2026-09-30T00:00:00Z')),
            'test-secret',
        ),
        new Date('2026-09-30T00:00:00Z'),
    );

const gruppenPseudonym = (id: string) => buildPseudonym('gruppe', id, 'test-secret');
const senderPseudonym = (id: string) => buildPseudonym('sender', id, 'test-secret');
const since = new Date('2026-04-01T00:00:00Z');

const merge = (snapshots: RawSnapshotDocument[]): EffectiveStateDocument => {
    const state = mergeStammSnapshots(snapshots, since);
    if (state == null) throw new Error('expected a state');
    return state;
};

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

describe('mergeStammSnapshots', () => {
    const stufeVon = (id: string) => (id === 'D' ? 'pfadfinder' : 'woelflinge');
    const vierGruppen = (werte: Record<string, number>) =>
        ['A', 'B', 'C', 'D'].map((id) => {
            const wert = werte[id];
            return wert === undefined ? fremdeGruppe(id, stufeVon(id)) : gruppe(id, stufeVon(id), wert);
        });

    test('takes each group from the newest snapshot covering it (example P1 to P4)', () => {
        const p4 = snapshot({
            sender_id: 'P4',
            source_data_as_of: '2026-04-10T00:00:00Z',
            gruppen: vierGruppen({ A: 40, B: 40, C: 40, D: 40 }),
            metrics: { leitende: { gesamt: 12 }, stammesvorstand: 2 },
        });
        const p3 = snapshot({ sender_id: 'P3', source_data_as_of: '2026-04-11T00:00:00Z', abdeckung: 'gruppen', gruppen: vierGruppen({ C: 30 }) });
        const p2 = snapshot({ sender_id: 'P2', source_data_as_of: '2026-04-12T00:00:00Z', abdeckung: 'gruppen', gruppen: vierGruppen({ A: 20, B: 20 }) });
        const p1 = snapshot({ sender_id: 'P1', source_data_as_of: '2026-04-13T00:00:00Z', abdeckung: 'gruppen', gruppen: vierGruppen({ A: 10 }) });

        // Die Eingangsreihenfolge spielt keine Rolle.
        const state = merge([p1, p4, p2, p3]);
        const wert = (id: string) => state.gruppen.find((g) => g.gruppe_pseudonym === gruppenPseudonym(id))?.wert;

        expect(wert('A')).toMatchObject({ mitglieder: { gesamt: 10 }, sender_pseudonym: senderPseudonym('P1') });
        expect(wert('B')).toMatchObject({ mitglieder: { gesamt: 20 }, sender_pseudonym: senderPseudonym('P2') });
        expect(wert('C')).toMatchObject({ mitglieder: { gesamt: 30 }, sender_pseudonym: senderPseudonym('P3') });
        expect(wert('D')).toMatchObject({ mitglieder: { gesamt: 40 }, sender_pseudonym: senderPseudonym('P4') });
        expect(state.stammweit).toMatchObject({ sender_pseudonym: senderPseudonym('P4'), metrics: { stammesvorstand: 2 } });
        expect(state.sender_count).toBe(4);
        expect(state.gruppen.map((g) => g.abdeckende_sender)).toEqual([3, 2, 2, 1]);

        const derived = deriveStammState(state, since);
        expect(derived?.art).toBe('gemischt');
        expect(derived?.metrics.woelflinge.gesamt).toBe(60);
        expect(derived?.metrics.pfadfinder.gesamt).toBe(40);
        expect(derived?.metrics.biber.gesamt).toBe(0);
        expect(derived?.metrics.leitende.gesamt).toBe(12);
        expect(derived?.oldest).toEqual(new Date('2026-04-10T00:00:00Z'));
        expect(derived?.newest).toEqual(new Date('2026-04-13T00:00:00Z'));
    });

    test('keeps the full snapshot when a partial snapshot is older', () => {
        const voll = snapshot({ sender_id: 'voll', source_data_as_of: '2026-04-12T00:00:00Z', gruppen: [gruppe('A', 'biber', 8)] });
        const teil = snapshot({ sender_id: 'teil', source_data_as_of: '2026-04-11T00:00:00Z', abdeckung: 'gruppen', gruppen: [gruppe('A', 'biber', 3)] });

        const derived = deriveStammState(merge([voll, teil]), since);

        expect(derived?.art).toBe('vollstaendig');
        expect(derived?.metrics.biber.gesamt).toBe(8);
    });

    test('leaves a stufe unknown while one of its groups has no value', () => {
        const teil = snapshot({
            abdeckung: 'gruppen',
            gruppen: [gruppe('A', 'woelflinge', 12), fremdeGruppe('B', 'woelflinge'), gruppe('C', 'rover', 6)],
        });

        const derived = deriveStammState(merge([teil]), since);

        expect(derived?.art).toBe('nur_gruppen');
        expect(derived?.metrics.woelflinge).toEqual({ gesamt: null, maennlich: null, weiblich: null, divers: null, geschlecht_unbekannt: null });
        expect(derived?.metrics.rover.gesamt).toBe(6);
        expect(derived?.metrics.leitende.gesamt).toBeNull();
        expect(derived?.unvollstaendige_stufen).toBe(1);
        expect(derived?.gruppen).toHaveLength(2);
    });

    test('takes the group structure from the newest snapshot', () => {
        const alt = snapshot({ sender_id: 'a', source_data_as_of: '2026-04-10T00:00:00Z', gruppen: [gruppe('A', 'biber', 4), gruppe('X', 'biber', 2)] });
        const neu = snapshot({ sender_id: 'b', source_data_as_of: '2026-04-11T00:00:00Z', abdeckung: 'gruppen', gruppen: [gruppe('A', 'biber', 5)] });

        const state = merge([alt, neu]);

        expect(state.gruppen.map((g) => g.gruppe_pseudonym)).toEqual([gruppenPseudonym('A')]);
        expect(deriveStammState(state, since)?.metrics.biber.gesamt).toBe(5);
    });

    test('ignores snapshots outside the window', () => {
        const alt = snapshot({ source_data_as_of: '2026-03-31T23:59:59Z' });

        expect(mergeStammSnapshots([alt], since)).toBeNull();
    });

    test('drops parts that left the window by the time of aggregation', () => {
        const voll = snapshot({ sender_id: 'voll', source_data_as_of: '2026-04-01T00:00:00Z', gruppen: [gruppe('A', 'biber', 8), gruppe('B', 'rover', 4)] });
        const teil = snapshot({ sender_id: 'teil', source_data_as_of: '2026-05-20T00:00:00Z', abdeckung: 'gruppen', gruppen: [gruppe('A', 'biber', 3), fremdeGruppe('B', 'rover')] });
        const state = merge([voll, teil]);

        const spaeter = deriveStammState(state, new Date('2026-04-15T00:00:00Z'));

        expect(spaeter?.art).toBe('nur_gruppen');
        expect(spaeter?.metrics.biber.gesamt).toBe(3);
        expect(spaeter?.metrics.rover.gesamt).toBeNull();
        expect(spaeter?.metrics.leitende.gesamt).toBeNull();
    });

    test('groups snapshots by stamm', () => {
        const states = mergeAllStammSnapshots([
            snapshot({ stamm_id: 's1' }),
            snapshot({ stamm_id: 's2' }),
            snapshot({ stamm_id: 's1', sender_id: 'other', source_data_as_of: '2026-04-09T19:00:00Z' }),
        ], since);

        expect(states).toHaveLength(2);
    });
});

describe('computeBundAggregate', () => {
    const now = new Date('2026-06-10T12:00:00Z');
    const window = new Date('2026-04-10T12:00:00Z');
    const states = (snapshots: RawSnapshotDocument[]) => mergeAllStammSnapshots(snapshots, window);

    test('aggregates sum, count and median per metric and skips null values', () => {
        const aggregate = computeBundAggregate(states([
            snapshot({ stamm_id: 's1', source_data_as_of: '2026-06-01T00:00:00Z', gruppen: [gruppe('a', 'biber', 4), gruppe('b', 'woelflinge', 10)] }),
            snapshot({ stamm_id: 's2', source_data_as_of: '2026-06-02T00:00:00Z', gruppen: [gruppe('c', 'biber', 8), fremdeGruppe('d', 'woelflinge')], abdeckung: 'gruppen' }),
            snapshot({ stamm_id: 's3', source_data_as_of: '2026-06-03T00:00:00Z', gruppen: [gruppe('e', 'biber', 1)] }),
        ]), now);
        const biber = aggregate.metrics?.biber as Record<string, MetricAggregate>;
        const woelflinge = aggregate.metrics?.woelflinge as Record<string, MetricAggregate>;

        expect(aggregate.aggregation_type).toBe('bund');
        expect(aggregate.aggregation_week).toBe('2026-W24');
        expect(aggregate.participating_stamm_count).toBe(3);
        expect(aggregate.oldest_source_data_as_of).toEqual(new Date('2026-06-01T00:00:00Z'));
        expect(aggregate.newest_source_data_as_of).toEqual(new Date('2026-06-03T00:00:00Z'));
        expect(biber.gesamt).toEqual({ sum: 13, stamm_count: 3, median: 4 });
        // s2 kennt seine Meute nicht, s3 hat keine (0).
        expect(woelflinge.gesamt).toEqual({ sum: 10, stamm_count: 2, median: 5 });
        expect(woelflinge.maennlich).toEqual({ sum: 0, stamm_count: 1, median: 0 });
    });

    test('averages the two middle values for an even median', () => {
        const aggregate = computeBundAggregate(states([2, 4, 6, 100].map((wert, index) =>
            snapshot({ stamm_id: `s${index}`, source_data_as_of: '2026-06-01T00:00:00Z', gruppen: [gruppe(`g${index}`, 'biber', wert)] }))), now);

        expect((aggregate.metrics?.biber as Record<string, MetricAggregate>).gesamt?.median).toBe(5);
    });

    test('excludes stamms whose snapshots are older than two months', () => {
        const merged = mergeAllStammSnapshots([
            snapshot({ stamm_id: 'fresh', source_data_as_of: '2026-04-10T12:00:00Z' }),
            snapshot({ stamm_id: 'stale', source_data_as_of: '2026-04-10T11:59:59Z' }),
        ], new Date('2026-04-01T00:00:00Z'));

        expect(computeBundAggregate(merged, now).participating_stamm_count).toBe(1);
    });

    test('aggregates group sizes per stufe and counts stamms separately', () => {
        const aggregate = computeBundAggregate(states([
            snapshot({ stamm_id: 's1', source_data_as_of: '2026-06-01T00:00:00Z', gruppen: [gruppe('m1', 'woelflinge', 10, 2), gruppe('m2', 'woelflinge', 14, 3)] }),
            snapshot({ stamm_id: 's2', source_data_as_of: '2026-06-01T00:00:00Z', gruppen: [gruppe('m3', 'woelflinge', 9, 1)] }),
        ]), now);

        expect(aggregate.gruppen_je_stufe?.woelflinge).toMatchObject({
            gruppen_count: 3,
            stamm_count: 2,
            gruppen_pro_stamm: { sum: 3, stamm_count: 2, median: 1.5 },
            mitglieder: { gesamt: { sum: 33, stamm_count: 2, gruppen_count: 3, median: 10 } },
            leitende: { gesamt: { sum: 6, stamm_count: 2, gruppen_count: 3, median: 2 } },
        });
        expect(aggregate.gruppen_je_stufe?.biber.gruppen_count).toBe(0);
    });

    test('produces an empty aggregate without qualifying stamms', () => {
        const aggregate = computeBundAggregate([], now);

        expect(aggregate.participating_stamm_count).toBe(0);
        expect(aggregate.metrics).toBeNull();
        expect(aggregate.gruppen_je_stufe).toBeNull();
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

    test('suppresses group sizes by the number of stamms, not groups', () => {
        // Sechs Meuten aus einem einzigen Stamm duerfen nicht ausgeliefert werden.
        const aggregate = computeBundAggregate(mergeAllStammSnapshots([
            snapshot({
                stamm_id: 'gross',
                source_data_as_of: '2026-06-01T00:00:00Z',
                gruppen: [1, 2, 3, 4, 5, 6].map((i) => gruppe(`m${i}`, 'woelflinge', 10 + i)),
            }),
        ], new Date('2026-04-10T12:00:00Z')), new Date('2026-06-10T12:00:00Z'));

        const suppressed = suppressSmallGruppenCounts(aggregate.gruppen_je_stufe!, 5);

        expect(suppressed.woelflinge.mitglieder.gesamt).toEqual({ sum: null, stamm_count: 1, gruppen_count: 6, median: null });
        expect(suppressed.woelflinge.gruppen_pro_stamm).toEqual({ sum: null, stamm_count: 1, median: null });
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
