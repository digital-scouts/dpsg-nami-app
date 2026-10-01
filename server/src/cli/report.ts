import 'dotenv/config';

import { loadConfig } from '../app/config.js';
import { buildMongoDbClient, connectToMongoDb } from '../infra/mongodb/client.js';
import { buildMongoDependencies } from '../infra/mongodb/statisticsPersistence.js';
import { buildSmtpReportMailer } from '../modules/report/mailer.js';
import { buildMonthlyReport, isValidMonth, previousMonth } from '../modules/report/report.js';

// Monatsreport von Hand: npm run report -- [--month YYYY-MM] [--dry-run]
const args = process.argv.slice(2);
const monthIndex = args.indexOf('--month');
const month = monthIndex >= 0 ? args[monthIndex + 1] ?? '' : previousMonth(new Date());
const dryRun = args.includes('--dry-run');

const main = async (): Promise<void> => {
    if (!isValidMonth(month)) {
        throw new Error(`--month erwartet YYYY-MM, erhalten: "${month}"`);
    }

    const config = loadConfig();
    if (config.storageBackend !== 'mongodb') {
        throw new Error('Der Report braucht STORAGE_BACKEND=mongodb.');
    }
    if (!dryRun && config.report == null) {
        throw new Error('Ohne REPORT_SMTP_HOST, REPORT_MAIL_FROM und REPORT_MAIL_TO nur mit --dry-run moeglich.');
    }

    const client = buildMongoDbClient(config);
    try {
        await connectToMongoDb(client, config);
        const dependencies = buildMongoDependencies(client.db(config.mongoDbDatabase));
        const message = await buildMonthlyReport(dependencies, month, config.minStammCountForRead);

        if (dryRun || config.report == null) {
            process.stdout.write(`${message.subject}\n\n${message.text}\n`);
            return;
        }

        await buildSmtpReportMailer(config.report).send(message);
        await dependencies.reportStatusRepository.markReported(month, new Date());
        process.stdout.write(`Report ${month} verschickt.\n`);
    } finally {
        await client.close();
    }
};

main().catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exit(1);
});
