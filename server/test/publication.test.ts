import { afterAll, beforeAll, describe, expect, test } from 'vitest';

import {
    lastNightlySlot,
    lastWeeklySlot,
    runAggregatePublicationIfDue,
} from '../src/modules/aggregation/refresh.js';
import {
    authHeader,
    buildMemoryTestServer,
    buildTestConfig,
    createMutableClock,
    createValidPayload,
    gruppe,
} from './support/fixtures.js';

describe('publication slots', () => {
    test.each([
        // 2026-06-10 ist ein Mittwoch.
        ['2026-06-10T12:00:00Z', '2026-06-10T03:00:00Z', '2026-06-08T03:00:00Z'],
        ['2026-06-10T02:59:59Z', '2026-06-09T03:00:00Z', '2026-06-08T03:00:00Z'],
        ['2026-06-15T03:00:00Z', '2026-06-15T03:00:00Z', '2026-06-15T03:00:00Z'],
        ['2026-06-15T02:00:00Z', '2026-06-14T03:00:00Z', '2026-06-08T03:00:00Z'],
    ])('at %s the last nightly run was %s and the last weekly run %s', (now, nacht, woche) => {
        expect(lastNightlySlot(new Date(now))).toEqual(new Date(nacht));
        expect(lastWeeklySlot(new Date(now))).toEqual(new Date(woche));
    });
});

describe('runAggregatePublicationIfDue', () => {
    const time = createMutableClock('2026-06-10T12:00:00Z');
    const { server, store, dependencies } = buildMemoryTestServer({
        clock: time.clock,
        config: buildTestConfig({ MIN_STAMM_COUNT_FOR_READ: '1' }),
    });

    const teile = async (stammId: string, biber: number) => {
        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(),
            payload: createValidPayload({
                stamm_id: stammId,
                sender_id: 'install-1',
                source_data_as_of: time.now.toISOString(),
                gruppen: [gruppe('g-biber', 'biber', biber)],
            }),
        });
        expect(response.statusCode).toBe(204);
    };
    const lauf = () => runAggregatePublicationIfDue(dependencies, time.now);
    const aggregat = () => [...store.weeklyAggregates.values()].sort((a, b) => b.generated_at.getTime() - a.generated_at.getTime())[0];
    const biberSumme = () => {
        const biber = aggregat()?.metrics?.biber as Record<string, { sum: number | null }> | undefined;
        return biber?.gesamt?.sum;
    };

    beforeAll(async () => {
        await server.ready();
    });

    afterAll(async () => {
        await server.close();
    });

    test('publishes weekly, adds only new stamms at night and keeps existing ones frozen', async () => {
        // Ohne Aggregat rechnet der erste Lauf (z. B. beim Start) alles.
        await teile('stamm-1', 5);
        expect(await lauf()).toBe('woche');
        expect(aggregat()?.participating_stamm_count).toBe(1);
        expect(biberSumme()).toBe(5);

        // Ein erneuter Start ohne faelligen Lauf rechnet nichts.
        time.now = new Date('2026-06-10T18:00:00Z');
        await teile('stamm-1', 8);
        expect(await lauf()).toBeNull();
        expect(biberSumme()).toBe(5);

        // Nachtlauf ohne neue Staemme: Inhalt und Zeitpunkt bleiben, nur die Pruefung wird vermerkt.
        time.now = new Date('2026-06-11T03:00:00Z');
        expect(await lauf()).toBeNull();
        expect(aggregat()?.generated_at).toEqual(new Date('2026-06-10T12:00:00Z'));
        expect(aggregat()?.checked_at).toEqual(new Date('2026-06-11T03:00:00Z'));
        expect(await lauf()).toBeNull();

        // Nachtlauf mit neuem Stamm: Er kommt dazu, stamm-1 bleibt beim Stand des Wochenlaufs.
        time.now = new Date('2026-06-11T10:00:00Z');
        await teile('stamm-2', 3);
        time.now = new Date('2026-06-12T03:30:00Z');
        expect(await lauf()).toBe('nacht');
        expect(aggregat()?.participating_stamm_count).toBe(2);
        expect(biberSumme()).toBe(8);
        expect(aggregat()?.full_refresh_at).toEqual(new Date('2026-06-10T12:00:00Z'));

        // Wochenlauf am Montag: Alle Staemme werden neu berechnet.
        time.now = new Date('2026-06-15T03:00:00Z');
        expect(await lauf()).toBe('woche');
        expect(biberSumme()).toBe(11);
        expect(aggregat()?.aggregation_week).toBe('2026-W25');
    });

    test('keeps frozen stamms on the window of the last weekly run', async () => {
        store.rawSnapshots.length = 0;
        store.effectiveStates.clear();
        store.weeklyAggregates.clear();
        time.now = new Date('2026-06-08T03:00:00Z');
        await teile('stamm-alt', 4);
        time.now = new Date('2026-08-03T03:00:00Z');
        await teile('stamm-neu', 6);
        expect(await lauf()).toBe('woche');
        expect(aggregat()?.participating_stamm_count).toBe(2);

        // stamm-alt faellt am 08.08. aus dem Zwei-Monats-Fenster, bleibt aber bis zum
        // Wochenlauf veroeffentlicht, damit sich nachts nichts an bestehenden Staemmen aendert.
        time.now = new Date('2026-08-08T12:00:00Z');
        await teile('stamm-3', 2);
        time.now = new Date('2026-08-09T03:00:00Z');
        expect(await lauf()).toBe('nacht');
        expect(aggregat()?.participating_stamm_count).toBe(3);

        time.now = new Date('2026-08-10T03:00:00Z');
        expect(await lauf()).toBe('woche');
        expect(aggregat()?.participating_stamm_count).toBe(2);
    });
});
