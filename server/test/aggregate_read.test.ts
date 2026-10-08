import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import { createStatisticsMemoryStore } from '../src/infra/memory/statisticsMemoryStore.js';
import { publishFullAggregate } from '../src/modules/aggregation/refresh.js';
import {
    authHeader,
    buildMemoryTestServer,
    buildTestConfig,
    createMutableClock,
    createValidPayload,
    fremdeGruppe,
    gruppe,
    OTHER_SECRET,
    TEST_SECRET,
} from './support/fixtures.js';

describe('bund aggregate read route', () => {
    const store = createStatisticsMemoryStore();
    const time = createMutableClock('2026-06-10T12:00:00Z');
    const { server, dependencies } = buildMemoryTestServer({
        store,
        clock: time.clock,
        config: buildTestConfig({ MIN_STAMM_COUNT_FOR_READ: '3' }),
    });

    const shareSnapshot = async (stammId: string, senderId: string, biber: number) => {
        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(),
            payload: createValidPayload({
                stamm_id: stammId,
                sender_id: senderId,
                source_data_as_of: time.now.toISOString(),
                gruppen: [gruppe('g-biber', 'biber', biber)],
            }),
        });
        expect(response.statusCode).toBe(204);
    };

    // Liest nach einem Wochenlauf zum aktuellen Zeitpunkt.
    const readAggregate = async (senderId: string | undefined, secret: string | null = TEST_SECRET) => {
        await publishFullAggregate(dependencies, time.now);
        return server.inject({
            method: 'GET',
            url: '/aggregates/bund/latest',
            headers: {
                ...(senderId == null ? {} : { 'x-sender-id': senderId }),
                ...(secret == null ? {} : authHeader(secret)),
            },
        });
    };

    beforeAll(async () => {
        await server.ready();
    });

    afterAll(async () => {
        await server.close();
    });

    beforeEach(() => {
        store.rawSnapshots.length = 0;
        store.senders.clear();
        store.effectiveStates.clear();
        store.weeklyAggregates.clear();
        time.now = new Date('2026-06-10T12:00:00Z');
    });

    test('requires sender id and secret', async () => {
        expect((await readAggregate(undefined)).json().error.code).toBe('missing_sender_credentials');
        expect((await readAggregate('install-1', null)).json().error.code).toBe('missing_sender_credentials');
    });

    test('denies senders that never shared a snapshot', async () => {
        const response = await readAggregate('install-unknown');

        expect(response.statusCode).toBe(403);
        expect(response.json().error.code).toBe('not_participating');
    });

    test('rejects a wrong secret for a known sender', async () => {
        await shareSnapshot('stamm-1', 'install-1', 15);

        const response = await readAggregate('install-1', OTHER_SECRET);

        expect(response.statusCode).toBe(401);
        expect(response.json().error.code).toBe('invalid_sender_credentials');
    });

    test('denies senders whose last successful send is older than 30 days', async () => {
        await shareSnapshot('stamm-1', 'install-1', 15);
        time.now = new Date('2026-07-10T12:00:00Z');
        expect((await readAggregate('install-1')).statusCode).toBe(200);
        time.now = new Date('2026-07-10T12:00:01Z');

        const response = await readAggregate('install-1');

        expect(response.statusCode).toBe(403);
        expect(response.json().error.code).toBe('not_participating');
    });

    test('reports insufficient participation below the minimum stamm count without a count', async () => {
        await shareSnapshot('stamm-1', 'install-1', 15);
        await shareSnapshot('stamm-2', 'install-2', 17);

        const response = await readAggregate('install-1');

        expect(response.statusCode).toBe(200);
        expect(response.json()).toMatchObject({
            status: 'insufficient_participation',
            teilnehmende_staemme_mindestens: null,
            min_stamm_count: 3,
            metrics: null,
        });
        expect(response.json()).not.toHaveProperty('participating_stamm_count');
    });

    test('returns the published aggregate with transparency metadata', async () => {
        await shareSnapshot('stamm-1', 'install-1', 15);
        await shareSnapshot('stamm-2', 'install-2', 17);
        time.now = new Date('2026-06-11T13:00:00Z');
        await shareSnapshot('stamm-3', 'install-3', 13);

        const response = await readAggregate('install-2');
        const body = response.json();

        expect(response.statusCode).toBe(200);
        expect(body).toMatchObject({
            status: 'ok',
            aggregation_type: 'bund',
            aggregation_week: '2026-W24',
            generated_at: '2026-06-11T13:00:00.000Z',
            teilnehmende_staemme_mindestens: 3,
            min_stamm_count: 3,
            data_as_of: {
                oldest: '2026-06-10T00:00:00.000Z',
                newest: '2026-06-11T00:00:00.000Z',
            },
        });
        expect(body.notice).toContain('Annäherung');
        expect(body.metrics.biber.gesamt).toEqual({ durchschnitt: 15, median: 15 });
        expect(body.metrics.biber.divers).toEqual({ durchschnitt: null, median: null, anteil: null });
        expect(JSON.stringify(body)).not.toMatch(/"sum"|"stamm_count"|"gruppen_count"|participating/);
    });

    test('keeps the values of an active installation when another one sends for the same stamm', async () => {
        await shareSnapshot('stamm-1', 'install-1', 15);
        await shareSnapshot('stamm-2', 'install-2', 17);
        await shareSnapshot('stamm-3', 'install-3', 13);
        time.now = new Date('2026-06-11T12:00:00Z');
        await shareSnapshot('stamm-1', 'install-4', 99);

        const body = (await readAggregate('install-1')).json();

        expect(body.metrics.biber.gesamt).toEqual({ durchschnitt: 15, median: 15 });
    });

    test('ignores a newer partial view of a stamm whose installation is active', async () => {
        await shareSnapshot('stamm-1', 'install-1', 15);
        await shareSnapshot('stamm-2', 'install-2', 17);
        await shareSnapshot('stamm-3', 'install-3', 13);
        time.now = new Date('2026-06-11T12:00:00Z');
        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(),
            payload: createValidPayload({
                stamm_id: 'stamm-1',
                sender_id: 'install-gruppe',
                source_data_as_of: time.now.toISOString(),
                abdeckung: 'gruppen',
                gruppen: [gruppe('g-biber', 'biber', 11, 2)],
                metrics: { leitende: { gesamt: 99 } },
            }),
        });
        expect(response.statusCode).toBe(204);

        const body = (await readAggregate('install-gruppe')).json();

        expect(body.status).toBe('ok');
        expect(body.metrics.biber.gesamt).toEqual({ durchschnitt: 15, median: 15 });
        // Stammweite Werte der Teilsicht werden verworfen, der Stamm-Snapshot bleibt massgeblich.
        expect(body.metrics.leitende.gesamt).toEqual({ durchschnitt: 3, median: 3 });
        expect(body.gruppen_je_stufe.biber).toMatchObject({
            gruppen_pro_stamm: { durchschnitt: 1, median: 1 },
            mitglieder: { gesamt: { durchschnitt: 15, median: 15 } },
            leitende: { gesamt: { durchschnitt: 1, median: 1 } },
        });
        expect(body.gruppen_je_stufe.woelflinge.mitglieder.gesamt).toEqual({ durchschnitt: null, median: null });
    });

    test('delivers the gender distribution over all stufen with shares', async () => {
        for (const nummer of [1, 2, 3]) {
            const response = await server.inject({
                method: 'POST',
                url: '/snapshots/stamm',
                headers: authHeader(),
                payload: createValidPayload({
                    stamm_id: `stamm-${nummer}`,
                    sender_id: `install-${nummer}`,
                    source_data_as_of: time.now.toISOString(),
                    gruppen: [
                        gruppe('g-woe', 'woelflinge', 10, 2, { mitglieder: { gesamt: 10, maennlich: 6, weiblich: 4, divers: 0, geschlecht_unbekannt: 0 } }),
                        gruppe('g-rov', 'rover', 6, 1, { mitglieder: { gesamt: 6, maennlich: 2, weiblich: 4, divers: 0, geschlecht_unbekannt: 0 } }),
                    ],
                }),
            });
            expect(response.statusCode).toBe(204);
        }

        const body = (await readAggregate('install-1')).json();

        expect(body.metrics.alle_stufen).toMatchObject({
            gesamt: { durchschnitt: 16, median: 16 },
            maennlich: { durchschnitt: 8, median: 8, anteil: 50 },
            weiblich: { durchschnitt: 8, median: 8, anteil: 50 },
            divers: { durchschnitt: 0, median: 0, anteil: 0 },
        });
    });

    test('lets a sender without readable values read, without counting its stamm', async () => {
        await shareSnapshot('stamm-1', 'install-1', 15);
        await shareSnapshot('stamm-2', 'install-2', 17);
        // Leitung ohne lesbare Rollen: Teilnahme ohne Werte, nur die Gruppenstruktur.
        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(),
            payload: createValidPayload({
                stamm_id: 'stamm-3',
                sender_id: 'install-3',
                source_data_as_of: time.now.toISOString(),
                abdeckung: 'gruppen',
                gruppen: [fremdeGruppe('g-woe', 'woelflinge'), fremdeGruppe('g-biber', 'biber')],
            }),
        });
        expect(response.statusCode).toBe(204);

        const read = await readAggregate('install-3');

        expect(read.statusCode).toBe(200);
        expect(read.json()).toMatchObject({ status: 'insufficient_participation' });
    });

    test('ignores the stamm-wide values of a group-only stamm', async () => {
        await shareSnapshot('stamm-1', 'install-1', 15);
        await shareSnapshot('stamm-2', 'install-2', 17);
        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(),
            payload: createValidPayload({
                stamm_id: 'stamm-3',
                sender_id: 'install-3',
                source_data_as_of: time.now.toISOString(),
                abdeckung: 'gruppen',
                gruppen: [gruppe('g-woe-1', 'woelflinge', 12), fremdeGruppe('g-woe-2', 'woelflinge'), fremdeGruppe('g-biber', 'biber')],
            }),
        });
        expect(response.statusCode).toBe(204);

        const body = (await readAggregate('install-3')).json();

        expect(body.status).toBe('ok');
        // Woelflinge: Stamm 3 hat zwei Meuten, nur eine ist bekannt, also kein Stufenwert; die
        // anderen Staemme haben keine Meute. Leitende kennt nur die Stammessicht von 1 und 2.
        expect(body.metrics.woelflinge.gesamt).toEqual({ durchschnitt: null, median: null });
        expect(body.metrics.leitende.gesamt).toEqual({ durchschnitt: null, median: null });
        expect(body.gruppen_je_stufe.woelflinge.mitglieder.gesamt).toEqual({ durchschnitt: null, median: null });
        expect(body.metrics.biber.gesamt).toEqual({ durchschnitt: null, median: null });
    });
});
