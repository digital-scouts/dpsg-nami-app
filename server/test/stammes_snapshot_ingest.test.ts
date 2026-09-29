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
    createValidPayload,
    OTHER_SECRET,
} from './support/fixtures.js';

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
    });

    test('registers the sender on first contact and derives effective state and aggregate', async () => {
        await postSnapshot(createValidPayload());

        const [sender] = [...store.senders.values()];
        expect(sender?.secret_hash).toMatch(/^[a-f0-9]{64}$/);
        expect(JSON.stringify(sender)).not.toContain('a'.repeat(64));
        expect(sender?.last_successful_send_at).toEqual(new Date('2026-04-10T08:00:00Z'));
        expect(store.effectiveStates.size).toBe(1);
        expect(store.weeklyAggregates.size).toBe(1);
    });

    test('normalizes timestamps with offsets to UTC dates', async () => {
        await postSnapshot(createValidPayload({
            sent_at: '2026-04-09T20:30:00+02:00',
            source_data_as_of: '2026-04-09T19:00:00+01:00',
        }));

        expect(store.rawSnapshots[0]?.sent_at).toEqual(new Date('2026-04-09T18:30:00Z'));
        expect(store.rawSnapshots[0]?.source_data_as_of).toEqual(new Date('2026-04-09T18:00:00Z'));
    });

    test('treats a resent identical data state as idempotent success', async () => {
        await postSnapshot(createValidPayload());
        const response = await postSnapshot(createValidPayload({ sent_at: '2026-04-09T19:30:00Z' }));

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
        const response = await postSnapshot(createValidPayload({ schema_version: '2025-01-01' }));

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
            sent_at: '2026-04-09T18:30:00.123456Z',
            source_data_as_of: '2026-04-09T18:00:00.123456789Z',
        }));

        expect(response.statusCode).toBe(204);
        expect(store.rawSnapshots[0]?.sent_at).toEqual(new Date('2026-04-09T18:30:00.123Z'));
    });

    test('rejects impossible calendar dates', async () => {
        const response = await postSnapshot(createValidPayload({ source_data_as_of: '2026-13-45T18:00:00Z' }));

        expect(response.statusCode).toBe(400);
        expect(response.json().error).toMatchObject({
            code: 'invalid_datetime',
            fields: ['source_data_as_of'],
        });
    });

    test('rejects timestamps too far in the future', async () => {
        const response = await postSnapshot(createValidPayload({ source_data_as_of: '2026-05-01T00:00:00Z' }));

        expect(response.statusCode).toBe(400);
        expect(response.json().error).toMatchObject({
            code: 'invalid_datetime',
            fields: ['source_data_as_of'],
        });
    });

    test('rejects invalid stamm plausibility when all core levels are empty', async () => {
        const response = await postSnapshot(createValidPayload({
            metrics: {
                biber: { gesamt: 0 },
                woelflinge: { gesamt: null },
                jungpfadfinder: { gesamt: null },
                pfadfinder: { gesamt: 0 },
                rover: { gesamt: null },
            },
        }));

        expect(response.statusCode).toBe(400);
        expect(response.json()).toEqual({
            error: {
                code: 'invalid_stamm_plausibility',
                message: 'Snapshot payload is invalid',
                fields: [
                    'metrics.biber.gesamt',
                    'metrics.woelflinge.gesamt',
                    'metrics.jungpfadfinder.gesamt',
                    'metrics.pfadfinder.gesamt',
                    'metrics.rover.gesamt',
                ],
            },
        });
    });
});

describe('parseStammesSnapshotPayload', () => {
    test('normalizes missing known fields to null and strips unknown fields recursively', () => {
        const parsed = parseStammesSnapshotPayload({
            ...createValidPayload(),
            bezirk_id: undefined,
            unknown_root: 'ignored',
            metrics: {
                biber: {
                    gesamt: 5,
                    unknown_nested: 999,
                },
                unknown_metric: 12,
            },
        });

        expect(parsed).toEqual({
            schema_version: SUPPORTED_SCHEMA_VERSION,
            stamm_id: 'stamm-123',
            dv_id: 'dv-1',
            bezirk_id: null,
            sender_id: 'install-77',
            sent_at: '2026-04-09T18:30:00Z',
            source_data_as_of: '2026-04-09T18:00:00Z',
            metrics: {
                aktive_mitglieder: {
                    gesamt: null,
                    normaler_beitrag: null,
                    familienermaessigter_beitrag: null,
                    sozialermaessigter_beitrag: null,
                },
                passive_mitglieder: null,
                biber: {
                    gesamt: 5,
                    maennlich: null,
                    weiblich: null,
                    divers: null,
                    geschlecht_unbekannt: null,
                },
                woelflinge: {
                    gesamt: null,
                    maennlich: null,
                    weiblich: null,
                    divers: null,
                    geschlecht_unbekannt: null,
                },
                jungpfadfinder: {
                    gesamt: null,
                    maennlich: null,
                    weiblich: null,
                    divers: null,
                    geschlecht_unbekannt: null,
                },
                pfadfinder: {
                    gesamt: null,
                    maennlich: null,
                    weiblich: null,
                    divers: null,
                    geschlecht_unbekannt: null,
                },
                rover: {
                    gesamt: null,
                    maennlich: null,
                    weiblich: null,
                    divers: null,
                    geschlecht_unbekannt: null,
                },
                leitende: {
                    gesamt: null,
                    unter_21: null,
                    von_21_bis_30: null,
                    von_31_bis_40: null,
                    von_41_bis_50: null,
                    von_51_bis_60: null,
                    ueber_60: null,
                },
                leitende_biber: {
                    gesamt: null,
                    maennlich: null,
                    weiblich: null,
                    divers: null,
                    geschlecht_unbekannt: null,
                },
                leitende_woelflinge: {
                    gesamt: null,
                    maennlich: null,
                    weiblich: null,
                    divers: null,
                    geschlecht_unbekannt: null,
                },
                leitende_jungpfadfinder: {
                    gesamt: null,
                    maennlich: null,
                    weiblich: null,
                    divers: null,
                    geschlecht_unbekannt: null,
                },
                leitende_pfadfinder: {
                    gesamt: null,
                    maennlich: null,
                    weiblich: null,
                    divers: null,
                    geschlecht_unbekannt: null,
                },
                leitende_rover: {
                    gesamt: null,
                    maennlich: null,
                    weiblich: null,
                    divers: null,
                    geschlecht_unbekannt: null,
                },
                nicht_leitende_erwachsene: null,
                stammesvorstand: null,
                kuraten: null,
            },
        });
    });

    test('rejects invalid metric values', () => {
        try {
            parseStammesSnapshotPayload({
                ...createValidPayload(),
                metrics: {
                    biber: {
                        gesamt: -1,
                    },
                },
            });

            throw new Error('Expected validation error');
        } catch (error) {
            expect(error).toMatchObject({
                code: 'invalid_metric_value',
                fields: ['metrics.biber.gesamt'],
            });
        }
    });
});

describe('pseudonymizeStammesSnapshot', () => {
    test('creates stable pseudonyms and keeps dv and bezirk readable', () => {
        const snapshot = parseStammesSnapshotPayload({
            ...createValidPayload(),
            bezirk_id: 'bezirk-5',
        });

        const firstResult = pseudonymizeStammesSnapshot(snapshot, 'test-secret');
        const secondResult = pseudonymizeStammesSnapshot(snapshot, 'test-secret');

        expect(firstResult).toEqual(secondResult);
        expect(firstResult.stamm_pseudonym).toMatch(/^stamm_[a-f0-9]{64}$/);
        expect(firstResult.sender_pseudonym).toMatch(/^sender_[a-f0-9]{64}$/);
        expect(firstResult.dv_id).toBe('dv-1');
        expect(firstResult.bezirk_id).toBe('bezirk-5');
        expect(firstResult.sent_at).toEqual(new Date('2026-04-09T18:30:00Z'));
        expect(JSON.stringify(firstResult)).not.toContain('stamm-123');
        expect(JSON.stringify(firstResult)).not.toContain('install-77');
    });

    test('separates pseudonym scopes and secrets', () => {
        const snapshot = parseStammesSnapshotPayload({
            ...createValidPayload(),
            stamm_id: 'same-id',
            sender_id: 'same-id',
        });

        const firstSecretResult = pseudonymizeStammesSnapshot(snapshot, 'first-secret');
        const secondSecretResult = pseudonymizeStammesSnapshot(snapshot, 'second-secret');

        expect(firstSecretResult.stamm_pseudonym).not.toBe(firstSecretResult.sender_pseudonym);
        expect(firstSecretResult.stamm_pseudonym).not.toBe(secondSecretResult.stamm_pseudonym);
        expect(firstSecretResult.sender_pseudonym).not.toBe(secondSecretResult.sender_pseudonym);
    });
});

describe('buildRawSnapshotDocument', () => {
    test('adds received_at to the pseudonymized snapshot document', () => {
        const snapshot = parseStammesSnapshotPayload(createValidPayload());
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
