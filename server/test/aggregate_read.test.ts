import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import { createStatisticsMemoryStore } from '../src/infra/memory/statisticsMemoryStore.js';
import {
    authHeader,
    buildMemoryTestServer,
    buildTestConfig,
    createMutableClock,
    createValidPayload,
    OTHER_SECRET,
    TEST_SECRET,
} from './support/fixtures.js';

describe('bund aggregate read route', () => {
    const store = createStatisticsMemoryStore();
    const time = createMutableClock('2026-06-10T12:00:00Z');
    const { server } = buildMemoryTestServer({
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
                sent_at: time.now.toISOString(),
                source_data_as_of: time.now.toISOString(),
                metrics: { biber: { gesamt: biber } },
            }),
        });
        expect(response.statusCode).toBe(204);
    };

    const readAggregate = (senderId: string | undefined, secret: string | null = TEST_SECRET) =>
        server.inject({
            method: 'GET',
            url: '/aggregates/bund/latest',
            headers: {
                ...(senderId == null ? {} : { 'x-sender-id': senderId }),
                ...(secret == null ? {} : authHeader(secret)),
            },
        });

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
        await shareSnapshot('stamm-1', 'install-1', 5);

        const response = await readAggregate('install-1', OTHER_SECRET);

        expect(response.statusCode).toBe(401);
        expect(response.json().error.code).toBe('invalid_sender_credentials');
    });

    test('denies senders whose last successful send is older than 14 days', async () => {
        await shareSnapshot('stamm-1', 'install-1', 5);
        time.now = new Date('2026-06-24T12:00:01Z');

        const response = await readAggregate('install-1');

        expect(response.statusCode).toBe(403);
        expect(response.json().error.code).toBe('not_participating');
    });

    test('reports insufficient participation below the minimum stamm count', async () => {
        await shareSnapshot('stamm-1', 'install-1', 5);
        await shareSnapshot('stamm-2', 'install-2', 7);

        const response = await readAggregate('install-1');

        expect(response.statusCode).toBe(200);
        expect(response.json()).toMatchObject({
            status: 'insufficient_participation',
            participating_stamm_count: 2,
            min_stamm_count: 3,
            metrics: null,
        });
    });

    test('returns the materialized aggregate with transparency metadata', async () => {
        await shareSnapshot('stamm-1', 'install-1', 5);
        await shareSnapshot('stamm-2', 'install-2', 7);
        time.now = new Date('2026-06-10T13:00:00Z');
        await shareSnapshot('stamm-3', 'install-3', 3);

        const response = await readAggregate('install-2');
        const body = response.json();

        expect(response.statusCode).toBe(200);
        expect(body).toMatchObject({
            status: 'ok',
            aggregation_type: 'bund',
            aggregation_week: '2026-W24',
            generated_at: '2026-06-10T13:00:00.000Z',
            participating_stamm_count: 3,
            min_stamm_count: 3,
            data_as_of: {
                oldest: '2026-06-10T12:00:00.000Z',
                newest: '2026-06-10T13:00:00.000Z',
            },
        });
        expect(body.notice).toContain('Annäherung');
        expect(body.metrics.biber.gesamt).toEqual({ sum: 15, stamm_count: 3, median: 5 });
        expect(body.metrics.biber.divers).toEqual({ sum: null, stamm_count: 0, median: null });
    });

    test('uses only the newest data state per stamm across senders', async () => {
        await shareSnapshot('stamm-1', 'install-1', 5);
        await shareSnapshot('stamm-2', 'install-2', 7);
        await shareSnapshot('stamm-3', 'install-3', 3);
        time.now = new Date('2026-06-11T12:00:00Z');
        await shareSnapshot('stamm-1', 'install-4', 9);

        const body = (await readAggregate('install-1')).json();

        expect(body.participating_stamm_count).toBe(3);
        expect(body.metrics.biber.gesamt).toEqual({ sum: 19, stamm_count: 3, median: 7 });
    });
});
