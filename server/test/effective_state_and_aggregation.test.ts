import { describe, expect, test } from 'vitest';

import {
    computeBundAggregate,
    formatAggregatedMetrics,
    formatGruppenJeStufe,
    type MetricAggregate,
    tagesgenau,
    teilnahmeUntergrenze,
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

const HOUR_MS = 60 * 60 * 1000;

// Snapshot mit Eingang beim Server; der Datenstand liegt eine Stunde davor.
const snapshot = (
    overrides: Record<string, unknown>,
    eingang = '2026-04-10T00:00:00Z',
    kenntSeit: string | null = null,
): RawSnapshotDocument => {
    const receivedAt = new Date(eingang);
    return buildRawSnapshotDocument(
        pseudonymizeStammesSnapshot(
            parseStammesSnapshotPayload(
                createValidPayload({ source_data_as_of: new Date(receivedAt.getTime() - HOUR_MS).toISOString(), ...overrides }),
                receivedAt,
            ),
            'test-secret',
        ),
        receivedAt,
        kenntSeit == null ? null : new Date(kenntSeit),
    );
};

const gruppenPseudonym = (id: string) => buildPseudonym('gruppe', id, 'test-secret');
const senderPseudonym = (id: string) => buildPseudonym('sender', id, 'test-secret');
const since = new Date('2026-04-01T00:00:00Z');
// Alle Snapshots der Beispiele liegen ausserhalb der Haltefrist, sofern nicht anders gesetzt.
const spaeter = new Date('2026-05-20T00:00:00Z');

const merge = (snapshots: RawSnapshotDocument[], now: Date = spaeter): EffectiveStateDocument => {
    const state = mergeStammSnapshots(snapshots, since, now);
    if (state == null) throw new Error('expected a state');
    return state;
};

const wertVon = (state: EffectiveStateDocument, id: string) =>
    state.gruppen.find((g) => g.gruppe_pseudonym === gruppenPseudonym(id))?.wert;

describe('isNewerSnapshot', () => {
    test('decides by the time the server received the snapshot, not by client timestamps', () => {
        const older = snapshot({ source_data_as_of: '2026-04-09T23:00:00Z' }, '2026-04-10T00:00:00Z');
        const newer = snapshot({ source_data_as_of: '2026-04-09T00:00:00Z' }, '2026-04-11T00:00:00Z');

        expect(isNewerSnapshot(newer, older)).toBe(true);
        expect(isNewerSnapshot(older, newer)).toBe(false);
        expect(isNewerSnapshot(older, older)).toBe(false);
    });
});

describe('mergeStammSnapshots', () => {
    const stufeVon = (id: string) => (id === 'D' ? 'pfadfinder' : 'woelflinge');
    const vierGruppen = (werte: Record<string, number>) =>
        ['A', 'B', 'C', 'D'].map((id) => {
            const wert = werte[id];
            return wert === undefined ? fremdeGruppe(id, stufeVon(id)) : gruppe(id, stufeVon(id), wert);
        });

    test('takes each group from the newest snapshot covering it when nobody is active (example P1 to P4)', () => {
        const p4 = snapshot({
            sender_id: 'P4',
            gruppen: vierGruppen({ A: 40, B: 40, C: 40, D: 40 }),
            metrics: { leitende: { gesamt: 12 }, stammesvorstand: 2 },
        }, '2026-04-10T00:00:00Z');
        const p3 = snapshot({ sender_id: 'P3', abdeckung: 'gruppen', gruppen: vierGruppen({ C: 30 }) }, '2026-04-11T00:00:00Z');
        const p2 = snapshot({ sender_id: 'P2', abdeckung: 'gruppen', gruppen: vierGruppen({ A: 20, B: 20 }) }, '2026-04-12T00:00:00Z');
        const p1 = snapshot({ sender_id: 'P1', abdeckung: 'gruppen', gruppen: vierGruppen({ A: 10 }) }, '2026-04-13T00:00:00Z');

        // Die Eingangsreihenfolge spielt keine Rolle.
        const state = merge([p1, p4, p2, p3]);

        expect(wertVon(state, 'A')).toMatchObject({ mitglieder: { gesamt: 10 }, sender_pseudonym: senderPseudonym('P1') });
        expect(wertVon(state, 'B')).toMatchObject({ mitglieder: { gesamt: 20 }, sender_pseudonym: senderPseudonym('P2') });
        expect(wertVon(state, 'C')).toMatchObject({ mitglieder: { gesamt: 30 }, sender_pseudonym: senderPseudonym('P3') });
        expect(wertVon(state, 'D')).toMatchObject({ mitglieder: { gesamt: 40 }, sender_pseudonym: senderPseudonym('P4') });
        expect(state.stammweit).toMatchObject({ sender_pseudonym: senderPseudonym('P4'), metrics: { stammesvorstand: 2 } });
        expect(state.sender_count).toBe(4);
        expect(state.gruppen.map((g) => g.abdeckende_sender)).toEqual([3, 2, 2, 1]);

        const derived = deriveStammState(state, since);
        expect(derived?.art).toBe('gemischt');
        // Stufensummen stammen aus der einzigen Installation, die alle Gruppen der Stufe abdeckt.
        expect(derived?.metrics.woelflinge.gesamt).toBe(120);
        expect(derived?.metrics.pfadfinder.gesamt).toBe(40);
        // Ohne Biber-Gruppe bleibt die Stufe unbekannt und zaehlt nicht als liefernder Stamm (S-13).
        expect(derived?.metrics.biber.gesamt).toBeNull();
        expect(derived?.metrics.leitende.gesamt).toBe(12);
        expect(derived?.oldest).toEqual(new Date('2026-04-10T00:00:00Z'));
        expect(derived?.newest).toEqual(new Date('2026-04-13T00:00:00Z'));
    });

    test('keeps an active stamm from being overwritten by a foreign installation (S-01)', () => {
        const echt = snapshot({ sender_id: 'echt', gruppen: [gruppe('A', 'biber', 8)], metrics: { kuraten: 1 } }, '2026-05-17T00:00:00Z', '2026-03-01T00:00:00Z');
        const fremd = snapshot({
            sender_id: 'fremd',
            dv_id: 'dv-fremd',
            // Vordatiert: zaehlt nicht, entscheidend ist der Eingang.
            source_data_as_of: '2026-05-20T23:00:00Z',
            gruppen: [gruppe('A', 'biber', 99), gruppe('X', 'rover', 99)],
            metrics: { kuraten: 9 },
        }, '2026-05-19T23:00:00Z');

        const state = merge([echt, fremd]);

        expect(state.dv_id).toBe('dv-1');
        expect(state.gruppen.map((g) => g.gruppe_pseudonym)).toEqual([gruppenPseudonym('A')]);
        expect(wertVon(state, 'A')).toMatchObject({ mitglieder: { gesamt: 8 }, sender_pseudonym: senderPseudonym('echt') });
        expect(state.stammweit?.metrics.kuraten).toBe(1);
    });

    test('holds back newer values until the holder has been inactive for the holding period', () => {
        const echt = snapshot({ sender_id: 'echt', gruppen: [gruppe('A', 'biber', 8)] }, '2026-05-05T00:00:00Z', '2026-03-01T00:00:00Z');
        const neu = snapshot({ sender_id: 'neu', gruppen: [gruppe('A', 'biber', 6)] }, '2026-05-15T00:00:00Z');

        expect(wertVon(merge([echt, neu], new Date('2026-05-18T23:59:59Z')), 'A')?.mitglieder.gesamt).toBe(8);
        expect(wertVon(merge([echt, neu], new Date('2026-05-19T00:00:01Z')), 'A')?.mitglieder.gesamt).toBe(6);
    });

    test('gives a returning installation its precedence back', () => {
        const echt = snapshot({ sender_id: 'echt', gruppen: [gruppe('A', 'biber', 8)] }, '2026-04-20T00:00:00Z', '2026-03-01T00:00:00Z');
        const fremd = snapshot({ sender_id: 'fremd', gruppen: [gruppe('A', 'biber', 99)] }, '2026-05-18T00:00:00Z');
        const zurueck = snapshot({ sender_id: 'echt', gruppen: [gruppe('A', 'biber', 9)] }, '2026-05-19T00:00:00Z', '2026-03-01T00:00:00Z');

        expect(wertVon(merge([echt, fremd]), 'A')?.mitglieder.gesamt).toBe(99);
        expect(wertVon(merge([echt, fremd, zurueck]), 'A')?.mitglieder.gesamt).toBe(9);
    });

    test('lets a longer known group leader keep a group against a newer full report', () => {
        const leitung = snapshot({ sender_id: 'G', abdeckung: 'gruppen', gruppen: vierGruppen({ A: 10 }) }, '2026-05-15T00:00:00Z', '2026-03-01T00:00:00Z');
        const vorstand = snapshot({ sender_id: 'V', gruppen: vierGruppen({ A: 11, B: 20, C: 30, D: 40 }) }, '2026-05-19T00:00:00Z', '2026-05-01T00:00:00Z');

        const state = merge([leitung, vorstand]);

        expect(wertVon(state, 'A')).toMatchObject({ mitglieder: { gesamt: 10 }, sender_pseudonym: senderPseudonym('G') });
        expect(wertVon(state, 'B')?.sender_pseudonym).toBe(senderPseudonym('V'));
        expect(state.stufen.find((stufe) => stufe.stufe === 'woelflinge')?.wert?.sender_pseudonym).toBe(senderPseudonym('V'));
        expect(deriveStammState(state, since)?.metrics.woelflinge.gesamt).toBe(61);
    });

    test('never mixes installations within a stufe sum', () => {
        // Die echte Gruppenleitung deckt nur A ab. Wer B dazuerfindet, darf A nicht in eine
        // Stufensumme ziehen, sonst liesse sich A aus der Summe herausrechnen.
        const leitung = snapshot({ sender_id: 'G', abdeckung: 'gruppen', gruppen: [gruppe('A', 'woelflinge', 10), fremdeGruppe('B', 'woelflinge')] }, '2026-05-15T00:00:00Z', '2026-03-01T00:00:00Z');
        const fremd = snapshot({ sender_id: 'X', abdeckung: 'gruppen', gruppen: [gruppe('A', 'woelflinge', 50), gruppe('B', 'woelflinge', 7)] }, '2026-05-19T00:00:00Z');

        const state = merge([leitung, fremd]);
        const derived = deriveStammState(state, since);

        expect(wertVon(state, 'A')?.mitglieder.gesamt).toBe(10);
        expect(wertVon(state, 'B')?.mitglieder.gesamt).toBe(7);
        expect(derived?.metrics.woelflinge.gesamt).toBe(57);
    });

    test('leaves a stufe unknown while no installation covers all of its groups', () => {
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

    test('takes the group structure from the newest snapshot when nobody is active', () => {
        const alt = snapshot({ sender_id: 'a', gruppen: [gruppe('A', 'biber', 4), gruppe('X', 'biber', 2)] }, '2026-04-10T00:00:00Z');
        const neu = snapshot({ sender_id: 'b', abdeckung: 'gruppen', gruppen: [gruppe('A', 'biber', 5)] }, '2026-04-11T00:00:00Z');

        const state = merge([alt, neu]);

        expect(state.gruppen.map((g) => g.gruppe_pseudonym)).toEqual([gruppenPseudonym('A')]);
        expect(deriveStammState(state, since)?.metrics.biber.gesamt).toBe(5);
    });

    test('ignores snapshots received before the window', () => {
        const alt = snapshot({}, '2026-03-31T23:59:59Z');

        expect(mergeStammSnapshots([alt], since, spaeter)).toBeNull();
    });

    test('drops parts that left the window by the time of aggregation', () => {
        const voll = snapshot({ sender_id: 'voll', gruppen: [gruppe('A', 'biber', 8), gruppe('B', 'rover', 4)] }, '2026-04-01T00:00:00Z');
        const teil = snapshot({ sender_id: 'teil', abdeckung: 'gruppen', gruppen: [gruppe('A', 'biber', 13), fremdeGruppe('B', 'rover')] }, '2026-05-20T00:00:00Z');
        const state = merge([voll, teil], new Date('2026-06-10T00:00:00Z'));

        const danach = deriveStammState(state, new Date('2026-04-15T00:00:00Z'));

        expect(danach?.art).toBe('nur_gruppen');
        expect(danach?.metrics.biber.gesamt).toBe(13);
        expect(danach?.metrics.rover.gesamt).toBeNull();
        expect(danach?.metrics.leitende.gesamt).toBeNull();
    });

    test('groups snapshots by stamm', () => {
        const states = mergeAllStammSnapshots([
            snapshot({ stamm_id: 's1' }),
            snapshot({ stamm_id: 's2' }),
            snapshot({ stamm_id: 's1', sender_id: 'other' }, '2026-04-10T01:00:00Z'),
        ], since, spaeter);

        expect(states).toHaveLength(2);
    });
});

describe('computeBundAggregate', () => {
    const now = new Date('2026-06-10T12:00:00Z');
    const window = new Date('2026-04-10T12:00:00Z');
    const states = (snapshots: RawSnapshotDocument[]) => mergeAllStammSnapshots(snapshots, window, now);

    test('aggregates sum, count and median per metric and skips null values', () => {
        const aggregate = computeBundAggregate(states([
            snapshot({ stamm_id: 's1', gruppen: [gruppe('a', 'biber', 4), gruppe('b', 'woelflinge', 10)] }, '2026-06-01T00:00:00Z'),
            snapshot({ stamm_id: 's2', gruppen: [gruppe('c', 'biber', 8), fremdeGruppe('d', 'woelflinge')], abdeckung: 'gruppen' }, '2026-06-02T00:00:00Z'),
            snapshot({ stamm_id: 's3', gruppen: [gruppe('e', 'biber', 6)] }, '2026-06-03T00:00:00Z'),
        ]), now);
        const biber = aggregate.metrics?.biber as Record<string, MetricAggregate>;
        const woelflinge = aggregate.metrics?.woelflinge as Record<string, MetricAggregate>;

        expect(aggregate.aggregation_type).toBe('bund');
        expect(aggregate.aggregation_week).toBe('2026-W24');
        expect(aggregate.participating_stamm_count).toBe(3);
        expect(aggregate.oldest_data_as_of).toEqual(new Date('2026-06-01T00:00:00Z'));
        expect(aggregate.newest_data_as_of).toEqual(new Date('2026-06-03T00:00:00Z'));
        expect(biber.gesamt).toEqual({ sum: 18, stamm_count: 3, median: 6 });
        // s2 kennt seine Meute nicht, s3 hat keine: Beide zaehlen fuer die Woelflinge nicht.
        expect(woelflinge.gesamt).toEqual({ sum: 10, stamm_count: 1, median: 10 });
        expect(woelflinge.maennlich).toEqual({ sum: 0, stamm_count: 0, median: null });
    });

    test('averages the two middle values for an even median', () => {
        const aggregate = computeBundAggregate(states([6, 8, 10, 100].map((wert, index) =>
            snapshot({ stamm_id: `s${index}`, gruppen: [gruppe(`g${index}`, 'biber', wert)] }, '2026-06-01T00:00:00Z'))), now);

        expect((aggregate.metrics?.biber as Record<string, MetricAggregate>).gesamt?.median).toBe(9);
    });

    test('excludes stamms whose snapshots are older than two months', () => {
        const merged = mergeAllStammSnapshots([
            snapshot({ stamm_id: 'fresh' }, '2026-04-10T12:00:00Z'),
            snapshot({ stamm_id: 'stale' }, '2026-04-10T11:59:59Z'),
        ], new Date('2026-04-01T00:00:00Z'), now);

        expect(computeBundAggregate(merged, now).participating_stamm_count).toBe(1);
    });

    test('aggregates group sizes per stufe and counts stamms separately', () => {
        const aggregate = computeBundAggregate(states([
            snapshot({ stamm_id: 's1', gruppen: [gruppe('m1', 'woelflinge', 10, 2), gruppe('m2', 'woelflinge', 14, 3)] }, '2026-06-01T00:00:00Z'),
            snapshot({ stamm_id: 's2', gruppen: [gruppe('m3', 'woelflinge', 9, 1)] }, '2026-06-01T00:00:00Z'),
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
        expect(aggregate.oldest_data_as_of).toBeNull();
    });
});

describe('Mindestgroessen', () => {
    const now = new Date('2026-06-10T12:00:00Z');
    const window = new Date('2026-04-10T12:00:00Z');
    const derive = (overrides: Record<string, unknown>) => {
        const [state] = mergeAllStammSnapshots([snapshot(overrides, '2026-06-01T00:00:00Z')], window, now);
        return state == null ? null : deriveStammState(state, window);
    };

    test('ignores groups with at most two members everywhere', () => {
        const derived = derive({
            gruppen: [gruppe('m1', 'woelflinge', 12), gruppe('m2', 'woelflinge', 2), gruppe('r1', 'rover', 1)],
        });

        expect(derived?.gruppen.map((g) => g.gruppe_pseudonym)).toEqual([gruppenPseudonym('m1')]);
        expect(derived?.gruppen_je_stufe).toMatchObject({ woelflinge: 1, rover: 0 });
        expect(derived?.metrics.woelflinge.gesamt).toBe(12);
        // Eine Stufe nur mit inaktiven Gruppen bleibt unbekannt.
        expect(derived?.metrics.rover.gesamt).toBeNull();
        expect(derived?.metrics.alle_stufen.gesamt).toBe(12);
    });

    test('treats a stamm with fewer than five members as group values only', () => {
        const derived = derive({
            gruppen: [gruppe('r1', 'rover', 4)],
            metrics: { aktive_mitglieder: { gesamt: 4 }, kuraten: 1 },
        });

        expect(derived?.gruppen).toHaveLength(1);
        expect(derived?.art).toBe('nur_gruppen');
        expect(derived?.metrics.kuraten).toBeNull();
        expect(derived?.metrics.rover.gesamt).toBeNull();
        expect(derived?.metrics.alle_stufen.gesamt).toBeNull();
    });

    test('drops a stamm without any counted value', () => {
        expect(derive({ gruppen: [gruppe('r1', 'rover', 2)] })).toBeNull();
    });

    test('suppresses a stufe that only a single stamm has (S-13)', () => {
        const staemme = [1, 2, 3, 4, 5].map((nummer) => snapshot({
            stamm_id: `s${nummer}`,
            gruppen: nummer === 1
                ? [gruppe('b1', 'biber', 4, 1, { mitglieder: { gesamt: 4, divers: 1 } }), gruppe(`w${nummer}`, 'woelflinge', 12)]
                : [gruppe(`w${nummer}`, 'woelflinge', 12)],
        }, '2026-06-01T00:00:00Z'));
        const aggregate = computeBundAggregate(mergeAllStammSnapshots(staemme, window, now), now);
        const metrics = formatAggregatedMetrics(aggregate.metrics!, 5) as Record<string, Record<string, unknown>>;

        expect(metrics.biber?.gesamt).toEqual({ durchschnitt: null, median: null });
        expect(metrics.biber?.divers).toEqual({ durchschnitt: null, median: null, anteil: null });
        expect(metrics.woelflinge?.gesamt).toEqual({ durchschnitt: 12, median: 12 });
    });
});

describe('Auslieferung', () => {
    test('delivers rounded averages, medians and shares without sums or counts', () => {
        const metrics = formatAggregatedMetrics({
            biber: {
                gesamt: { sum: 37, stamm_count: 6, median: 6.5 },
                weiblich: { sum: 17, stamm_count: 6, median: 3 },
                divers: { sum: 1, stamm_count: 4, median: 0 },
            },
            kuraten: { sum: 7, stamm_count: 6, median: 1 },
        }, 5);

        expect(metrics).toEqual({
            biber: {
                gesamt: { durchschnitt: 6.2, median: 7 },
                weiblich: { durchschnitt: 2.8, median: 3, anteil: 46 },
                divers: { durchschnitt: null, median: null, anteil: null },
            },
            kuraten: { durchschnitt: 1.2, median: 1 },
        });
        expect(JSON.stringify(metrics)).not.toMatch(/sum|stamm_count/);
    });

    test('suppresses group sizes by the number of stamms, not groups', () => {
        // Sechs Meuten aus einem einzigen Stamm duerfen nicht ausgeliefert werden.
        const aggregate = computeBundAggregate(mergeAllStammSnapshots([
            snapshot({
                stamm_id: 'gross',
                gruppen: [1, 2, 3, 4, 5, 6].map((i) => gruppe(`m${i}`, 'woelflinge', 10 + i)),
            }, '2026-06-01T00:00:00Z'),
        ], new Date('2026-04-10T12:00:00Z'), new Date('2026-06-10T12:00:00Z')), new Date('2026-06-10T12:00:00Z'));

        const formatted = formatGruppenJeStufe(aggregate.gruppen_je_stufe!, 5);

        expect(formatted.woelflinge).toEqual({
            gruppen_pro_stamm: { durchschnitt: null, median: null },
            mitglieder: expect.objectContaining({ gesamt: { durchschnitt: null, median: null } }),
            leitende: expect.objectContaining({ maennlich: { durchschnitt: null, median: null, anteil: null } }),
        });
        expect(JSON.stringify(formatted)).not.toMatch(/count|sum/);
    });

    test('averages group values per group', () => {
        const aggregate = computeBundAggregate(mergeAllStammSnapshots([1, 2, 3, 4, 5].map((nummer) => snapshot({
            stamm_id: `s${nummer}`,
            gruppen: [gruppe(`a${nummer}`, 'woelflinge', 10), gruppe(`b${nummer}`, 'woelflinge', 15)],
        }, '2026-06-01T00:00:00Z')), new Date('2026-04-10T12:00:00Z'), new Date('2026-06-10T12:00:00Z')), new Date('2026-06-10T12:00:00Z'));

        const formatted = formatGruppenJeStufe(aggregate.gruppen_je_stufe!, 5);

        expect(formatted.woelflinge.mitglieder.gesamt).toEqual({ durchschnitt: 12.5, median: 13 });
        expect(formatted.woelflinge.gruppen_pro_stamm).toEqual({ durchschnitt: 2, median: 2 });
    });

    test.each([
        [5, 5], [7, 5], [47, 45], [49, 45], [50, 50], [59, 50], [123, 120],
    ])('reports %i participating stamms as at least %i', (staemme, untergrenze) => {
        expect(teilnahmeUntergrenze(staemme)).toBe(untergrenze);
    });

    test('reduces data timestamps to the day', () => {
        expect(tagesgenau(new Date('2026-06-10T13:45:12.345Z'))).toEqual(new Date('2026-06-10T00:00:00Z'));
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
