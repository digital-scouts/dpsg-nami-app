import { afterAll, beforeAll, describe, expect, test } from 'vitest';

import { createStatisticsMemoryStore } from '../src/infra/memory/statisticsMemoryStore.js';
import { adminConfig, basic, meldung, version } from './support/appFeeds.js';
import { authHeader, buildMemoryTestServer, createValidPayload } from './support/fixtures.js';

describe('admin betrieb view', () => {
    const store = createStatisticsMemoryStore();
    store.meldungen.set('wartung', meldung({ title: { de: '<b>Wartung</b>', en: 'Maintenance' } }));
    store.meldungen.set('update', meldung({
        id: 'update',
        type: 'urgent',
        title: { de: 'Update', en: '' },
        starts_at: new Date('2026-05-01T00:00:00Z'),
        ends_at: null,
    }));
    store.versionen.set('ios', version({
        latest: '1.0.1',
        security: { min_version: '1.0.1', betrifft: 'Anmeldung', betrifft_en: 'Sign-in', daten_loeschen: false },
    }));
    const { server } = buildMemoryTestServer({ store, config: adminConfig() });

    beforeAll(async () => {
        await server.ready();
        await server.inject({ method: 'POST', url: '/snapshots/stamm', headers: authHeader(), payload: createValidPayload() });
    });

    afterAll(async () => {
        await server.close();
    });

    test('asks for basic auth', async () => {
        const response = await server.inject({ method: 'GET', url: '/admin/betrieb' });

        expect(response.statusCode).toBe(401);
        expect(response.headers['www-authenticate']).toContain('Basic');
    });

    test('renders checks, operation and a summary of the app contents', async () => {
        const response = await server.inject({ method: 'GET', url: '/admin/betrieb', headers: basic() });

        expect(response.statusCode).toBe(200);
        expect(response.headers['cache-control']).toBe('no-store');
        expect(response.headers['content-security-policy']).toContain("default-src 'none'");
        expect(response.body).toContain('aria-current="page">Betrieb</a>');
        // Die Version steht nur im Kopf, eine Kachel mit dem langen SHA liefe über.
        expect(response.body).not.toContain('Server-Version');
        expect(response.body).toContain('Meldung „update“: Titel Englisch fehlt.');
        expect(response.body).toContain('Versionen Android fehlen, die App prüft dort keine Updates.');
        expect(response.body).toContain('2 Meldungen · 1 aktiv, 1 geplant');
        expect(response.body).toContain('iOS 1.0.1 · Sicherheitsupdate aktiv');
        expect(response.body).toContain('href="/admin/meldungen"');
        expect(response.body).toContain('href="/admin/versionen"');
        expect(response.body).toContain('09.04.2026, 21:14 UTC');
        expect(response.body).not.toContain('<b>Wartung</b>');
        expect(response.body).toContain('1 in den letzten 7 Tagen');
        expect(response.body).toContain('erreichbar');
        // Snapshot vom 10.04.2026 laeuft 14 Monate spaeter ab, der Sender ebenso.
        expect(response.body).toContain('Snapshots 10.06.2027 · Installationen 10.06.2027 (1 gespeichert)');
        expect(response.body).toContain('<summary aria-label="Erklärung zu letztes Backup">i</summary>');
        expect(response.body).toContain('täglich um 03:15 Uhr');
    });

    test('links all admin areas from the statistics page', async () => {
        const response = await server.inject({ method: 'GET', url: '/admin', headers: basic() });

        for (const pfad of ['/admin/betrieb', '/admin/meldungen', '/admin/versionen']) {
            expect(response.body).toContain(`href="${pfad}"`);
        }
    });
});

describe('admin betrieb without database', () => {
    test('shows the database error instead of failing', async () => {
        const { server } = buildMemoryTestServer({
            config: adminConfig(),
            dependencies: {
                readinessProbe: {
                    pingDatabase: async () => {
                        throw new Error('down');
                    },
                    findLastBackupAt: async () => null,
                },
            },
        });

        const response = await server.inject({ method: 'GET', url: '/admin/betrieb', headers: basic() });

        expect(response.statusCode).toBe(200);
        expect(response.body).toContain('MongoDB ist nicht erreichbar.');
        expect(response.body).toContain('keine Meldungen');
        await server.close();
    });

    test('is not registered without admin configuration', async () => {
        const { server } = buildMemoryTestServer();

        expect((await server.inject({ method: 'GET', url: '/admin/betrieb' })).statusCode).toBe(404);
        expect((await server.inject({ method: 'GET', url: '/admin/meldungen' })).statusCode).toBe(404);
        await server.close();
    });
});
