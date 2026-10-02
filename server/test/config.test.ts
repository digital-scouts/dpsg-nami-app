import { describe, expect, test } from 'vitest';

import { loadConfig } from '../src/app/config.js';
import { hashAdminPassword } from '../src/modules/admin/password.js';

const requiredEnv = {
    PSEUDONYMIZATION_SECRET: 'test-secret',
    SENDER_SECRET_PEPPER: 'test-pepper',
};

describe('loadConfig', () => {
    test('uses MongoDB and hardening defaults for local development', () => {
        const config = loadConfig({
            NODE_ENV: 'test',
            ...requiredEnv,
        });

        expect(config.pseudonymizationSecret).toBe('test-secret');
        expect(config.senderSecretPepper).toBe('test-pepper');
        expect(config.mongoDbUri).toBe('mongodb://localhost:27017');
        expect(config.mongoDbDatabase).toBe('nami_statistics_local');
        expect(config.trustProxyHops).toBe(0);
        expect(config.bodyLimitBytes).toBe(32 * 1024);
        expect(config.rateLimitWindowMs).toBe(60 * 60 * 1000);
        expect(config.rateLimitIngestMax).toBe(30);
        expect(config.rateLimitReadMax).toBe(120);
        expect(config.minStammCountForRead).toBe(5);
        expect(config.gitSha).toBe('unknown');
        expect(config.storageBackend).toBe('mongodb');
        expect(config.mockSeedStammCount).toBe(0);
    });

    test('accepts the memory backend with mock seed', () => {
        const config = loadConfig({
            NODE_ENV: 'production',
            ...requiredEnv,
            STORAGE_BACKEND: 'memory',
            MOCK_SEED_STAMM_COUNT: '30',
        });

        expect(config.storageBackend).toBe('memory');
        expect(config.mockSeedStammCount).toBe(30);
    });

    test('rejects mock seed with the MongoDB backend', () => {
        expect(() =>
            loadConfig({
                NODE_ENV: 'test',
                ...requiredEnv,
                MOCK_SEED_STAMM_COUNT: '30',
            }),
        ).toThrow();
    });

    test('reads explicit environment variables', () => {
        const config = loadConfig({
            NODE_ENV: 'production',
            PSEUDONYMIZATION_SECRET: 'production-secret',
            SENDER_SECRET_PEPPER: 'production-pepper',
            MONGODB_URI: 'mongodb://user:pass@mongo.internal:27017/?authSource=admin',
            MONGODB_DATABASE: 'nami_statistics_prod',
            TRUST_PROXY_HOPS: '1',
            RATE_LIMIT_INGEST_MAX: '10',
            MIN_STAMM_COUNT_FOR_READ: '3',
            GIT_SHA: 'abc123',
        });

        expect(config.mongoDbUri).toBe('mongodb://user:pass@mongo.internal:27017/?authSource=admin');
        expect(config.mongoDbDatabase).toBe('nami_statistics_prod');
        expect(config.trustProxyHops).toBe(1);
        expect(config.rateLimitIngestMax).toBe(10);
        expect(config.minStammCountForRead).toBe(3);
        expect(config.gitSha).toBe('abc123');
    });

    test('requires a pseudonymization secret', () => {
        expect(() =>
            loadConfig({
                NODE_ENV: 'test',
                SENDER_SECRET_PEPPER: 'test-pepper',
            }),
        ).toThrow();
    });

    test('requires a sender secret pepper', () => {
        expect(() =>
            loadConfig({
                NODE_ENV: 'test',
                PSEUDONYMIZATION_SECRET: 'test-secret',
            }),
        ).toThrow();
    });

    test('leaves admin view and telegram off by default', () => {
        const config = loadConfig({ ...requiredEnv, ADMIN_USER: '', REPORT_TELEGRAM_CHAT_ID: '' });

        expect(config.admin).toBeNull();
        expect(config.telegram).toBeNull();
        expect(config.publicBaseUrl).toBeNull();
    });

    test('reads admin, telegram and public base url', () => {
        const passwordHash = hashAdminPassword('ein-langes-passwort');
        const config = loadConfig({
            ...requiredEnv,
            ADMIN_USER: 'betrieb',
            ADMIN_PASSWORD_HASH: passwordHash,
            REPORT_TELEGRAM_BOT_TOKEN: '123:abc',
            REPORT_TELEGRAM_CHAT_ID: '-10042',
            PUBLIC_BASE_URL: 'https://namiapp.example.org/',
        });

        expect(config.admin).toEqual({ user: 'betrieb', passwordHash });
        expect(config.telegram).toEqual({ botToken: '123:abc', chatId: '-10042' });
        expect(config.publicBaseUrl).toBe('https://namiapp.example.org');
    });

    test('rejects half configured admin access and telegram', () => {
        expect(() => loadConfig({ ...requiredEnv, ADMIN_USER: 'betrieb' })).toThrow(/ADMIN_USER and ADMIN_PASSWORD_HASH/);
        expect(() => loadConfig({ ...requiredEnv, ADMIN_USER: 'betrieb', ADMIN_PASSWORD_HASH: 'klartext' }))
            .toThrow(/npm run admin:hash/);
        expect(() => loadConfig({ ...requiredEnv, REPORT_TELEGRAM_BOT_TOKEN: '123:abc' })).toThrow(/REPORT_TELEGRAM/);
    });
});
