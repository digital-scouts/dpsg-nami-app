import 'dotenv/config';

import type { MongoClient } from 'mongodb';

import { buildServer } from './app/buildServer.js';
import { loadConfig } from './app/config.js';
import type { ServerDependencies } from './app/dependencies.js';
import { buildMemoryDependencies } from './infra/memory/statisticsMemoryStore.js';
import { buildMongoDbClient, connectToMongoDb } from './infra/mongodb/client.js';
import { buildMongoDependencies, initializeStatisticsPersistence } from './infra/mongodb/statisticsPersistence.js';
import { rebuildEffectiveStatesAndAggregate } from './modules/aggregation/refresh.js';
import { MOCK_SEED_INTERVAL_MS, seedMockSnapshots } from './modules/mockSeed/mockSeed.js';

const config = loadConfig();
// Im Speichermodus (Mock-Instanz) gibt es keine MongoDB; Daten gehen beim Neustart verloren.
const mongoClient: MongoClient | null = config.storageBackend === 'mongodb' ? buildMongoDbClient(config) : null;
const mongoDb = mongoClient?.db(config.mongoDbDatabase) ?? null;
const dependencies: ServerDependencies = mongoDb != null ? buildMongoDependencies(mongoDb) : buildMemoryDependencies();
const server = buildServer(config, dependencies);
let mockSeedTimer: NodeJS.Timeout | null = null;

const runMockSeed = async (): Promise<void> => {
    await seedMockSnapshots(dependencies, config.pseudonymizationSecret, config.mockSeedStammCount, dependencies.clock());
};

const start = async (): Promise<void> => {
    try {
        if (mongoClient != null && mongoDb != null) {
            await connectToMongoDb(mongoClient, config);
            await initializeStatisticsPersistence(mongoDb);
        }
        await rebuildEffectiveStatesAndAggregate(
            dependencies.rawSnapshotsRepository,
            dependencies.effectiveStatesRepository,
            dependencies.weeklyAggregatesRepository,
            dependencies.clock(),
        );
        if (config.mockSeedStammCount > 0) {
            await runMockSeed();
            // Taeglich frische Datenstaende, sonst fallen die Seeds nach zwei Monaten aus dem Aggregat.
            mockSeedTimer = setInterval(() => {
                runMockSeed().catch((error: unknown) => server.log.error(error, 'Mock seed failed'));
            }, MOCK_SEED_INTERVAL_MS);
            mockSeedTimer.unref();
        }
        await server.listen({ host: config.host, port: config.port });
        server.log.info(
            {
                host: config.host,
                port: config.port,
                storage: config.storageBackend,
                database: mongoDb != null ? config.mongoDbDatabase : null,
                mockSeedStammCount: config.mockSeedStammCount,
                version: config.gitSha,
            },
            'Statistics server listening',
        );
    } catch (error) {
        server.log.error(error, 'Failed to start statistics server');
        await mongoClient?.close().catch(() => undefined);
        process.exit(1);
    }
};

const shutdown = async (signal: NodeJS.Signals): Promise<void> => {
    server.log.info({ signal }, 'Shutting down statistics server');

    try {
        if (mockSeedTimer != null) {
            clearInterval(mockSeedTimer);
        }
        await server.close();
        await mongoClient?.close();
        process.exit(0);
    } catch (error) {
        server.log.error(error, 'Failed to shut down statistics server cleanly');
        process.exit(1);
    }
};

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
    process.on(signal, () => {
        void shutdown(signal);
    });
}

void start();
