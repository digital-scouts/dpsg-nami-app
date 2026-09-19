import { afterAll, beforeAll, describe, expect, test } from 'vitest';

import { buildServer } from '../src/app/buildServer.js';
import { loadConfig } from '../src/app/config.js';

describe('health route', () => {
    const server = buildServer(
        loadConfig({
            NODE_ENV: 'test',
            LOG_LEVEL: 'error',
            PSEUDONYMIZATION_SECRET: 'test-secret',
        }),
    );

    beforeAll(async () => {
        await server.ready();
    });

    afterAll(async () => {
        await server.close();
    });

    test('returns a healthy response', async () => {
        const response = await server.inject({
            method: 'GET',
            url: '/health',
        });

        expect(response.statusCode).toBe(200);
        expect(response.json()).toEqual({
            status: 'ok',
            service: 'nami-statistics-server',
        });
    });
});