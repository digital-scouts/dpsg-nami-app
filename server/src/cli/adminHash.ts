import { createInterface } from 'node:readline/promises';

import { hashAdminPassword } from '../modules/admin/password.js';

// Erzeugt ADMIN_PASSWORD_HASH: npm run admin:hash (Passwort wird abgefragt, nicht als Argument).
const main = async (): Promise<void> => {
    const readline = createInterface({ input: process.stdin, output: process.stderr, terminal: true });
    const password = (await readline.question('Passwort fuer /admin: ')).trim();
    readline.close();

    if (password.length < 12) {
        throw new Error('Das Passwort muss mindestens 12 Zeichen haben.');
    }
    process.stdout.write(`ADMIN_PASSWORD_HASH=${hashAdminPassword(password)}\n`);
};

main().catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exit(1);
});
