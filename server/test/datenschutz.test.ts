import { describe, expect, test } from 'vitest';

import { buildServer } from '../src/app/buildServer.js';
import { buildMemoryDependencies, createStatisticsMemoryStore } from '../src/infra/memory/statisticsMemoryStore.js';
import { auskunftFuerInstallation, loescheInstallation } from '../src/modules/betroffenenanfrage/installation.js';
import { snapshotWindowStart } from '../src/modules/effectiveState/effectiveState.js';
import { monthStart, previousMonth, REPORT_BACKFILL_MONTHS, toMonth } from '../src/modules/report/report.js';
import { buildPseudonym } from '../src/modules/stammesSnapshot/pseudonymize.js';
import { addUtcMonths, RETENTION_MONTHS } from '../src/shared/retention.js';
import { subtractUtcMonths } from '../src/shared/time.js';
import {
    authHeader,
    buildTestConfig,
    createMutableClock,
    createValidPayload,
    gruppe,
    OTHER_SECRET,
} from './support/fixtures.js';

const CLIENT_IP = '203.0.113.77';

describe('Request-Log ohne Client-IP (S-06)', () => {
    const logZeilen = () => {
        const zeilen: string[] = [];
        return { zeilen, stream: { write: (zeile: string) => zeilen.push(zeile) } };
    };

    test('protokolliert Methode, Routenmuster und Status, aber weder IP noch IDs', async () => {
        const log = logZeilen();
        const server = buildServer(
            buildTestConfig({ LOG_LEVEL: 'info', TRUST_PROXY_HOPS: '1' }),
            buildMemoryDependencies(createStatisticsMemoryStore(), () => new Date('2026-04-10T08:00:00Z')),
            log.stream,
        );

        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: { ...authHeader(), 'x-forwarded-for': CLIENT_IP },
            payload: createValidPayload(),
            remoteAddress: '198.51.100.9',
        });
        await server.close();

        expect(response.statusCode).toBe(204);
        const alles = log.zeilen.join('');
        expect(alles).toContain('"route":"/snapshots/stamm"');
        expect(alles).toContain('"status":204');
        expect(alles).not.toContain(CLIENT_IP);
        expect(alles).not.toContain('198.51.100.9');
        expect(alles).not.toContain('remoteAddress');
        expect(alles).not.toContain('install-77');
        expect(alles).not.toContain('incoming request');
    });

    test('loggt auch unerwartete Fehler ohne IP', async () => {
        const log = logZeilen();
        const dependencies = buildMemoryDependencies(createStatisticsMemoryStore(), () => new Date('2026-04-10T08:00:00Z'));
        const server = buildServer(
            buildTestConfig({ LOG_LEVEL: 'info', TRUST_PROXY_HOPS: '1' }),
            {
                ...dependencies,
                rawSnapshotsRepository: {
                    ...dependencies.rawSnapshotsRepository,
                    insert: async () => {
                        throw new Error('kaputt');
                    },
                },
            },
            log.stream,
        );

        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: { ...authHeader(), 'x-forwarded-for': CLIENT_IP },
            payload: createValidPayload(),
        });
        await server.close();

        expect(response.statusCode).toBe(500);
        const alles = log.zeilen.join('');
        expect(alles).toContain('Unhandled request error');
        expect(alles).not.toContain(CLIENT_IP);
        expect(alles).not.toContain('remoteAddress');
    });
});

describe('Speicherfrist (S-05)', () => {
    const teile = async (
        server: ReturnType<typeof buildServer>,
        jetzt: Date,
        overrides: Record<string, unknown> = {},
        secret?: string,
    ) =>
        server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers: authHeader(secret),
            payload: createValidPayload({
                source_data_as_of: jetzt.toISOString(),
                ...overrides,
            }),
        });

    test('Rohsnapshots und Sender verschwinden nach 14 Monaten, vorher nicht', async () => {
        const time = createMutableClock('2026-04-10T08:00:00Z');
        const store = createStatisticsMemoryStore();
        const dependencies = buildMemoryDependencies(store, time.clock);
        const server = buildServer(buildTestConfig(), dependencies);

        expect((await teile(server, time.now)).statusCode).toBe(204);
        const senderPseudonym = buildPseudonym('sender', 'install-77', 'test-secret');

        time.now = addUtcMonths(new Date('2026-04-10T08:00:00Z'), RETENTION_MONTHS - 1);
        expect(await dependencies.rawSnapshotsRepository.findBySender(senderPseudonym)).toHaveLength(1);
        expect(await dependencies.senderRepository.findByPseudonym(senderPseudonym)).not.toBeNull();

        time.now = addUtcMonths(new Date('2026-04-10T08:00:01Z'), RETENTION_MONTHS);
        expect(await dependencies.rawSnapshotsRepository.findBySender(senderPseudonym)).toHaveLength(0);
        expect(await dependencies.senderRepository.findByPseudonym(senderPseudonym)).toBeNull();
        expect(await dependencies.senderRepository.listActivity()).toHaveLength(0);

        await server.close();
    });

    test('eine spätere Sendung verlängert die Frist des Senders', async () => {
        const time = createMutableClock('2026-04-10T08:00:00Z');
        const dependencies = buildMemoryDependencies(createStatisticsMemoryStore(), time.clock);
        const server = buildServer(buildTestConfig(), dependencies);
        const senderPseudonym = buildPseudonym('sender', 'install-77', 'test-secret');

        await teile(server, time.now);
        time.now = new Date('2027-01-10T08:00:00Z');
        expect((await teile(server, time.now)).statusCode).toBe(204);

        time.now = new Date('2027-07-10T08:00:00Z');
        expect(await dependencies.senderRepository.findByPseudonym(senderPseudonym)).not.toBeNull();
        // Der erste Snapshot ist abgelaufen, der zweite nicht.
        expect(await dependencies.rawSnapshotsRepository.findBySender(senderPseudonym)).toHaveLength(1);

        await server.close();
    });

    test('die Frist deckt den Backfill der Monatsberichte ab', () => {
        // Ungünstigster Zeitpunkt ist das Monatsende: Dann liegt der früheste Backfill-Monat am weitesten zurück.
        for (const jetzt of ['2027-03-31T23:59:59Z', '2027-02-28T23:59:59Z', '2027-07-01T00:00:00Z']) {
            const now = new Date(jetzt);
            const fruehesterMonat = toMonth(subtractUtcMonths(monthStart(previousMonth(now)), REPORT_BACKFILL_MONTHS - 1));
            const stichtag = new Date(addUtcMonths(monthStart(fruehesterMonat), 1).getTime() - 1);
            const benoetigtAb = snapshotWindowStart(stichtag);

            expect(benoetigtAb.getTime()).toBeGreaterThanOrEqual(subtractUtcMonths(now, RETENTION_MONTHS).getTime());
        }
    });
});

describe('Auskunft und Löschung auf Anfrage (S-04)', () => {
    const aufbau = async () => {
        const time = createMutableClock('2026-04-10T08:00:00Z');
        const store = createStatisticsMemoryStore();
        const dependencies = buildMemoryDependencies(store, time.clock);
        const server = buildServer(buildTestConfig(), dependencies);
        const teile = (senderId: string, secret: string | undefined, mitglieder: number) =>
            server.inject({
                method: 'POST',
                url: '/snapshots/stamm',
                headers: authHeader(secret),
                payload: createValidPayload({
                    sender_id: senderId,
                    source_data_as_of: time.now.toISOString(),
                    gruppen: [gruppe('g-biber', 'biber', mitglieder)],
                }),
            });

        expect((await teile('install-a', undefined, 4)).statusCode).toBe(204);
        time.now = new Date('2026-04-11T08:00:00Z');
        expect((await teile('install-b', OTHER_SECRET, 7)).statusCode).toBe(204);

        return { time, store, dependencies, server };
    };

    test('Auskunft liefert nur die Daten der Installation, ohne Secret-Hash', async () => {
        const { dependencies, server } = await aufbau();

        const auskunft = await auskunftFuerInstallation(dependencies, ' install-a ', 'test-secret');

        expect(auskunft.sender_pseudonym).toBe(buildPseudonym('sender', 'install-a', 'test-secret'));
        expect(auskunft.sender?.created_at).toEqual(new Date('2026-04-10T08:00:00Z'));
        expect(auskunft.snapshots).toHaveLength(1);
        expect(auskunft.snapshots[0]?.gruppen[0]?.mitglieder?.gesamt).toBe(4);
        expect(JSON.stringify(auskunft)).not.toContain('secret_hash');

        await server.close();
    });

    test('Löschung entfernt Snapshots und Sender und baut den effektiven Stand neu auf', async () => {
        const { time, store, dependencies, server } = await aufbau();
        // install-a kennt den Stamm laenger und ist aktiv, deshalb zaehlen ihre Werte.
        const [vorher] = [...store.effectiveStates.values()];
        expect(vorher?.gruppen[0]?.wert?.mitglieder.gesamt).toBe(4);

        const ergebnis = await loescheInstallation(dependencies, 'install-a', 'test-secret', time.now);

        expect(ergebnis).toMatchObject({ geloeschte_snapshots: 1, sender_geloescht: true });
        expect(await auskunftFuerInstallation(dependencies, 'install-a', 'test-secret'))
            .toMatchObject({ sender: null, snapshots: [] });
        const [nachher] = [...store.effectiveStates.values()];
        expect(nachher?.gruppen[0]?.wert?.mitglieder.gesamt).toBe(7);
        expect(store.rawSnapshots).toHaveLength(1);

        await server.close();
    });

    test('unbekannte oder leere Installations-ID', async () => {
        const { time, dependencies, server } = await aufbau();

        expect(await loescheInstallation(dependencies, 'install-x', 'test-secret', time.now))
            .toMatchObject({ geloeschte_snapshots: 0, sender_geloescht: false });
        await expect(auskunftFuerInstallation(dependencies, '  ', 'test-secret')).rejects.toThrow('Installations-ID fehlt.');

        await server.close();
    });
});
