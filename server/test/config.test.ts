import { describe, expect, test } from 'vitest';

import { loadConfig } from '../src/app/config.js';

describe('loadConfig', () => {
    test('uses MongoDB defaults for local development', () => {
        const config = loadConfig({
            NODE_ENV: 'test',
            PSEUDONYMIZATION_SECRET: 'test-secret',
        });

        expect(config.pseudonymizationSecret).toBe('test-secret');
        expect(config.mongoDbUri).toBe('mongodb://localhost:27017');
        expect(config.mongoDbDatabase).toBe('nami_statistics_local');
    });

    test('reads explicit MongoDB environment variables', () => {
        const config = loadConfig({
            NODE_ENV: 'production',
            PSEUDONYMIZATION_SECRET: 'production-secret',
            MONGODB_URI: 'mongodb://mongo.internal:27017',
            MONGODB_DATABASE: 'nami_statistics_prod',
        });

        expect(config.pseudonymizationSecret).toBe('production-secret');
        expect(config.mongoDbUri).toBe('mongodb://mongo.internal:27017');
        expect(config.mongoDbDatabase).toBe('nami_statistics_prod');
    });

    test('requires a pseudonymization secret', () => {
        expect(() =>
            loadConfig({
                NODE_ENV: 'test',
            }),
        ).toThrow();
    });
});