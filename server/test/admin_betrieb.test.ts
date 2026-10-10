import { afterAll, beforeAll, describe, expect, test } from 'vitest';

import { createStatisticsMemoryStore } from '../src/infra/memory/statisticsMemoryStore.js';
import type { FeedFetcher } from '../src/modules/admin/feeds.js';
import { pruefeMeldungen, pruefeVersionen } from '../src/modules/admin/feeds.js';
import { hashAdminPassword } from '../src/modules/admin/password.js';
import { authHeader, buildMemoryTestServer, buildTestConfig, createValidPayload } from './support/fixtures.js';

const basic = () => ({
    authorization: `Basic ${Buffer.from('betrieb:ein-langes-passwort').toString('base64')}`,
});

const NOTIFICATIONS_URL = 'https://feeds.example.org/notifications.json';
const VERSION_URL = 'https://feeds.example.org/version.json';
const now = new Date('2026-04-10T08:00:00Z');

const notifications = {
    items: [
        {
            id: 'wartung',
            type: 'warn',
            title: { de: '<b>Wartung</b>', en: 'Maintenance' },
            body: { de: 'Text', en: 'Text' },
            starts_at: '2026-04-01T00:00:00Z',
            ends_at: '2026-04-20T00:00:00Z',
            external_link: 'https://status.example.org',
        },
        { id: 'update', type: 'urgent', title: { de: 'Update', en: '' }, body: { de: 'Text', en: 'Text' }, starts_at: '2026-05-01T00:00:00Z' },
    ],
};

const versions = {
    android: { latest: '1.0.0', min_supported: '1.1.0', store_url: 'https://play.google.com/store/apps/details?id=de.jlange.nami.app' },
    ios: { latest: '1.0.0', min_supported: '1.0.0', store_url: 'https://apps.apple.com/de/app/nami/id6468066816' },
};

const fetcher = (antworten: Record<string, unknown>): FeedFetcher & { aufrufe: string[] } => {
    const aufrufe: string[] = [];
    return {
        aufrufe,
        async fetchJson(url) {
            aufrufe.push(url);
            const antwort = antworten[url];
            if (antwort instanceof Error) {
                throw antwort;
            }
            return antwort;
        },
    };
};

const config = () => buildTestConfig({
    ADMIN_USER: 'betrieb',
    ADMIN_PASSWORD_HASH: hashAdminPassword('ein-langes-passwort'),
    ADMIN_NOTIFICATIONS_URL: NOTIFICATIONS_URL,
    ADMIN_VERSION_URL: VERSION_URL,
});

describe('admin betrieb view', () => {
    const feedFetcher = fetcher({ [NOTIFICATIONS_URL]: notifications, [VERSION_URL]: versions });
    const store = createStatisticsMemoryStore();
    const { server } = buildMemoryTestServer({ store, config: config(), dependencies: { feedFetcher } });

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

    test('renders checks, operation, notifications and versions escaped', async () => {
        const response = await server.inject({ method: 'GET', url: '/admin/betrieb', headers: basic() });

        expect(response.statusCode).toBe(200);
        expect(response.headers['cache-control']).toBe('no-store');
        expect(response.headers['content-security-policy']).toContain("default-src 'none'");
        expect(response.body).toContain('aria-current="page">Betrieb</a>');
        // Die Version steht nur im Kopf, eine Kachel mit dem langen SHA liefe über.
        expect(response.body).not.toContain('Server-Version');
        expect(response.body).toContain('latest 1.0.0 liegt unter min_supported 1.1.0');
        expect(response.body).toContain('Meldung „update“: title.en fehlt.');
        expect(response.body).toContain('&lt;b&gt;Wartung&lt;/b&gt;');
        expect(response.body).not.toContain('<b>Wartung</b>');
        expect(response.body).toContain('>aktiv</span>');
        expect(response.body).toContain('>geplant</span>');
        expect(response.body).toContain('1 in den letzten 7 Tagen');
        expect(response.body).toContain('erreichbar');
        // Snapshot vom 10.04.2026 laeuft 14 Monate spaeter ab, der Sender ebenso.
        expect(response.body).toContain('Snapshots 10.06.2027 · Installationen 10.06.2027 (1 gespeichert)');
        expect(response.body).toContain('<summary aria-label="Erklärung zu letztes Backup">i</summary>');
        expect(response.body).toContain('täglich um 03:15 Uhr');
    });

    test('fetches the feeds at most every five minutes', async () => {
        const vorher = feedFetcher.aufrufe.length;

        await server.inject({ method: 'GET', url: '/admin/betrieb', headers: basic() });

        expect(feedFetcher.aufrufe.length).toBe(vorher);
    });

    test('links back from the statistics page', async () => {
        const response = await server.inject({ method: 'GET', url: '/admin', headers: basic() });

        expect(response.body).toContain('href="/admin/betrieb"');
    });
});

describe('admin betrieb with unreachable feeds', () => {
    test('shows the fetch error instead of failing', async () => {
        const { server } = buildMemoryTestServer({
            config: config(),
            dependencies: { feedFetcher: fetcher({ [NOTIFICATIONS_URL]: new Error('HTTP 404'), [VERSION_URL]: new Error('timeout') }) },
        });

        const response = await server.inject({ method: 'GET', url: '/admin/betrieb', headers: basic() });

        expect(response.statusCode).toBe(200);
        expect(response.body).toContain('notifications.json nicht abrufbar: HTTP 404');
        expect(response.body).toContain('version.json nicht abrufbar: timeout');
        await server.close();
    });

    test('is not registered without admin configuration', async () => {
        const { server } = buildMemoryTestServer();

        expect((await server.inject({ method: 'GET', url: '/admin/betrieb' })).statusCode).toBe(404);
        await server.close();
    });
});

describe('feed checks', () => {
    test('reports structure errors, duplicates and invalid dates', () => {
        const { befunde, zeilen } = pruefeMeldungen(
            [
                { id: 'a', title: 'T', body: 'B' },
                { id: 'a', title: 'T', body: 'B', type: 'kritisch', platform: 'web' },
                { id: 'b', title: 'T', body: 'B', starts_at: '2026-04-05T00:00:00Z', ends_at: '2026-04-01T00:00:00Z' },
                { id: 'c', title: 'T', body: 'B', ends_at: 'gestern', external_link: 'http://x.org', deep_link: 'settings' },
                { title: 'T', body: 'B', ends_at: '2026-01-01T00:00:00Z' },
            ],
            now,
        );
        const texte = befunde.map((b) => `${b.stufe}: ${b.text}`);

        expect(texte).toContain('fehler: Meldung „a“: id doppelt, Bestätigungen gelten dann für beide.');
        expect(texte).toContain('warnung: Meldung „a“: unbekannter type „kritisch“, die App zeigt ihn als info.');
        expect(texte).toContain('warnung: Meldung „a“: unbekannte platform „web“, die Meldung erscheint nirgends.');
        expect(texte).toContain('fehler: Meldung „b“: ends_at liegt nicht nach starts_at.');
        expect(texte).toContain('fehler: Meldung „c“: starts_at oder ends_at ist kein gültiges Datum.');
        expect(texte).toContain('warnung: Meldung „c“: external_link ist nicht https, die App öffnet ihn nicht.');
        expect(texte).toContain('warnung: Meldung „c“: deep_link beginnt nicht mit „/“.');
        expect(texte).toContain('fehler: Eintrag 5: id fehlt, die App verwirft den Feed.');
        expect(zeilen.at(-1)?.status).toBe('abgelaufen');
        expect(pruefeMeldungen({ foo: 1 }, now).befunde[0].stufe).toBe('fehler');
    });

    test('checks versions and store urls', () => {
        const { befunde, plattformen } = pruefeVersionen({
            android: { latest: '1.2', min_supported: '1.0.0', store_url: 'https://example.org' },
        });
        const texte = befunde.map((b) => b.text);

        expect(texte).toContain('Version Android: latest „1.2“ ist keine Version x.y.z.');
        expect(texte).toContain('Version Android: store_url ist kein https-Link auf play.google.com.');
        expect(texte).toContain('Version iOS: Eintrag fehlt, die App prüft dort keine Updates.');
        expect(plattformen.map((p) => p.ok)).toEqual([false, false]);
        expect(pruefeVersionen(versions).plattformen.map((p) => p.ok)).toEqual([false, true]);
    });
});
