import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import { createStatisticsMemoryStore } from '../src/infra/memory/statisticsMemoryStore.js';
import { buildRawSnapshotDocument } from '../src/modules/stammesSnapshot/persistence.js';
import { pseudonymizeStammesSnapshot } from '../src/modules/stammesSnapshot/pseudonymize.js';
import {
    parseStammesSnapshotPayload,
    SUPPORTED_SCHEMA_VERSION,
} from '../src/modules/stammesSnapshot/schema.js';
import {
    authHeader,
    buildMemoryTestServer,
    createMutableClock,
    createValidPayload,
    fremdeGruppe,
    gruppe,
    OTHER_SECRET,
} from './support/fixtures.js';

const JETZT = new Date('2026-04-10T08:00:00Z');

describe('stammes snapshot ingest route', () => {
    const store = createStatisticsMemoryStore();
    const { server } = buildMemoryTestServer({ store });

    const postSnapshot = (payload: unknown, headers: Record<string, string> = authHeader()) =>
        server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            headers,
            payload: payload as Record<string, unknown>,
        });

    beforeEach(() => {
        store.rawSnapshots.length = 0;
        store.senders.clear();
        store.effectiveStates.clear();
        store.weeklyAggregates.clear();
    });

    beforeAll(async () => {
        await server.ready();
    });

    afterAll(async () => {
        await server.close();
    });

    test('accepts a valid stamm snapshot with 204 and stores it pseudonymized', async () => {
        const response = await postSnapshot(createValidPayload());

        expect(response.statusCode).toBe(204);
        expect(response.body).toBe('');
        expect(store.rawSnapshots).toHaveLength(1);
        const [stored] = store.rawSnapshots;
        expect(stored?.stamm_pseudonym).toMatch(/^stamm_[a-f0-9]{64}$/);
        expect(stored?.sender_pseudonym).toMatch(/^sender_[a-f0-9]{64}$/);
        expect(stored?.dv_id).toBe('dv-1');
        expect(stored?.bezirk_id).toBeNull();
        expect(stored?.received_at).toBeInstanceOf(Date);
        expect(JSON.stringify(stored)).not.toContain('stamm-123');
        expect(JSON.stringify(stored)).not.toContain('install-77');
        expect(JSON.stringify(stored)).not.toContain('g-biber');
    });

    test('registers the sender on first contact without publishing the aggregate', async () => {
        await postSnapshot(createValidPayload());

        const [sender] = [...store.senders.values()];
        expect(sender?.secret_hash).toMatch(/^[a-f0-9]{64}$/);
        expect(JSON.stringify(sender)).not.toContain('a'.repeat(64));
        expect(sender?.last_successful_send_at).toEqual(new Date('2026-04-10T08:00:00Z'));
        // Ins Aggregat kommt der Snapshot erst mit dem naechsten Nacht- oder Wochenlauf.
        expect(store.effectiveStates.size).toBe(0);
        expect(store.weeklyAggregates.size).toBe(0);
    });

    test('normalizes timestamps with offsets to UTC dates and ignores a client send time', async () => {
        await postSnapshot(createValidPayload({
            sent_at: '2026-04-09T20:30:00+02:00',
            source_data_as_of: '2026-04-09T19:00:00+01:00',
        }));

        expect(store.rawSnapshots[0]?.source_data_as_of).toEqual(new Date('2026-04-09T18:00:00Z'));
        expect(store.rawSnapshots[0]).not.toHaveProperty('sent_at');
    });

    test('treats a resent identical data state as idempotent success', async () => {
        await postSnapshot(createValidPayload());
        const response = await postSnapshot(createValidPayload());

        expect(response.statusCode).toBe(204);
        expect(store.rawSnapshots).toHaveLength(1);
    });

    test('rejects requests without sender credentials', async () => {
        const response = await postSnapshot(createValidPayload(), {});

        expect(response.statusCode).toBe(401);
        expect(response.json()).toEqual({
            error: {
                code: 'missing_sender_credentials',
                message: 'Sender credentials are missing',
            },
        });
        expect(store.rawSnapshots).toHaveLength(0);
    });

    test('rejects too short secrets', async () => {
        const response = await postSnapshot(createValidPayload(), { authorization: 'Bearer short' });

        expect(response.statusCode).toBe(401);
        expect(response.json().error.code).toBe('invalid_sender_credentials');
    });

    test('rejects a known sender id with a different secret', async () => {
        await postSnapshot(createValidPayload());
        const response = await postSnapshot(
            createValidPayload({ source_data_as_of: '2026-04-09T18:10:00Z' }),
            authHeader(OTHER_SECRET),
        );

        expect(response.statusCode).toBe(401);
        expect(response.json().error.code).toBe('invalid_sender_credentials');
        expect(store.rawSnapshots).toHaveLength(1);
    });

    test('rejects unsupported schema version', async () => {
        const response = await postSnapshot(createValidPayload({ schema_version: '2026-04-01' }));

        expect(response.statusCode).toBe(400);
        expect(response.json()).toEqual({
            error: {
                code: 'unsupported_schema_version',
                message: 'Snapshot payload is invalid',
                fields: ['schema_version'],
            },
        });
        expect(store.rawSnapshots).toHaveLength(0);
    });

    test('rejects missing required metadata', async () => {
        const payload: Record<string, unknown> = createValidPayload();
        delete payload.stamm_id;

        const response = await postSnapshot(payload);

        expect(response.statusCode).toBe(400);
        expect(response.json()).toEqual({
            error: {
                code: 'missing_required_field',
                message: 'Snapshot payload is invalid',
                fields: ['stamm_id'],
            },
        });
    });

    test('accepts snapshots without dv and bezirk', async () => {
        const payload: Record<string, unknown> = createValidPayload();
        delete payload.dv_id;

        const response = await postSnapshot(payload);

        expect(response.statusCode).toBe(204);
        expect(store.rawSnapshots[0]?.dv_id).toBeNull();
    });

    test('accepts fractional seconds with microsecond precision', async () => {
        const response = await postSnapshot(createValidPayload({
            source_data_as_of: '2026-04-09T18:00:00.123456789Z',
        }));

        expect(response.statusCode).toBe(204);
        expect(store.rawSnapshots[0]?.source_data_as_of).toEqual(new Date('2026-04-09T18:00:00.123Z'));
    });

    test('rejects impossible calendar dates', async () => {
        const response = await postSnapshot(createValidPayload({ source_data_as_of: '2026-13-45T18:00:00Z' }));

        expect(response.statusCode).toBe(400);
        expect(response.json().error).toMatchObject({
            code: 'invalid_datetime',
            fields: ['source_data_as_of'],
        });
    });

    test.each([
        ['more than a day in the future', '2026-04-11T08:00:01Z'],
        ['older than seven days plus a day of clock skew', '2026-04-02T07:59:59Z'],
    ])('rejects a data state %s', async (_name, sourceDataAsOf) => {
        const response = await postSnapshot(createValidPayload({ source_data_as_of: sourceDataAsOf }));

        expect(response.statusCode).toBe(400);
        expect(response.json().error).toMatchObject({
            code: 'invalid_datetime',
            fields: ['source_data_as_of'],
        });
    });

    test.each([
        ['a day in the future', '2026-04-11T08:00:00Z'],
        ['eight days old', '2026-04-02T08:00:00Z'],
    ])('accepts a data state %s', async (_name, sourceDataAsOf) => {
        expect((await postSnapshot(createValidPayload({ source_data_as_of: sourceDataAsOf }))).statusCode).toBe(204);
    });

    test('rejects a snapshot without members in any covered group', async () => {
        const response = await postSnapshot(createValidPayload({
            gruppen: [gruppe('g1', 'biber', 0), gruppe('g2', 'rover', null)],
        }));

        expect(response.statusCode).toBe(400);
        expect(response.json()).toEqual({
            error: {
                code: 'invalid_stamm_plausibility',
                message: 'Snapshot payload is invalid',
                fields: ['gruppen'],
            },
        });
    });

    test.each([
        ['a stamm snapshot with an uncovered group', 'stamm', [gruppe('g1', 'biber', 5), fremdeGruppe('g2', 'rover')]],
        ['duplicate group ids', 'stamm', [gruppe('g1', 'biber', 5), gruppe('g1', 'rover', 3)]],
    ])('rejects %s as invalid coverage', async (_name, abdeckung, gruppen) => {
        const response = await postSnapshot(createValidPayload({ abdeckung, gruppen }));

        expect(response.statusCode).toBe(400);
        expect(response.json().error).toMatchObject({ code: 'invalid_coverage', fields: ['gruppen'] });
    });

    test('accepts a group snapshot without covered groups as participation without values', async () => {
        const response = await postSnapshot(createValidPayload({
            abdeckung: 'gruppen',
            gruppen: [fremdeGruppe('g1', 'biber'), fremdeGruppe('g2', 'rover')],
        }));

        expect(response.statusCode).toBe(204);
    });

    test('rejects missing coverage, groups and stamm metrics', async () => {
        const ohneAbdeckung: Record<string, unknown> = createValidPayload();
        delete ohneAbdeckung.abdeckung;
        const ohneGruppen: Record<string, unknown> = createValidPayload();
        delete ohneGruppen.gruppen;
        const ohneMetrics: Record<string, unknown> = createValidPayload();
        delete ohneMetrics.metrics;

        expect((await postSnapshot(ohneAbdeckung)).json().error).toMatchObject({ code: 'missing_required_field', fields: ['abdeckung'] });
        expect((await postSnapshot(ohneGruppen)).json().error).toMatchObject({ code: 'missing_required_field', fields: ['gruppen'] });
        expect((await postSnapshot(ohneMetrics)).json().error).toMatchObject({ code: 'missing_required_field', fields: ['metrics'] });
    });

    test('rejects unknown stufen and coverage values', async () => {
        expect((await postSnapshot(createValidPayload({ gruppen: [gruppe('g1', 'leitung', 5)] }))).json().error)
            .toMatchObject({ code: 'invalid_snapshot_payload', fields: ['gruppen.0.stufe'] });
        expect((await postSnapshot(createValidPayload({ abdeckung: 'bezirk' }))).json().error)
            .toMatchObject({ code: 'invalid_snapshot_payload', fields: ['abdeckung'] });
    });
});

describe('first_seen_at', () => {
    test('carries the first contact of a sender with a stamm forward', async () => {
        const time = createMutableClock('2026-04-10T08:00:00Z');
        const { server, store } = buildMemoryTestServer({ clock: time.clock });
        const send = (overrides: Record<string, unknown>) =>
            server.inject({ method: 'POST', url: '/snapshots/stamm', headers: authHeader(), payload: createValidPayload(overrides) });

        await send({});
        time.now = new Date('2026-04-20T08:00:00Z');
        await send({ source_data_as_of: '2026-04-20T07:00:00Z' });
        await send({ source_data_as_of: '2026-04-20T07:30:00Z', stamm_id: 'anderer-stamm' });

        expect(store.rawSnapshots.map((document) => document.first_seen_at)).toEqual([
            new Date('2026-04-10T08:00:00Z'),
            new Date('2026-04-10T08:00:00Z'),
            new Date('2026-04-20T08:00:00Z'),
        ]);
        await server.close();
    });
});

describe('parseStammesSnapshotPayload', () => {
    test('normalizes missing known fields to null and strips unknown fields recursively', () => {
        const parsed = parseStammesSnapshotPayload({
            ...createValidPayload(),
            bezirk_id: undefined,
            unknown_root: 'ignored',
            gruppen: [{ ...gruppe('g1', 'biber', 5), unknown_group_field: 1 }],
            metrics: {
                leitende: {
                    gesamt: 3,
                    unknown_nested: 999,
                },
                unknown_metric: 12,
            },
        }, JETZT);

        const leer = { gesamt: null, maennlich: null, weiblich: null, divers: null, geschlecht_unbekannt: null };
        expect(parsed).toEqual({
            schema_version: SUPPORTED_SCHEMA_VERSION,
            stamm_id: 'stamm-123',
            dv_id: 'dv-1',
            bezirk_id: null,
            sender_id: 'install-77',
            source_data_as_of: '2026-04-09T18:00:00Z',
            abdeckung: 'stamm',
            gruppen: [{
                gruppe_id: 'g1',
                stufe: 'biber',
                abgedeckt: true,
                mitglieder: { ...leer, gesamt: 5 },
                leitende: { ...leer, gesamt: 1 },
            }],
            metrics: {
                aktive_mitglieder: {
                    gesamt: null,
                    normaler_beitrag: null,
                    familienermaessigter_beitrag: null,
                    sozialermaessigter_beitrag: null,
                },
                passive_mitglieder: null,
                leitende: {
                    gesamt: 3,
                    unter_21: null,
                    von_21_bis_30: null,
                    von_31_bis_40: null,
                    von_41_bis_50: null,
                    von_51_bis_60: null,
                    ueber_60: null,
                },
                nicht_leitende_erwachsene: null,
                stammesvorstand: null,
                kuraten: null,
            },
        });
    });

    test('drops stamm metrics of a group snapshot and counts of uncovered groups', () => {
        const parsed = parseStammesSnapshotPayload(createValidPayload({
            abdeckung: 'gruppen',
            gruppen: [gruppe('g1', 'woelflinge', 12), { ...fremdeGruppe('g2', 'woelflinge'), mitglieder: { gesamt: 99 } }],
            metrics: { leitende: { gesamt: 3 } },
        }), JETZT);

        expect(parsed.metrics).toBeNull();
        expect(parsed.gruppen[1]).toEqual({ gruppe_id: 'g2', stufe: 'woelflinge', abgedeckt: false, mitglieder: null, leitende: null });
    });

    test('rejects invalid metric values', () => {
        try {
            parseStammesSnapshotPayload({
                ...createValidPayload(),
                gruppen: [gruppe('g1', 'biber', -1)],
            }, JETZT);

            throw new Error('Expected validation error');
        } catch (error) {
            expect(error).toMatchObject({
                code: 'invalid_metric_value',
                fields: ['gruppen.0.mitglieder.gesamt'],
            });
        }
    });
});

describe('pseudonymizeStammesSnapshot', () => {
    test('creates stable pseudonyms and keeps dv and bezirk readable', () => {
        const snapshot = parseStammesSnapshotPayload({
            ...createValidPayload(),
            bezirk_id: 'bezirk-5',
        }, JETZT);

        const firstResult = pseudonymizeStammesSnapshot(snapshot, 'test-secret');
        const secondResult = pseudonymizeStammesSnapshot(snapshot, 'test-secret');

        expect(firstResult).toEqual(secondResult);
        expect(firstResult.stamm_pseudonym).toMatch(/^stamm_[a-f0-9]{64}$/);
        expect(firstResult.sender_pseudonym).toMatch(/^sender_[a-f0-9]{64}$/);
        expect(firstResult.dv_id).toBe('dv-1');
        expect(firstResult.bezirk_id).toBe('bezirk-5');
        expect(firstResult.source_data_as_of).toEqual(new Date('2026-04-09T18:00:00Z'));
        expect(firstResult.gruppen[0]?.gruppe_pseudonym).toMatch(/^gruppe_[a-f0-9]{64}$/);
        expect(JSON.stringify(firstResult)).not.toContain('stamm-123');
        expect(JSON.stringify(firstResult)).not.toContain('install-77');
        expect(JSON.stringify(firstResult)).not.toContain('g-biber');
    });

    test('separates pseudonym scopes and secrets', () => {
        const snapshot = parseStammesSnapshotPayload({
            ...createValidPayload(),
            stamm_id: 'same-id',
            sender_id: 'same-id',
        }, JETZT);

        const firstSecretResult = pseudonymizeStammesSnapshot(snapshot, 'first-secret');
        const secondSecretResult = pseudonymizeStammesSnapshot(snapshot, 'second-secret');

        expect(firstSecretResult.stamm_pseudonym).not.toBe(firstSecretResult.sender_pseudonym);
        expect(firstSecretResult.stamm_pseudonym).not.toBe(secondSecretResult.stamm_pseudonym);
        expect(firstSecretResult.sender_pseudonym).not.toBe(secondSecretResult.sender_pseudonym);
    });
});

describe('buildRawSnapshotDocument', () => {
    test('uses received_at as first_seen_at on first contact and keeps a known one', () => {
        const pseudonymizedSnapshot = pseudonymizeStammesSnapshot(parseStammesSnapshotPayload(createValidPayload(), JETZT), 'test-secret');

        expect(buildRawSnapshotDocument(pseudonymizedSnapshot, new Date('2026-04-09T19:00:00Z')).first_seen_at)
            .toEqual(new Date('2026-04-09T19:00:00Z'));
        expect(buildRawSnapshotDocument(pseudonymizedSnapshot, new Date('2026-04-09T19:00:00Z'), new Date('2026-01-01T00:00:00Z')).first_seen_at)
            .toEqual(new Date('2026-01-01T00:00:00Z'));
    });

    test('adds received_at to the pseudonymized snapshot document', () => {
        const snapshot = parseStammesSnapshotPayload(createValidPayload(), JETZT);
        const pseudonymizedSnapshot = pseudonymizeStammesSnapshot(snapshot, 'test-secret');
        const document = buildRawSnapshotDocument(
            pseudonymizedSnapshot,
            new Date('2026-04-09T19:00:00Z'),
        );

        expect(document).toMatchObject({
            stamm_pseudonym: pseudonymizedSnapshot.stamm_pseudonym,
            sender_pseudonym: pseudonymizedSnapshot.sender_pseudonym,
            received_at: new Date('2026-04-09T19:00:00Z'),
        });
    });
});
