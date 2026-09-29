import 'dotenv/config';

import { buildServer } from './app/buildServer.js';
import { loadConfig } from './app/config.js';
import { buildMongoDbClient, connectToMongoDb } from './infra/mongodb/client.js';
import { buildMongoDependencies, initializeStatisticsPersistence } from './infra/mongodb/statisticsPersistence.js';
import { rebuildEffectiveStatesAndAggregate } from './modules/aggregation/refresh.js';

const config = loadConfig();
const mongoClient = buildMongoDbClient(config);
const mongoDb = mongoClient.db(config.mongoDbDatabase);
const dependencies = buildMongoDependencies(mongoDb);
const server = buildServer(config, dependencies);

const start = async (): Promise<void> => {
    try {
        await connectToMongoDb(mongoClient, config);
        await initializeStatisticsPersistence(mongoDb);
        await rebuildEffectiveStatesAndAggregate(
            dependencies.rawSnapshotsRepository,
            dependencies.effectiveStatesRepository,
            dependencies.weeklyAggregatesRepository,
            dependencies.clock(),
        );
        await server.listen({ host: config.host, port: config.port });
        server.log.info(
            {
                host: config.host,
                port: config.port,
                database: config.mongoDbDatabase,
                version: config.gitSha,
            },
            'Statistics server listening',
        );
    } catch (error) {
        server.log.error(error, 'Failed to start statistics server');
        await mongoClient.close().catch(() => undefined);
        process.exit(1);
    }
};

const shutdown = async (signal: NodeJS.Signals): Promise<void> => {
    server.log.info({ signal }, 'Shutting down statistics server');

    try {
        await server.close();
        await mongoClient.close();
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
