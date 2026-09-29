import { afterEach, describe, expect, test } from 'vitest';

import { authHeader, buildMemoryTestServer, buildTestConfig, createValidPayload } from './support/fixtures.js';

describe('server error handling', () => {
    let close: (() => Promise<unknown>) | undefined;

    afterEach(async () => {
        await close?.();
    });

    test('returns structured 404 for unknown routes', async () => {
        const { server } = buildMemoryTestServer();
        close = () => server.close();

        const response = await server.inject({ method: 'GET', url: '/unknown' });

        expect(response.statusCode).toBe(404);
        expect(response.json()).toEqual({
            error: {
                code: 'not_found',
                message: 'Route GET /unknown not found',
            },
        });
    });

    test('masks unexpected internal errors', async () => {
        const { server } = buildMemoryTestServer({
            dependencies: {
                rawSnapshotsRepository: {
                    insert: async () => {
                        throw new Error('E11001 secret mongo internals');
                    },
                    findLatestPerStamm: async () => [],
                },
            },
        });
        close = () => server.close();

        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(),
            payload: createValidPayload(),
        });

        expect(response.statusCode).toBe(500);
        expect(response.json()).toEqual({
            error: {
                code: 'internal_error',
                message: 'Unexpected server error',
            },
        });
    });

    test('maps malformed JSON to invalid_request', async () => {
        const { server } = buildMemoryTestServer();
        close = () => server.close();

        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: { ...authHeader(), 'content-type': 'application/json' },
            payload: '{"schema_version":',
        });

        expect(response.statusCode).toBe(400);
        expect(response.json().error.code).toBe('invalid_request');
    });

    test('rejects unsupported content types', async () => {
        const { server } = buildMemoryTestServer();
        close = () => server.close();

        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: { ...authHeader(), 'content-type': 'application/xml' },
            payload: '<snapshot/>',
        });

        expect(response.statusCode).toBe(415);
        expect(response.json().error.code).toBe('unsupported_media_type');
    });

    test('rejects payloads above the body limit', async () => {
        const { server } = buildMemoryTestServer({
            config: buildTestConfig({ BODY_LIMIT_BYTES: '1024' }),
        });
        close = () => server.close();

        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(),
            payload: createValidPayload({ padding: 'x'.repeat(2048) }),
        });

        expect(response.statusCode).toBe(413);
        expect(response.json().error.code).toBe('payload_too_large');
    });

    test('rate limits the ingest route per client', async () => {
        const { server } = buildMemoryTestServer({
            config: buildTestConfig({ RATE_LIMIT_INGEST_MAX: '2' }),
        });
        close = () => server.close();

        const post = () => server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(),
            payload: createValidPayload(),
        });

        expect((await post()).statusCode).toBe(204);
        expect((await post()).statusCode).toBe(204);
        const limited = await post();

        expect(limited.statusCode).toBe(429);
        expect(limited.json()).toEqual({
            error: {
                code: 'rate_limited',
                message: 'Too many requests',
            },
        });
    });

    test('does not rate limit health checks', async () => {
        const { server } = buildMemoryTestServer({
            config: buildTestConfig({ RATE_LIMIT_INGEST_MAX: '1', RATE_LIMIT_READ_MAX: '1' }),
        });
        close = () => server.close();

        for (let attempt = 0; attempt < 5; attempt += 1) {
            expect((await server.inject({ method: 'GET', url: '/health' })).statusCode).toBe(200);
        }
    });
});
