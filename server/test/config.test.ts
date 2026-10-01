import { describe, expect, test } from 'vitest';

import { loadConfig } from '../src/app/config.js';

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

    test('disables the monthly report without SMTP host', () => {
        const config = loadConfig({ ...requiredEnv, REPORT_SMTP_HOST: '', REPORT_MAIL_TO: 'a@example.org' });

        expect(config.report).toBeNull();
    });

    test('reads the monthly report configuration', () => {
        const config = loadConfig({
            ...requiredEnv,
            REPORT_SMTP_HOST: 'smtp.example.org',
            REPORT_SMTP_USER: 'report',
            REPORT_SMTP_PASS: 'geheim',
            REPORT_MAIL_FROM: 'statistik@example.org',
            REPORT_MAIL_TO: 'a@example.org, b@example.org',
        });

        expect(config.report).toEqual({
            smtpHost: 'smtp.example.org',
            smtpPort: 587,
            smtpUser: 'report',
            smtpPass: 'geheim',
            mailFrom: 'statistik@example.org',
            mailTo: ['a@example.org', 'b@example.org'],
        });
    });

    test('rejects an SMTP host without sender or recipient', () => {
        expect(() => loadConfig({ ...requiredEnv, REPORT_SMTP_HOST: 'smtp.example.org', REPORT_MAIL_FROM: 'x@example.org' }))
            .toThrow(/REPORT_SMTP_HOST requires/);
    });
});
