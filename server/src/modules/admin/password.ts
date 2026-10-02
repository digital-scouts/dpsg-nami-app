import { randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

// Format: scrypt:<salt hex>:<hash hex>. Doppelpunkte statt "$", weil docker compose "$" in
// .env-Dateien als Variable interpretiert.
const PREFIX = 'scrypt';
const KEY_LENGTH = 64;
const HASH_PATTERN = /^scrypt:[a-f0-9]{32}:[a-f0-9]{128}$/;

export const isAdminPasswordHash = (value: string): boolean => HASH_PATTERN.test(value);

export const hashAdminPassword = (password: string, salt: Buffer = randomBytes(16)): string =>
    `${PREFIX}:${salt.toString('hex')}:${scryptSync(password, salt, KEY_LENGTH).toString('hex')}`;

export const verifyAdminPassword = (password: string, stored: string): boolean => {
    if (!isAdminPasswordHash(stored)) {
        return false;
    }
    const [, saltHex = '', hashHex = ''] = stored.split(':');
    const expected = Buffer.from(hashHex, 'hex');
    const actual = scryptSync(password, Buffer.from(saltHex, 'hex'), KEY_LENGTH);

    return timingSafeEqual(actual, expected);
};

// Vergleich in konstanter Zeit, auch bei unterschiedlicher Laenge.
export const safeEqual = (a: string, b: string): boolean => {
    const left = Buffer.from(a);
    const right = Buffer.from(b);
    if (left.length !== right.length) {
        timingSafeEqual(left, left);
        return false;
    }
    return timingSafeEqual(left, right);
};
