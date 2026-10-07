import 'dotenv/config';

import { loadConfig } from '../app/config.js';
import { buildMongoDbClient, connectToMongoDb } from '../infra/mongodb/client.js';
import { buildMongoDependencies } from '../infra/mongodb/statisticsPersistence.js';
import { auskunftFuerInstallation, loescheInstallation } from '../modules/betroffenenanfrage/installation.js';

// Anfragen Betroffener bearbeiten (Ablauf siehe deploy/README.md):
//   npm run installation -- auskunft --sender-id <Installations-ID>
//   npm run installation -- loeschen --sender-id <Installations-ID>
const args = process.argv.slice(2);
const befehl = args[0];
const senderIdIndex = args.indexOf('--sender-id');
const senderId = senderIdIndex >= 0 ? args[senderIdIndex + 1] ?? '' : '';

const main = async (): Promise<void> => {
    if (befehl !== 'auskunft' && befehl !== 'loeschen') {
        throw new Error('Aufruf: npm run installation -- auskunft|loeschen --sender-id <Installations-ID>');
    }

    const config = loadConfig();
    if (config.storageBackend !== 'mongodb') {
        throw new Error('Die Bearbeitung braucht STORAGE_BACKEND=mongodb.');
    }

    const client = buildMongoDbClient(config);
    try {
        await connectToMongoDb(client, config);
        const dependencies = buildMongoDependencies(client.db(config.mongoDbDatabase));
        const ergebnis = befehl === 'auskunft'
            ? await auskunftFuerInstallation(dependencies, senderId, config.pseudonymizationSecret)
            : await loescheInstallation(dependencies, senderId, config.pseudonymizationSecret, new Date());
        process.stdout.write(`${JSON.stringify(ergebnis, null, 2)}\n`);
    } finally {
        await client.close();
    }
};

main().catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exit(1);
});
