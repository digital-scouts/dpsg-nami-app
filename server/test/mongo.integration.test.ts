import { MongoClient, type Db } from 'mongodb';
import { MongoMemoryServer } from 'mongodb-memory-server';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import { buildServer } from '../src/app/buildServer.js';
import {
    buildMongoDependencies,
    initializeStatisticsPersistence,
    statisticsCollectionNames,
} from '../src/infra/mongodb/statisticsPersistence.js';
import { rebuildEffectiveStatesAndAggregate } from '../src/modules/aggregation/refresh.js';
import {
    authHeader,
    buildTestConfig,
    createMutableClock,
    createValidPayload,
    OTHER_SECRET,
} from './support/fixtures.js';

describe('statistics server with MongoDB', () => {
    let mongo: MongoMemoryServer;
    let client: MongoClient;
    let db: Db;
    const time = createMutableClock('2026-06-10T12:00:00Z');

    const buildMongoServer = () =>
        buildServer(
            buildTestConfig({ MIN_STAMM_COUNT_FOR_READ: '2' }),
            buildMongoDependencies(db, time.clock),
        );

    const share = (server: ReturnType<typeof buildMongoServer>, overrides: Record<string, unknown>, secret?: string) =>
        server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(secret),
            payload: createValidPayload({
                sent_at: time.now.toISOString(),
                source_data_as_of: time.now.toISOString(),
                ...overrides,
            }),
        });

    beforeAll(async () => {
        mongo = await MongoMemoryServer.create();
        client = new MongoClient(mongo.getUri());
        await client.connect();
    });

    afterAll(async () => {
        await client?.close();
        await mongo?.stop();
    });

    beforeEach(async () => {
        db = client.db(`nami_statistics_test_${Date.now()}_${Math.random().toString(16).slice(2)}`);
        await initializeStatisticsPersistence(db);
        time.now = new Date('2026-06-10T12:00:00Z');
    });

    test('creates collections and indexes idempotently', async () => {
        await initializeStatisticsPersistence(db);

        const indexNames = async (collection: string) =>
            (await db.collection(collection).indexes()).map((index) => index.name);

        expect(await indexNames(statisticsCollectionNames.rawSnapshots)).toEqual(
            expect.arrayContaining(['raw_snapshots_by_stamm_and_recency', 'raw_snapshots_by_sent_at', 'raw_snapshots_dedup']),
        );
        expect(await indexNames(statisticsCollectionNames.effectiveStates)).toContain('effective_states_by_stamm');
        expect(await indexNames(statisticsCollectionNames.weeklyAggregates)).toContain('weekly_aggregates_by_week_and_type');
        expect(await indexNames(statisticsCollectionNames.senders)).toContain('senders_by_pseudonym');
    });

    test('persists ingest end to end without raw ids and serves the aggregate', async () => {
        const server = buildMongoServer();

        expect((await share(server, { stamm_id: 'stamm-a', sender_id: 'install-a', metrics: { biber: { gesamt: 4 } } })).statusCode).toBe(204);
        expect((await share(server, { stamm_id: 'stamm-b', sender_id: 'install-b', metrics: { biber: { gesamt: 6 } } })).statusCode).toBe(204);

        const rawSnapshots = await db.collection(statisticsCollectionNames.rawSnapshots).find().toArray();
        expect(rawSnapshots).toHaveLength(2);
        expect(rawSnapshots[0]?.sent_at).toBeInstanceOf(Date);
        expect(JSON.stringify(rawSnapshots)).not.toContain('stamm-a');
        expect(JSON.stringify(rawSnapshots)).not.toContain('install-a');
        expect(await db.collection(statisticsCollectionNames.effectiveStates).countDocuments()).toBe(2);
        expect(await db.collection(statisticsCollectionNames.weeklyAggregates).countDocuments()).toBe(1);

        const response = await server.inject({
            method: 'GET',
            url: '/aggregates/bund/latest',
            headers: { 'x-sender-id': 'install-a', ...authHeader() },
        });

        expect(response.statusCode).toBe(200);
        expect(response.json()).toMatchObject({
            status: 'ok',
            participating_stamm_count: 2,
            metrics: { biber: { gesamt: { sum: 10, stamm_count: 2, median: 5 } } },
        });

        await server.close();
    });

    test('ignores duplicates and keeps the newest state for out-of-order snapshots', async () => {
        const server = buildMongoServer();

        await share(server, { source_data_as_of: '2026-06-09T00:00:00Z', metrics: { biber: { gesamt: 9 } } });
        const duplicate = await share(server, { source_data_as_of: '2026-06-09T00:00:00Z', metrics: { biber: { gesamt: 9 } } });
        await share(server, { source_data_as_of: '2026-06-01T00:00:00Z', metrics: { biber: { gesamt: 2 } } });

        expect(duplicate.statusCode).toBe(204);
        expect(await db.collection(statisticsCollectionNames.rawSnapshots).countDocuments()).toBe(2);

        const states = await db.collection(statisticsCollectionNames.effectiveStates).find().toArray();
        expect(states).toHaveLength(1);
        expect(states[0]?.metrics.biber.gesamt).toBe(9);

        await server.close();
    });

    test('rejects a second secret for an already registered installation', async () => {
        const server = buildMongoServer();

        expect((await share(server, {})).statusCode).toBe(204);
        const response = await share(server, { source_data_as_of: '2026-06-10T11:00:00Z' }, OTHER_SECRET);

        expect(response.statusCode).toBe(401);
        expect(await db.collection(statisticsCollectionNames.senders).countDocuments()).toBe(1);

        await server.close();
    });

    test('handles concurrent first registrations of the same installation', async () => {
        const server = buildMongoServer();

        const responses = await Promise.all([
            share(server, { source_data_as_of: '2026-06-10T10:00:00Z' }),
            share(server, { source_data_as_of: '2026-06-10T10:30:00Z' }, OTHER_SECRET),
        ]);
        const statusCodes = responses.map((response) => response.statusCode).sort();

        expect(statusCodes).toEqual([204, 401]);
        expect(await db.collection(statisticsCollectionNames.senders).countDocuments()).toBe(1);

        await server.close();
    });

    test('rebuilds effective states and aggregate from raw snapshots', async () => {
        const server = buildMongoServer();
        await share(server, { stamm_id: 'stamm-a', source_data_as_of: '2026-06-01T00:00:00Z', metrics: { biber: { gesamt: 1 } } });
        await share(server, { stamm_id: 'stamm-a', source_data_as_of: '2026-06-05T00:00:00Z', metrics: { biber: { gesamt: 3 } } });
        await share(server, { stamm_id: 'stamm-b', metrics: { biber: { gesamt: 7 } } });
        await server.close();

        await db.collection(statisticsCollectionNames.effectiveStates).deleteMany({});
        await db.collection(statisticsCollectionNames.effectiveStates).insertOne({ stamm_pseudonym: 'orphan' });
        await db.collection(statisticsCollectionNames.weeklyAggregates).deleteMany({});

        const dependencies = buildMongoDependencies(db, time.clock);
        await rebuildEffectiveStatesAndAggregate(
            dependencies.rawSnapshotsRepository,
            dependencies.effectiveStatesRepository,
            dependencies.weeklyAggregatesRepository,
            time.now,
        );

        const states = await dependencies.effectiveStatesRepository.findAll();
        expect(states).toHaveLength(2);
        expect(states.map((state) => state.metrics.biber.gesamt).sort()).toEqual([3, 7]);

        const aggregate = await dependencies.weeklyAggregatesRepository.findLatest('bund');
        expect(aggregate?.participating_stamm_count).toBe(2);
    });

    test('reports readiness including the backup marker', async () => {
        const server = buildMongoServer();
        await db.collection<{ _id: string; last_success_at: Date }>(statisticsCollectionNames.opsStatus).insertOne({
            _id: 'backup',
            last_success_at: new Date('2026-06-10T03:00:00Z'),
        });

        const response = await server.inject({ method: 'GET', url: '/health/ready' });

        expect(response.statusCode).toBe(200);
        expect(response.json().checks).toEqual({
            mongodb: 'ok',
            last_backup_at: '2026-06-10T03:00:00.000Z',
            aggregate_generated_at: null,
        });

        await server.close();
    });
});
