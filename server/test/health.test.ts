import { afterEach, describe, expect, test } from 'vitest';

import { buildMemoryTestServer, buildTestConfig } from './support/fixtures.js';

describe('health routes', () => {
    let close: (() => Promise<unknown>) | undefined;

    afterEach(async () => {
        await close?.();
    });

    test('returns a healthy liveness response', async () => {
        const { server } = buildMemoryTestServer();
        close = () => server.close();

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

    test('reports readiness with version, backup and aggregate timestamps', async () => {
        const { server, store } = buildMemoryTestServer({
            config: buildTestConfig({ GIT_SHA: 'sha-123' }),
        });
        close = () => server.close();
        store.lastBackupAt = new Date('2026-04-10T03:00:00Z');

        const response = await server.inject({
            method: 'GET',
            url: '/health/ready',
        });

        expect(response.statusCode).toBe(200);
        expect(response.json()).toEqual({
            status: 'ok',
            service: 'nami-statistics-server',
            version: 'sha-123',
            checks: {
                mongodb: 'ok',
                last_backup_at: '2026-04-10T03:00:00.000Z',
                aggregate_generated_at: null,
            },
        });
    });

    test('responds with 503 when the database is unreachable', async () => {
        const { server } = buildMemoryTestServer({
            dependencies: {
                readinessProbe: {
                    pingDatabase: async () => {
                        throw new Error('connection refused');
                    },
                    findLastBackupAt: async () => null,
                },
            },
        });
        close = () => server.close();

        const response = await server.inject({
            method: 'GET',
            url: '/health/ready',
        });

        expect(response.statusCode).toBe(503);
        expect(response.json()).toMatchObject({
            status: 'error',
            checks: { mongodb: 'error' },
        });
        expect(response.body).not.toContain('connection refused');
    });
});
