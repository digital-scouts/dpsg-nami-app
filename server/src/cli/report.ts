import 'dotenv/config';

import { loadConfig } from '../app/config.js';
import { buildMongoDbClient, connectToMongoDb } from '../infra/mongodb/client.js';
import { buildMongoDependencies } from '../infra/mongodb/statisticsPersistence.js';
import { buildMonthlyReport, isValidMonth, previousMonth } from '../modules/report/report.js';

// Monatsreport als Text ausgeben: npm run report -- [--month YYYY-MM]
const args = process.argv.slice(2);
const monthIndex = args.indexOf('--month');
const month = monthIndex >= 0 ? args[monthIndex + 1] ?? '' : previousMonth(new Date());

const main = async (): Promise<void> => {
    if (!isValidMonth(month)) {
        throw new Error(`--month erwartet YYYY-MM, erhalten: "${month}"`);
    }

    const config = loadConfig();
    if (config.storageBackend !== 'mongodb') {
        throw new Error('Der Report braucht STORAGE_BACKEND=mongodb.');
    }

    const client = buildMongoDbClient(config);
    try {
        await connectToMongoDb(client, config);
        const dependencies = buildMongoDependencies(client.db(config.mongoDbDatabase));
        const message = await buildMonthlyReport(dependencies, month, config.minStammCountForRead);
        process.stdout.write(`${message.subject}\n\n${message.text}\n`);
    } finally {
        await client.close();
    }
};

main().catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exit(1);
});
