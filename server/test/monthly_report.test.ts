import { describe, expect, test } from 'vitest';

import { buildMemoryDependencies, createStatisticsMemoryStore } from '../src/infra/memory/statisticsMemoryStore.js';
import {
    computeReportFigures,
    formatMonthlyReport,
    formatTelegramMessage,
    previousMonth,
    REPORT_BACKFILL_MONTHS,
    runMonthlyReportIfDue,
} from '../src/modules/report/report.js';
import { buildRawSnapshotDocument, type RawSnapshotDocument } from '../src/modules/stammesSnapshot/persistence.js';
import { pseudonymizeStammesSnapshot } from '../src/modules/stammesSnapshot/pseudonymize.js';
import { parseStammesSnapshotPayload } from '../src/modules/stammesSnapshot/schema.js';
import { createValidPayload, fremdeGruppe, gruppe } from './support/fixtures.js';

const snapshot = (overrides: Record<string, unknown>, receivedAt: string): RawSnapshotDocument =>
    buildRawSnapshotDocument(
        pseudonymizeStammesSnapshot(parseStammesSnapshotPayload(createValidPayload(overrides), new Date(receivedAt)), 'test-secret'),
        new Date(receivedAt),
    );

// Stamm A: vollstaendig von P4, dazu eine neuere Gruppen-Leitung fuer Meute 1.
// Stamm B: nur eine Meute von zweien bekannt. Stamm C: nur im Vormonat.
const rohdaten = (): RawSnapshotDocument[] => [
    snapshot({
        stamm_id: 'A', sender_id: 'P4', dv_id: 'dv-1', bezirk_id: 'bz-1',
        source_data_as_of: '2026-05-20T00:00:00Z', sent_at: '2026-05-20T01:00:00Z',
        gruppen: [gruppe('a-m1', 'woelflinge', 10), gruppe('a-t1', 'jungpfadfinder', 8)],
    }, '2026-05-20T01:00:00Z'),
    snapshot({
        stamm_id: 'A', sender_id: 'P1', dv_id: 'dv-1', bezirk_id: 'bz-1', abdeckung: 'gruppen',
        source_data_as_of: '2026-06-05T00:00:00Z', sent_at: '2026-06-05T01:00:00Z',
        gruppen: [gruppe('a-m1', 'woelflinge', 12), fremdeGruppe('a-t1', 'jungpfadfinder')],
    }, '2026-06-05T01:00:00Z'),
    snapshot({
        stamm_id: 'B', sender_id: 'L1', dv_id: 'dv-1', abdeckung: 'gruppen',
        source_data_as_of: '2026-06-10T00:00:00Z', sent_at: '2026-06-10T01:00:00Z',
        gruppen: [gruppe('b-m1', 'woelflinge', 9), fremdeGruppe('b-m2', 'woelflinge')],
    }, '2026-06-10T01:00:00Z'),
    snapshot({
        stamm_id: 'C', sender_id: 'S1', dv_id: 'dv-2',
        source_data_as_of: '2026-04-15T00:00:00Z', sent_at: '2026-04-15T01:00:00Z',
        gruppen: [gruppe('c-r1', 'rover', 6)],
    }, '2026-04-15T01:00:00Z'),
];

const senders = [
    { created_at: new Date('2026-04-15T01:00:00Z'), last_successful_send_at: new Date('2026-04-15T01:00:00Z') },
    { created_at: new Date('2026-05-20T01:00:00Z'), last_successful_send_at: new Date('2026-05-20T01:00:00Z') },
    { created_at: new Date('2026-06-05T01:00:00Z'), last_successful_send_at: new Date('2026-06-05T01:00:00Z') },
    { created_at: new Date('2026-06-10T01:00:00Z'), last_successful_send_at: new Date('2026-06-10T01:00:00Z') },
];

describe('computeReportFigures', () => {
    test('counts installations, stamms, groups and regions at the end of the month', () => {
        const figures = computeReportFigures('2026-06', rohdaten(), senders);

        expect(figures.stichtag).toEqual(new Date('2026-06-30T23:59:59.999Z'));
        expect(figures.installationen).toEqual({ aktiv: 2, neu: 2, gesamt: 4 });
        // C liegt am 30.06. ausserhalb des Zwei-Monats-Fensters.
        expect(figures.staemme).toEqual({
            teilnehmend: 2, vollstaendig: 0, nur_gruppen: 1, gemischt: 1, mehrere_sender: 1, ohne_werte: 0,
        });
        expect(figures.gruppen).toMatchObject({
            mit_wert: 3,
            mehrfach_abgedeckt: 1,
            verworfene_werte: 1,
            unvollstaendige_stufen: 1,
        });
        expect(figures.gruppen.je_stufe).toMatchObject({ woelflinge: 2, jungpfadfinder: 1, rover: 0 });
        expect(figures.staemme_je_dv).toEqual({ 'dv-1': 2 });
        expect(figures.staemme_je_bezirk).toEqual({ 'bz-1': 1, unbekannt: 1 });
    });

    test('counts stamms with only participation without values separately', () => {
        const figures = computeReportFigures('2026-06', [
            ...rohdaten(),
            snapshot({
                stamm_id: 'D', sender_id: 'L2', abdeckung: 'gruppen',
                source_data_as_of: '2026-06-12T00:00:00Z', sent_at: '2026-06-12T01:00:00Z',
                gruppen: [fremdeGruppe('d-m1', 'woelflinge')],
            }, '2026-06-12T01:00:00Z'),
        ], senders);

        expect(figures.staemme).toMatchObject({ teilnehmend: 2, ohne_werte: 1 });
        expect(figures.installationen.aktiv).toBe(3);
    });

    test('only uses snapshots received until the end of the month', () => {
        const figures = computeReportFigures('2026-05', rohdaten(), senders);

        expect(figures.installationen).toEqual({ aktiv: 1, neu: 1, gesamt: 2 });
        expect(figures.staemme).toMatchObject({ teilnehmend: 2, vollstaendig: 2 });
        expect(figures.staemme_je_dv).toEqual({ 'dv-1': 1, 'dv-2': 1 });
    });
});

describe('formatMonthlyReport', () => {
    test('shows current values with the previous month and marks regions above the minimum', () => {
        const message = formatMonthlyReport(
            computeReportFigures('2026-06', rohdaten(), senders),
            computeReportFigures('2026-05', rohdaten(), senders),
            2,
        );

        expect(message.subject).toBe('NaMi-Statistik: Monatsreport 2026-06 – 2 Stämme, 2 aktive Installationen');
        expect(message.text).toContain('Stichtag 30.06.2026. Werte in Klammern: Vormonat (2026-05).');
        expect(message.text).toMatch(/teilnehmend:\s+2 {2}\(2\)/);
        expect(message.text).toMatch(/dv-1:\s+2 {2}\(1\) ✓/);
        expect(message.text).toContain('Stämme je DV (1 mit mindestens 2 Stämmen)');
        expect(message.text).not.toContain('stamm_');
    });
});

describe('formatTelegramMessage', () => {
    test('summarizes the month briefly and links the admin view', () => {
        const text = formatTelegramMessage(
            computeReportFigures('2026-06', rohdaten(), senders),
            computeReportFigures('2026-05', rohdaten(), senders),
            1,
            'https://namiapp.example.org/admin',
        );

        expect(text).toContain('NaMi-Statistik 2026-06');
        expect(text).toContain('Stämme: 2 (2) – vollständig 0, nur Gruppen 1, gemischt 1');
        expect(text).toContain('Aktive Installationen: 2 (1), neu 2');
        expect(text).toContain('DVs mit ≥ 1 Stämmen: 1, Bezirke: 1');
        expect(text.endsWith('https://namiapp.example.org/admin')).toBe(true);
        expect(text.length).toBeLessThan(4096);
    });
});

describe('computeReportFigures for the running month', () => {
    test('counts only snapshots received until now', () => {
        const figures = computeReportFigures('2026-06', rohdaten(), senders, new Date('2026-06-07T00:00:00Z'));

        expect(figures.stichtag).toEqual(new Date('2026-06-07T00:00:00Z'));
        expect(figures.installationen).toEqual({ aktiv: 1, neu: 1, gesamt: 3 });
        expect(figures.staemme.teilnehmend).toBe(2);
    });
});

describe('runMonthlyReportIfDue', () => {
    const setup = () => {
        const store = createStatisticsMemoryStore();
        store.rawSnapshots.push(...rohdaten());
        const dependencies = buildMemoryDependencies(store);
        const sent: string[] = [];
        const notifier = { send: async (text: string) => { sent.push(text); } };
        return { store, dependencies, sent, notifier };
    };
    const options = { minStammCount: 5, adminUrl: null };

    test('stores the previous month, backfills older months and notifies once', async () => {
        const { store, dependencies, sent, notifier } = setup();

        expect(await runMonthlyReportIfDue(dependencies, notifier, options, new Date('2026-07-01T06:00:00Z'))).toBe('2026-06');
        expect(await runMonthlyReportIfDue(dependencies, notifier, options, new Date('2026-07-15T06:00:00Z'))).toBeNull();

        expect(sent).toHaveLength(1);
        expect(sent[0]).toContain('2026-06');
        // Rueckwirkend nur Monate mit Daten (ab April), nicht die leeren davor.
        expect([...store.monthlyReports.keys()].sort()).toEqual(['2026-04', '2026-05', '2026-06']);
        expect(store.monthlyReports.size).toBeLessThanOrEqual(REPORT_BACKFILL_MONTHS);
        expect(store.monthlyReports.get('2026-06')?.figures.staemme.teilnehmend).toBe(2);
        expect(store.monthlyReports.get('2026-05')?.notified_at).not.toBeNull();

        expect(await runMonthlyReportIfDue(dependencies, notifier, options, new Date('2026-08-01T00:00:00Z'))).toBe('2026-07');
        expect(store.monthlyReports.has('2026-07')).toBe(true);
    });

    test('stores reports without notifier', async () => {
        const { store, dependencies } = setup();

        expect(await runMonthlyReportIfDue(dependencies, null, options, new Date('2026-07-01T06:00:00Z'))).toBeNull();
        expect(store.monthlyReports.get('2026-06')?.notified_at).toBeNull();
    });

    test('retries the notification after a failure', async () => {
        const { store, dependencies, sent, notifier } = setup();
        const kaputt = { send: async () => { throw new Error('telegram down'); } };

        await expect(runMonthlyReportIfDue(dependencies, kaputt, options, new Date('2026-07-01T06:00:00Z'))).rejects.toThrow('telegram down');
        expect(store.monthlyReports.get('2026-06')?.notified_at).toBeNull();

        expect(await runMonthlyReportIfDue(dependencies, notifier, options, new Date('2026-07-01T12:00:00Z'))).toBe('2026-06');
        expect(sent).toHaveLength(1);
    });

    test('derives the previous month across year boundaries', () => {
        expect(previousMonth(new Date('2027-01-01T00:00:00Z'))).toBe('2026-12');
        expect(previousMonth(new Date('2026-03-31T23:59:59Z'))).toBe('2026-02');
    });
});
