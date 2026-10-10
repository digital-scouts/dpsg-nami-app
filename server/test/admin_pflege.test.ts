import { describe, expect, test } from 'vitest';

import { createStatisticsMemoryStore } from '../src/infra/memory/statisticsMemoryStore.js';
import { adminConfig, basic, meldung, version } from './support/appFeeds.js';
import { buildMemoryTestServer } from './support/fixtures.js';

const now = new Date('2026-04-10T08:00:00Z');

const setup = (options: { notifier?: { send(text: string): Promise<void> } } = {}) => {
    const store = createStatisticsMemoryStore();
    const gesendet: string[] = [];
    const notifier = options.notifier ?? { send: async (text: string) => { gesendet.push(text); } };
    const { server } = buildMemoryTestServer({
        store,
        clock: () => now,
        config: adminConfig({ PUBLIC_BASE_URL: 'https://namiapp.example.org' }),
        dependencies: { notifier },
    });
    const csrf = async () => {
        const seite = await server.inject({ method: 'GET', url: '/admin/meldungen/neu', headers: basic() });
        return /name="csrf" value="([^"]+)"/.exec(seite.body)![1];
    };
    const post = (url: string, felder: Record<string, string>, headers: Record<string, string> = {}) =>
        server.inject({
            method: 'POST',
            url,
            headers: {
                ...basic(),
                'content-type': 'application/x-www-form-urlencoded',
                'sec-fetch-site': 'same-origin',
                ...headers,
            },
            payload: new URLSearchParams(felder).toString(),
        });
    return { store, server, gesendet, csrf, post };
};

const neueMeldung = {
    id: '',
    stand: '',
    type: 'urgent',
    platform: 'all',
    title_de: 'Wartung am Samstag',
    title_en: 'Maintenance on Saturday',
    body_de: 'Hitobito ist <b>nicht</b> erreichbar.',
    body_en: 'Hitobito is down.',
    starts_at: '2026-04-11T18:00',
    ends_at: '2026-04-12T02:00',
    deep_link: '',
    external_link: '',
};

describe('admin notification forms', () => {
    test('requires login for pages and forms', async () => {
        const { server } = setup();

        for (const url of ['/admin/meldungen', '/admin/meldungen/neu', '/admin/versionen']) {
            expect((await server.inject({ method: 'GET', url })).statusCode).toBe(401);
        }
        expect((await server.inject({ method: 'POST', url: '/admin/meldungen/neu/vorschau', payload: {} })).statusCode).toBe(401);
        await server.close();
    });

    test('rejects forms without token or from other sites', async () => {
        const { server, csrf, post, store } = setup();
        const token = await csrf();

        expect((await post('/admin/meldungen/neu', { ...neueMeldung, aktion: 'speichern' })).statusCode).toBe(403);
        expect((await post('/admin/meldungen/neu', { ...neueMeldung, csrf: token, aktion: 'speichern' }, { 'sec-fetch-site': 'cross-site' })).statusCode).toBe(403);
        expect((await post('/admin/meldungen/neu', { ...neueMeldung, csrf: token, aktion: 'speichern' }, { origin: 'https://boese.example.org' })).statusCode).toBe(403);
        expect(store.meldungen.size).toBe(0);
        await server.close();
    });

    test('creates a notification via preview and reports it', async () => {
        const { server, csrf, post, store, gesendet } = setup();
        const token = await csrf();

        const vorschau = await post('/admin/meldungen/neu/vorschau', { ...neueMeldung, csrf: token });
        expect(vorschau.statusCode).toBe(200);
        expect(vorschau.headers['content-security-policy']).toContain("form-action 'self'");
        expect(vorschau.body).toContain('Neue urgent-Meldung erscheint als Banner oben in der App auf Android und iOS.');
        expect(vorschau.body).toContain('Hitobito ist &lt;b&gt;nicht&lt;/b&gt; erreichbar.');
        expect(vorschau.body).not.toContain('<b>nicht</b>');
        expect(vorschau.body).toContain('name="id" value="wartung-am-samstag"');
        expect(store.meldungen.size).toBe(0);

        const gespeichert = await post('/admin/meldungen/neu', { ...neueMeldung, id: 'wartung-am-samstag', csrf: token, aktion: 'speichern' });
        expect(gespeichert.statusCode).toBe(303);
        expect(gespeichert.headers.location).toBe('/admin/meldungen?ok=gespeichert');
        expect(store.meldungen.get('wartung-am-samstag')).toMatchObject({
            type: 'urgent',
            starts_at: new Date('2026-04-11T16:00:00Z'),
            created_at: now,
        });
        expect(gesendet).toEqual([[
            'NaMi-App: Meldung angelegt',
            'Neue urgent-Meldung erscheint als Banner oben in der App auf Android und iOS.',
            'Sichtbar ab Sa 11.04.2026, 18:00, bis So 12.04.2026, 02:00 (deutsche Zeit).',
            'Link: kein Link.',
            'Apps laden sie beim nächsten Abruf.',
            '',
            'https://namiapp.example.org/admin/meldungen',
        ].join('\n')]);

        const liste = await server.inject({ method: 'GET', url: '/admin/meldungen?ok=gespeichert', headers: basic() });
        expect(liste.body).toContain('Gespeichert.');
        expect(liste.body).toContain('href="/admin/meldungen/wartung-am-samstag"');
        await server.close();
    });

    test('shows errors in the form instead of the preview', async () => {
        const { server, csrf, post, store } = setup();

        const antwort = await post('/admin/meldungen/neu/vorschau', { ...neueMeldung, title_en: '', ends_at: '2026-04-11T17:00', csrf: await csrf() });

        expect(antwort.statusCode).toBe(422);
        expect(antwort.body).toContain('2 Fehler – bitte korrigieren.');
        expect(antwort.body).toContain('Titel Englisch fehlt.');
        expect(antwort.body).toContain('„Bis“ liegt nicht nach „Ab“.');
        expect(antwort.body).toContain('value="Wartung am Samstag"');
        expect(store.meldungen.size).toBe(0);
        await server.close();
    });

    test('goes back to the form with the entered values', async () => {
        const { server, csrf, post } = setup();

        const antwort = await post('/admin/meldungen/neu', { ...neueMeldung, title_de: 'Geändert', csrf: await csrf(), aktion: 'zurueck' });

        expect(antwort.statusCode).toBe(200);
        expect(antwort.body).toContain('Neue Meldung');
        expect(antwort.body).toContain('value="Geändert"');
        await server.close();
    });

    test('edits with the stored state and refuses outdated forms', async () => {
        const { server, csrf, post, store, gesendet } = setup();
        store.meldungen.set('wartung', meldung());
        const token = await csrf();
        const formular = await server.inject({ method: 'GET', url: '/admin/meldungen/wartung', headers: basic() });
        const stand = /name="stand" value="([^"]+)"/.exec(formular.body)![1];
        expect(formular.body).toContain('value="2026-04-01T02:00"');
        expect(formular.body).toContain('href="/admin/meldungen/wartung/loeschen"');

        const felder = { ...neueMeldung, type: 'info', title_de: 'Wartung', csrf: token, stand };
        const vorschau = await post('/admin/meldungen/wartung/vorschau', felder);
        expect(vorschau.body).toContain('Typ: warn → info');

        const veraltet = await post('/admin/meldungen/wartung', { ...felder, stand: '2026-01-01T00:00:00.000Z', aktion: 'speichern' });
        expect(veraltet.statusCode).toBe(409);
        expect(veraltet.body).toContain('Inzwischen von anderer Stelle geändert.');
        expect(store.meldungen.get('wartung')?.type).toBe('warn');

        expect((await post('/admin/meldungen/wartung', { ...felder, aktion: 'speichern' })).statusCode).toBe(303);
        expect(store.meldungen.get('wartung')).toMatchObject({ type: 'info', created_at: new Date('2026-03-30T10:00:00Z') });
        expect(gesendet[0]).toContain('NaMi-App: Meldung geändert\n');
        await server.close();
    });

    test('deletes after confirmation', async () => {
        const { server, csrf, post, store, gesendet } = setup();
        store.meldungen.set('wartung', meldung());
        const token = await csrf();

        const rueckfrage = await server.inject({ method: 'GET', url: '/admin/meldungen/wartung/loeschen', headers: basic() });
        expect(rueckfrage.body).toContain('Endgültig löschen');
        expect(rueckfrage.body).toContain('Die ID „wartung“ wird frei.');

        const antwort = await post('/admin/meldungen/wartung/loeschen', { csrf: token, stand: '2026-03-30T10:00:00.000Z' });
        expect(antwort.statusCode).toBe(303);
        expect(store.meldungen.size).toBe(0);
        expect(gesendet[0]).toContain('NaMi-App: Meldung gelöscht');
        expect((await server.inject({ method: 'GET', url: '/admin/meldungen/wartung', headers: basic() })).statusCode).toBe(404);
        await server.close();
    });

    test('saves even if the notification fails', async () => {
        const { server, csrf, post, store } = setup({ notifier: { send: async () => { throw new Error('telegram down'); } } });

        const antwort = await post('/admin/meldungen/neu', { ...neueMeldung, csrf: await csrf(), aktion: 'speichern' });

        expect(antwort.statusCode).toBe(303);
        expect(store.meldungen.size).toBe(1);
        await server.close();
    });
});

describe('admin version forms', () => {
    const iosFelder = {
        stand: '',
        latest: '1.0.1',
        min_supported: '1.0.0',
        store_url: 'https://apps.apple.com/de/app/nami/id6468066816',
        security_aktiv: 'ja',
        security_min_version: '1.0.1',
        security_betrifft: 'Anmeldung bei Hitobito',
        security_betrifft_en: 'Sign-in to Hitobito',
    };

    test('shows both platforms and marks missing ones', async () => {
        const { server, store } = setup();
        store.versionen.set('ios', version({ security: { min_version: '1.0.1', betrifft: 'A', betrifft_en: 'B', daten_loeschen: false } }));

        const seite = await server.inject({ method: 'GET', url: '/admin/versionen', headers: basic() });

        expect(seite.body).toContain('aria-current="page">Versionen</a>');
        expect(seite.body).toContain('Noch nicht angelegt, die App prüft hier keine Updates.');
        expect(seite.body).toContain('<details class="sicher aktiv" open>');
        expect(seite.body).toContain('action="/admin/versionen/android/vorschau"');
        expect(seite.body).toContain('Keine Sperre.');
        await server.close();
    });

    test('previews the lock of a security update and saves it', async () => {
        const { server, csrf, post, store, gesendet } = setup();
        store.versionen.set('ios', version());
        const felder = { ...iosFelder, stand: '2026-04-09T21:14:00.000Z', csrf: await csrf() };

        const vorschau = await post('/admin/versionen/ios/vorschau', felder);
        expect(vorschau.statusCode).toBe(200);
        expect(vorschau.body).toContain('<li class="kritisch">Sicherheitsupdate neu: iOS-Apps unter 1.0.1');
        expect(vorschau.body).toContain('Ist 1.0.1 schon im Store?');

        expect((await post('/admin/versionen/ios', { ...felder, aktion: 'speichern' })).statusCode).toBe(303);
        expect(store.versionen.get('ios')?.security).toEqual({
            min_version: '1.0.1', betrifft: 'Anmeldung bei Hitobito', betrifft_en: 'Sign-in to Hitobito', daten_loeschen: false,
        });
        expect(gesendet[0].split('\n')[0]).toBe('NaMi-App: Versionen iOS geändert');
        const api = await server.inject({ method: 'GET', url: '/app/version' });
        expect(api.json().ios.security.min_version).toBe('1.0.1');
        await server.close();
    });

    test('keeps the input of the edited platform on errors', async () => {
        const { server, csrf, post, store } = setup();

        const antwort = await post('/admin/versionen/android/vorschau', { ...iosFelder, security_aktiv: '', csrf: await csrf() });

        expect(antwort.statusCode).toBe(422);
        expect(antwort.body).toContain('Android: Store-Adresse muss ein https-Link auf play.google.com sein.');
        expect(antwort.body).toContain('value="https://apps.apple.com/de/app/nami/id6468066816"');
        expect((await post('/admin/versionen/web/vorschau', { csrf: await csrf() })).statusCode).toBe(404);
        expect(store.versionen.size).toBe(0);
        await server.close();
    });
});
