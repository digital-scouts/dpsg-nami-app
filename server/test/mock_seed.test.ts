import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import { createStatisticsMemoryStore } from '../src/infra/memory/statisticsMemoryStore.js';
import { runAggregatePublicationIfDue } from '../src/modules/aggregation/refresh.js';
import {
    buildMockSnapshotPayloads,
    MOCK_GRUPPEN_SENDER_EVERY,
    MOCK_RARE_METRIC_STAMM_COUNT,
    seedMockSnapshots,
} from '../src/modules/mockSeed/mockSeed.js';
import { parseStammesSnapshotPayload } from '../src/modules/stammesSnapshot/schema.js';
import {
    authHeader,
    buildMemoryTestServer,
    buildTestConfig,
    createMutableClock,
    createValidPayload,
} from './support/fixtures.js';

const SEED_COUNT = 30;

describe('mock seed', () => {
    const store = createStatisticsMemoryStore();
    const time = createMutableClock('2026-06-10T12:00:00Z');
    const config = buildTestConfig({ STORAGE_BACKEND: 'memory', MOCK_SEED_STAMM_COUNT: String(SEED_COUNT) });
    const { server, dependencies } = buildMemoryTestServer({ store, clock: time.clock, config });

    const seed = () => seedMockSnapshots(dependencies, config.pseudonymizationSecret, SEED_COUNT, time.now);

    const shareAndRead = async () => {
        const send = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(),
            payload: createValidPayload({
                stamm_id: 'simulator-stamm',
                sender_id: 'simulator-install',
                source_data_as_of: time.now.toISOString(),
            }),
        });
        expect(send.statusCode).toBe(204);

        return server.inject({
            method: 'GET',
            url: '/aggregates/bund/latest',
            headers: { 'x-sender-id': 'simulator-install', ...authHeader() },
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

    test('generates payloads that pass the ingest validation', () => {
        const payloads = buildMockSnapshotPayloads(SEED_COUNT, time.now);

        expect(new Set(payloads.map((payload) => payload.stamm_id)).size).toBe(SEED_COUNT);
        expect(payloads.filter((payload) => payload.abdeckung === 'gruppen')).toHaveLength(
            Math.ceil(SEED_COUNT / MOCK_GRUPPEN_SENDER_EVERY),
        );
        for (const payload of payloads) {
            expect(() => parseStammesSnapshotPayload(payload, time.now)).not.toThrow();
        }
    });

    test('is deterministic for the same input', () => {
        expect(buildMockSnapshotPayloads(5, time.now)).toEqual(buildMockSnapshotPayloads(5, time.now));
    });

    test('materializes seeded stamms without registering senders', async () => {
        await seed();

        expect(store.effectiveStates.size).toBe(SEED_COUNT);
        expect(store.senders.size).toBe(0);
    });

    test('lets a single installation read bund values after sharing', async () => {
        await seed();

        const response = await shareAndRead();
        const body = response.json();

        expect(response.statusCode).toBe(200);
        expect(body.status).toBe('ok');
        // Der eigene Stamm kommt erst mit dem naechsten Nachtlauf dazu.
        expect(body.participating_stamm_count).toBe(SEED_COUNT);
        expect(body.metrics.woelflinge.gesamt.sum).toBeGreaterThan(0);
        expect(body.gruppen_je_stufe.woelflinge.gruppen_count).toBeGreaterThan(SEED_COUNT);
        expect(body.gruppen_je_stufe.woelflinge.mitglieder.gesamt.median).toBeGreaterThan(0);
        // Seltene Kennzahlen liefern zu wenige Staemme und werden unterdrueckt.
        expect(body.metrics.biber.divers).toEqual({
            sum: null,
            stamm_count: MOCK_RARE_METRIC_STAMM_COUNT,
            median: null,
        });
    });

    test('reseeding keeps seeded stamms inside the aggregation window', async () => {
        await seed();

        time.now = new Date('2026-09-10T12:00:00Z');
        await seed();

        const body = (await shareAndRead()).json();

        expect(body.status).toBe('ok');
        expect(body.aggregation_week).toBe('2026-W37');
        expect(body.participating_stamm_count).toBe(SEED_COUNT);

        time.now = new Date('2026-09-11T03:00:00Z');
        expect(await runAggregatePublicationIfDue(dependencies, time.now)).toBe('nacht');
        const read = await server.inject({
            method: 'GET',
            url: '/aggregates/bund/latest',
            headers: { 'x-sender-id': 'simulator-install', ...authHeader() },
        });
        expect(read.json().participating_stamm_count).toBe(SEED_COUNT + 1);
    });
});
