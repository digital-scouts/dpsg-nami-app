import { describe, expect, test } from 'vitest';

import { createStatisticsMemoryStore } from '../src/infra/memory/statisticsMemoryStore.js';
import {
    beschreibeMeldung,
    beschreibeVersion,
    idAusTitel,
    leseMeldung,
    leseVersion,
    type MeldungEingabe,
} from '../src/modules/appFeeds/pruefung.js';
import { alsBerlinFeld, alsBerlinText, ausBerlinFeld } from '../src/shared/berlinZeit.js';
import { meldung, version } from './support/appFeeds.js';
import { buildMemoryTestServer } from './support/fixtures.js';

const now = new Date('2026-04-10T08:00:00Z');

describe('public app feeds', () => {
    test('serves notifications in the notifications.json format without login', async () => {
        const store = createStatisticsMemoryStore();
        store.meldungen.set('alt', meldung({ id: 'alt', created_at: new Date('2026-01-01T00:00:00Z'), external_link: null, deep_link: '/achievements' }));
        store.meldungen.set('wartung', meldung());
        const { server } = buildMemoryTestServer({ store });

        const response = await server.inject({ method: 'GET', url: '/app/notifications' });

        expect(response.statusCode).toBe(200);
        expect(response.headers['content-type']).toContain('application/json');
        expect(response.json()).toEqual({
            items: [
                {
                    id: 'wartung',
                    type: 'warn',
                    platform: 'all',
                    title: { de: 'Wartung', en: 'Maintenance' },
                    body: { de: 'Text', en: 'Text' },
                    starts_at: '2026-04-01T00:00:00.000Z',
                    ends_at: '2026-04-20T00:00:00.000Z',
                    external_link: 'https://status.example.org',
                    created_at: '2026-03-30T10:00:00.000Z',
                    updated_at: '2026-03-30T10:00:00.000Z',
                },
                expect.objectContaining({ id: 'alt', deep_link: '/achievements' }),
            ],
        });
        expect(response.json().items[1]).not.toHaveProperty('external_link');
        await server.close();
    });

    test('serves an empty list and answers unchanged content with 304', async () => {
        const { server } = buildMemoryTestServer();

        const erste = await server.inject({ method: 'GET', url: '/app/notifications' });
        const zweite = await server.inject({ method: 'GET', url: '/app/notifications', headers: { 'if-none-match': erste.headers.etag as string } });

        expect(erste.json()).toEqual({ items: [] });
        expect(erste.headers['cache-control']).toBe('no-cache');
        expect(zweite.statusCode).toBe(304);
        expect(zweite.body).toBe('');
        await server.close();
    });

    test('serves versions in the version.json format and 404 while none exist', async () => {
        const store = createStatisticsMemoryStore();
        const { server } = buildMemoryTestServer({ store });

        expect((await server.inject({ method: 'GET', url: '/app/version' })).statusCode).toBe(404);

        store.versionen.set('ios', version({
            security: { min_version: '1.0.1', betrifft: 'Anmeldung', betrifft_en: 'Sign-in', daten_loeschen: true },
        }));
        store.versionen.set('android', version({ plattform: 'android', store_url: 'https://play.google.com/store/apps/details?id=de.jlange.nami.app' }));
        const response = await server.inject({ method: 'GET', url: '/app/version' });

        expect(response.json()).toEqual({
            android: { latest: '1.0.0', min_supported: '1.0.0', store_url: 'https://play.google.com/store/apps/details?id=de.jlange.nami.app' },
            ios: {
                latest: '1.0.0',
                min_supported: '1.0.0',
                store_url: 'https://apps.apple.com/de/app/nami/id6468066816',
                security: { min_version: '1.0.1', betrifft: 'Anmeldung', betrifft_en: 'Sign-in', daten_loeschen: true },
            },
        });
        await server.close();
    });
});

describe('german time in forms', () => {
    test('converts summer and winter time both ways', () => {
        expect(ausBerlinFeld('2026-10-12T18:00')).toEqual(new Date('2026-10-12T16:00:00Z'));
        expect(ausBerlinFeld('2026-12-24T18:00')).toEqual(new Date('2026-12-24T17:00:00Z'));
        expect(alsBerlinFeld(new Date('2026-10-12T16:00:00Z'))).toBe('2026-10-12T18:00');
        expect(alsBerlinText(new Date('2026-10-12T16:00:00Z'))).toBe('Mo 12.10.2026, 18:00');
        expect(ausBerlinFeld('')).toBeNull();
    });

    test('rejects malformed values and times skipped by the clock change', () => {
        expect(ausBerlinFeld('12.10.2026 18:00')).toBe('ungueltig');
        expect(ausBerlinFeld('2026-02-30T10:00')).toBe('ungueltig');
        expect(ausBerlinFeld('2026-03-29T02:30')).toBe('ungueltig');
    });
});

const eingabe = (overrides: Partial<MeldungEingabe> = {}): MeldungEingabe => ({
    id: '',
    type: 'urgent',
    platform: 'all',
    title_de: 'Wartung am Samstag',
    title_en: 'Maintenance on Saturday',
    body_de: 'Text',
    body_en: 'Text',
    starts_at: '2026-04-11T18:00',
    ends_at: '2026-04-12T02:00',
    deep_link: '',
    external_link: '',
    ...overrides,
});

describe('notification rules', () => {
    test('derives the id from the german title and avoids taken ids', () => {
        expect(idAusTitel('Größere Änderung: Übersicht!')).toBe('groessere-aenderung-uebersicht');
        expect(leseMeldung(eingabe(), null, new Set(), now).meldung.id).toBe('wartung-am-samstag');
        expect(leseMeldung(eingabe(), null, new Set(['wartung-am-samstag']), now).meldung.id).toBe('wartung-am-samstag-2');
    });

    test('reports field errors that block saving', () => {
        const { befunde } = leseMeldung(eingabe({
            id: 'Wartung!',
            type: 'kritisch',
            title_en: '',
            ends_at: '2026-04-11T17:00',
            external_link: 'http://example.org',
            deep_link: '/settings/geheim',
        }), null, new Set(), now);

        expect(befunde.filter((b) => b.stufe === 'fehler').map((b) => b.feld)).toEqual(
            ['id', 'type', 'title_en', 'ends_at', 'external_link', 'deep_link'],
        );
        expect(leseMeldung(eingabe({ id: 'wartung' }), null, new Set(['wartung']), now).befunde[0].text).toBe('ID „wartung“ ist schon vergeben.');
    });

    test('keeps id and creation time when editing and warns about expired notifications', () => {
        const bisher = meldung();
        const { meldung: neu, befunde } = leseMeldung(eingabe({ id: 'anders', ends_at: '2026-04-05T10:00', starts_at: '' }), bisher, new Set(), now);

        expect(neu.id).toBe('wartung');
        expect(neu.created_at).toEqual(bisher.created_at);
        expect(neu.updated_at).toEqual(now);
        expect(befunde).toEqual([expect.objectContaining({ stufe: 'warnung', feld: 'ends_at' })]);
    });

    test('describes the effect of new, changed and deleted notifications', () => {
        const neu = leseMeldung(eingabe(), null, new Set(), now).meldung;

        expect(beschreibeMeldung(null, neu)[0]).toEqual({
            text: 'Neue urgent-Meldung erscheint als Banner oben in der App auf Android und iOS.',
            kritisch: true,
        });
        expect(beschreibeMeldung(null, neu)[1].text).toBe('Sichtbar ab Sa 11.04.2026, 18:00, bis So 12.04.2026, 02:00 (deutsche Zeit).');
        const geaendert = beschreibeMeldung(neu, { ...neu, type: 'info', title: { ...neu.title, de: 'Wartung' } }).map((w) => w.text);
        expect(geaendert).toContain('Typ: urgent → info');
        expect(geaendert).toContain('Titel Deutsch: Wartung am Samstag → Wartung');
        expect(geaendert.at(-1)).toContain('Wer die Meldung schon bestätigt hat');
        expect(beschreibeMeldung(neu, { ...neu })).toEqual([{ text: 'Keine Änderung.' }]);
        expect(beschreibeMeldung(neu, null)[0].text).toContain('gelöscht');
    });
});

describe('version rules', () => {
    const felder = {
        latest: '1.0.1',
        min_supported: '1.0.0',
        store_url: 'https://apps.apple.com/de/app/nami/id6468066816',
        security_aktiv: 'ja',
        security_min_version: '1.0.1',
        security_betrifft: 'Anmeldung bei Hitobito',
        security_betrifft_en: 'Sign-in to Hitobito',
        security_daten_loeschen: '',
    };

    test('checks versions, store url and the security block', () => {
        const { befunde } = leseVersion('android', {
            ...felder,
            latest: '1.0',
            min_supported: '1.1.0',
            security_min_version: 'neu',
            security_betrifft: '',
            security_betrifft_en: '',
        }, null, now);

        expect(befunde.map((b) => `${b.stufe}:${b.feld}`)).toEqual([
            'fehler:latest',
            'fehler:store_url',
            'fehler:security_min_version',
            'fehler:security_betrifft',
            'warnung:security_betrifft_en',
        ]);
        expect(leseVersion('ios', { ...felder, latest: '1.0.0', min_supported: '1.0.1', security_aktiv: '' }, null, now).befunde[0].text)
            .toBe('iOS: min_supported liegt über latest, niemand kann die Version laden.');
    });

    test('asks to confirm the store release when a security update starts', () => {
        const bisher = version({ latest: '1.0.0' });
        const { version: neu, befunde } = leseVersion('ios', felder, bisher, now);

        expect(befunde.map((b) => b.text)).toEqual(['iOS: Ist 1.0.1 schon im Store? Sonst kann niemand die Sperre durch ein Update lösen.']);
        expect(beschreibeVersion(bisher, neu)).toEqual([
            { text: 'latest 1.0.0 → 1.0.1: Hinweis „Update verfügbar“ für iOS-Apps unter 1.0.1.' },
            {
                kritisch: true,
                text: 'Sicherheitsupdate neu: iOS-Apps unter 1.0.1 fragen zweimal nach, zeigen dann einen Countdown und sperren sich danach bis zum Update.',
            },
            { text: 'Daten bleiben beim Sperren erhalten, Notfallkontakte bleiben lesbar.' },
        ]);
        expect(leseVersion('ios', felder, neu, now).befunde).toEqual([]);
        expect(beschreibeVersion(neu, { ...neu, security: null })[0].text).toContain('Sicherheitsupdate entfernt');
        expect(beschreibeVersion(neu, { ...neu, security: { ...neu.security!, daten_loeschen: true } })[1]).toEqual({
            kritisch: true,
            text: 'Beim Sperren meldet die App ab und löscht die Mitgliederdaten. Es gibt keinen Notfallzugang.',
        });
    });
});
