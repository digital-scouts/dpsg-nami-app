import 'dotenv/config';

import type { MongoClient } from 'mongodb';

import { buildServer } from './app/buildServer.js';
import { loadConfig } from './app/config.js';
import type { ServerDependencies } from './app/dependencies.js';
import { buildMemoryDependencies } from './infra/memory/statisticsMemoryStore.js';
import { buildMongoDbClient, connectToMongoDb } from './infra/mongodb/client.js';
import { buildMongoDependencies, initializeStatisticsPersistence } from './infra/mongodb/statisticsPersistence.js';
import { runAggregatePublicationIfDue } from './modules/aggregation/refresh.js';
import { MOCK_SEED_INTERVAL_MS, seedMockSnapshots } from './modules/mockSeed/mockSeed.js';
import { runMonthlyReportIfDue } from './modules/report/report.js';
import { buildTelegramNotifier } from './modules/report/telegram.js';

const REPORT_CHECK_INTERVAL_MS = 6 * 60 * 60 * 1000;
const PUBLICATION_CHECK_INTERVAL_MS = 60 * 60 * 1000;

const config = loadConfig();
// Im Speichermodus (Mock-Instanz) gibt es keine MongoDB; Daten gehen beim Neustart verloren.
const mongoClient: MongoClient | null = config.storageBackend === 'mongodb' ? buildMongoDbClient(config) : null;
const mongoDb = mongoClient?.db(config.mongoDbDatabase) ?? null;
const dependencies: ServerDependencies = mongoDb != null ? buildMongoDependencies(mongoDb) : buildMemoryDependencies();
const server = buildServer(config, dependencies);
let mockSeedTimer: NodeJS.Timeout | null = null;
let reportTimer: NodeJS.Timeout | null = null;
let publicationTimer: NodeJS.Timeout | null = null;
const reportNotifier = config.telegram != null ? buildTelegramNotifier(config.telegram) : null;

const runMockSeed = async (): Promise<void> => {
    await seedMockSnapshots(dependencies, config.pseudonymizationSecret, config.mockSeedStammCount, dependencies.clock());
};

// Die Mock-Instanz legt keine Monatsberichte an; ihre Daten sind synthetisch und fluechtig.
const reportsEnabled = config.storageBackend === 'mongodb';

const runReportCheck = async (): Promise<void> => {
    try {
        const month = await runMonthlyReportIfDue(
            dependencies,
            reportNotifier,
            {
                minStammCount: config.minStammCountForRead,
                adminUrl: config.publicBaseUrl != null && config.admin != null ? `${config.publicBaseUrl}/admin` : null,
            },
            dependencies.clock(),
        );
        if (month != null) {
            server.log.info({ month }, 'Monthly report notification sent');
        }
    } catch (error) {
        // Beim naechsten Durchlauf erneut versuchen; der Merker bleibt unveraendert.
        server.log.error(error, 'Monthly report failed');
    }
};

// Wochen- und Nachtlauf des Bundesaggregats; ein verpasster Lauf wird nachgeholt.
const runPublicationCheck = async (): Promise<void> => {
    try {
        const lauf = await runAggregatePublicationIfDue(dependencies, dependencies.clock());
        if (lauf != null) {
            server.log.info({ lauf }, 'Bund aggregate published');
        }
    } catch (error) {
        server.log.error(error, 'Bund aggregate publication failed');
    }
};

const start = async (): Promise<void> => {
    try {
        if (mongoClient != null && mongoDb != null) {
            await connectToMongoDb(mongoClient, config);
            await initializeStatisticsPersistence(mongoDb);
        }
        // Rechnet beim Start nur, wenn noch kein Aggregat existiert oder ein Lauf faellig ist;
        // ein Deploy soll keine zusaetzliche Veroeffentlichung ausloesen.
        await runAggregatePublicationIfDue(dependencies, dependencies.clock());
        if (config.mockSeedStammCount > 0) {
            await runMockSeed();
            // Taeglich frische Datenstaende, sonst fallen die Seeds nach zwei Monaten aus dem Aggregat.
            mockSeedTimer = setInterval(() => {
                runMockSeed().catch((error: unknown) => server.log.error(error, 'Mock seed failed'));
            }, MOCK_SEED_INTERVAL_MS);
            mockSeedTimer.unref();
        }
        await server.listen({ host: config.host, port: config.port });
        publicationTimer = setInterval(() => {
            void runPublicationCheck();
        }, PUBLICATION_CHECK_INTERVAL_MS);
        publicationTimer.unref();
        if (reportsEnabled) {
            void runReportCheck();
            reportTimer = setInterval(() => {
                void runReportCheck();
            }, REPORT_CHECK_INTERVAL_MS);
            reportTimer.unref();
        }
        server.log.info(
            {
                host: config.host,
                port: config.port,
                storage: config.storageBackend,
                database: mongoDb != null ? config.mongoDbDatabase : null,
                mockSeedStammCount: config.mockSeedStammCount,
                admin: config.admin != null,
                telegram: config.telegram != null,
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
        if (reportTimer != null) {
            clearInterval(reportTimer);
        }
        if (publicationTimer != null) {
            clearInterval(publicationTimer);
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
