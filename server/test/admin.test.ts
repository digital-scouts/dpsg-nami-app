import { afterAll, beforeAll, describe, expect, test } from 'vitest';

import { createStatisticsMemoryStore } from '../src/infra/memory/statisticsMemoryStore.js';
import { hashAdminPassword, verifyAdminPassword } from '../src/modules/admin/password.js';
import { computeReportFigures } from '../src/modules/report/report.js';
import { buildTelegramNotifier } from '../src/modules/report/telegram.js';
import { authHeader, buildMemoryTestServer, buildTestConfig, createValidPayload } from './support/fixtures.js';

const basic = (user: string, password: string) => ({
    authorization: `Basic ${Buffer.from(`${user}:${password}`).toString('base64')}`,
});

describe('admin password', () => {
    test('verifies only the matching password', () => {
        const hash = hashAdminPassword('ein-langes-passwort');

        expect(hash).toMatch(/^scrypt:[a-f0-9]{32}:[a-f0-9]{128}$/);
        expect(verifyAdminPassword('ein-langes-passwort', hash)).toBe(true);
        expect(verifyAdminPassword('falsch', hash)).toBe(false);
        expect(verifyAdminPassword('ein-langes-passwort', 'kaputt')).toBe(false);
    });
});

describe('admin view', () => {
    const store = createStatisticsMemoryStore();
    const config = buildTestConfig({
        ADMIN_USER: 'betrieb',
        ADMIN_PASSWORD_HASH: hashAdminPassword('ein-langes-passwort'),
    });
    const { server } = buildMemoryTestServer({ store, config });

    beforeAll(async () => {
        await server.ready();
        // DV-IDs kommen von den Apps und duerfen kein HTML einschleusen.
        await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(),
            payload: createValidPayload({ dv_id: '<script>alert(1)</script>', sent_at: '2026-04-09T18:30:00Z' }),
        });
        store.monthlyReports.set('2026-03', {
            month: '2026-03',
            figures: computeReportFigures('2026-03', [], []),
            created_at: new Date('2026-04-01T00:00:00Z'),
            notified_at: null,
        });
    });

    afterAll(async () => {
        await server.close();
    });

    test('asks for basic auth without or with wrong credentials', async () => {
        for (const headers of [{}, basic('betrieb', 'falsch'), basic('jemand', 'ein-langes-passwort'), { authorization: 'Bearer x' }]) {
            const response = await server.inject({ method: 'GET', url: '/admin', headers });

            expect(response.statusCode).toBe(401);
            expect(response.headers['www-authenticate']).toBe('Basic realm="NaMi-Statistik", charset="UTF-8"');
        }
    });

    test('renders the current month, regions and history escaped', async () => {
        const response = await server.inject({ method: 'GET', url: '/admin', headers: basic('betrieb', 'ein-langes-passwort') });

        expect(response.statusCode).toBe(200);
        expect(response.headers['content-type']).toContain('text/html');
        expect(response.headers['cache-control']).toBe('no-store');
        expect(response.headers['x-robots-tag']).toBe('noindex');
        expect(response.headers['content-security-policy']).toContain("default-src 'none'");
        expect(response.body).toContain('Laufender Monat 2026-04');
        expect(response.body).toContain('&lt;script&gt;alert(1)&lt;/script&gt;');
        expect(response.body).not.toContain('<script>');
        expect(response.body).toContain('<td>2026-03</td>');
    });

    test('is not registered without admin configuration', async () => {
        const { server: ohneAdmin } = buildMemoryTestServer();

        expect((await ohneAdmin.inject({ method: 'GET', url: '/admin' })).statusCode).toBe(404);
        await ohneAdmin.close();
    });
});

describe('telegram notifier', () => {
    test('posts the message to the configured chat', async () => {
        const calls: Array<{ url: string; body: unknown }> = [];
        const fakeFetch = (async (url: string, init?: RequestInit) => {
            calls.push({ url, body: JSON.parse(String(init?.body)) });
            return new Response('{"ok":true}', { status: 200 });
        }) as unknown as typeof fetch;

        await buildTelegramNotifier({ botToken: '123:abc', chatId: '-100' }, fakeFetch).send('Hallo');

        expect(calls).toEqual([{
            url: 'https://api.telegram.org/bot123:abc/sendMessage',
            body: { chat_id: '-100', text: 'Hallo', disable_web_page_preview: true },
        }]);
    });

    test('reports failures without the token', async () => {
        const fakeFetch = (async () => new Response('chat not found', { status: 400 })) as unknown as typeof fetch;

        const error = await buildTelegramNotifier({ botToken: '123:geheim', chatId: '-100' }, fakeFetch).send('x').catch((e: Error) => e);

        expect(String(error)).toContain('400: chat not found');
        expect(String(error)).not.toContain('geheim');
    });
});
