import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import { buildServer } from '../src/app/buildServer.js';
import { loadConfig } from '../src/app/config.js';
import { initializeStatisticsPersistence, statisticsCollectionNames } from '../src/infra/mongodb/statisticsPersistence.js';
import { buildRawSnapshotDocument, type RawSnapshotDocument } from '../src/modules/stammesSnapshot/persistence.js';
import { pseudonymizeStammesSnapshot } from '../src/modules/stammesSnapshot/pseudonymize.js';
import {
    parseStammesSnapshotPayload,
    SUPPORTED_SCHEMA_VERSION,
} from '../src/modules/stammesSnapshot/schema.js';

const createValidPayload = () => ({
    schema_version: SUPPORTED_SCHEMA_VERSION,
    stamm_id: 'stamm-123',
    dv_id: 'dv-1',
    sender_id: 'person-77',
    sent_at: '2026-04-09T18:30:00Z',
    source_data_as_of: '2026-04-09T18:00:00Z',
    metrics: {
        biber: {
            gesamt: 5,
        },
    },
});

describe('stammes snapshot ingest route', () => {
    const insertedRawSnapshots: RawSnapshotDocument[] = [];
    const server = buildServer(
        loadConfig({
            NODE_ENV: 'test',
            LOG_LEVEL: 'error',
            PSEUDONYMIZATION_SECRET: 'test-secret',
        }),
        {
            rawSnapshotsRepository: {
                insert: async (document) => {
                    insertedRawSnapshots.push(document);
                },
            },
        },
    );

    beforeEach(() => {
        insertedRawSnapshots.length = 0;
    });

    beforeAll(async () => {
        await server.ready();
    });

    afterAll(async () => {
        await server.close();
    });

    test('accepts a valid stamm snapshot with 204', async () => {
        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            payload: createValidPayload(),
        });

        expect(response.statusCode).toBe(204);
        expect(response.body).toBe('');
        expect(insertedRawSnapshots).toHaveLength(1);
        expect(insertedRawSnapshots[0]?.stamm_pseudonym).toMatch(/^stamm_[a-f0-9]{64}$/);
        expect(insertedRawSnapshots[0]?.sender_pseudonym).toMatch(/^sender_[a-f0-9]{64}$/);
        expect(insertedRawSnapshots[0]?.dv_id).toBe('dv-1');
        expect(insertedRawSnapshots[0]?.bezirk_id).toBeNull();
        expect(insertedRawSnapshots[0]?.received_at).toMatch(/^\d{4}-\d{2}-\d{2}T/);
        expect(JSON.stringify(insertedRawSnapshots[0])).not.toContain('stamm-123');
        expect(JSON.stringify(insertedRawSnapshots[0])).not.toContain('person-77');
    });

    test('rejects unsupported schema version', async () => {
        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            payload: {
                ...createValidPayload(),
                schema_version: '2025-01-01',
            },
        });

        expect(response.statusCode).toBe(400);
        expect(response.json()).toEqual({
            error: {
                code: 'unsupported_schema_version',
                message: 'Snapshot payload is invalid',
                fields: ['schema_version'],
            },
        });
        expect(insertedRawSnapshots).toHaveLength(0);
    });

    test('rejects missing required metadata', async () => {
        const payload = createValidPayload();
        delete (payload as Partial<typeof payload>).dv_id;

        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            payload,
        });

        expect(response.statusCode).toBe(400);
        expect(response.json()).toEqual({
            error: {
                code: 'missing_required_field',
                message: 'Snapshot payload is invalid',
                fields: ['dv_id'],
            },
        });
    });

    test('rejects invalid stamm plausibility when all core levels are empty', async () => {
        const response = await server.inject({
            method: 'POST',
            url: '/snapshots/stamm',
            payload: {
                ...createValidPayload(),
                metrics: {
                    biber: { gesamt: 0 },
                    woelflinge: { gesamt: null },
                    jungpfadfinder: { gesamt: null },
                    pfadfinder: { gesamt: 0 },
                    rover: { gesamt: null },
                },
            },
        });

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
            sender_id: 'person-77',
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
        expect(JSON.stringify(firstResult)).not.toContain('stamm-123');
        expect(JSON.stringify(firstResult)).not.toContain('person-77');
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
            '2026-04-09T19:00:00Z',
        );

        expect(document).toMatchObject({
            stamm_pseudonym: pseudonymizedSnapshot.stamm_pseudonym,
            sender_pseudonym: pseudonymizedSnapshot.sender_pseudonym,
            received_at: '2026-04-09T19:00:00Z',
        });
    });
});

describe('initializeStatisticsPersistence', () => {
    test('creates missing collections and expected indexes', async () => {
        const createdCollections: string[] = [];
        const createdIndexes: Record<string, Array<{ name?: string; unique?: boolean }>> = {};

        const fakeDb = {
            listCollections: () => ({
                toArray: async () => [],
            }),
            createCollection: async (collectionName: string) => {
                createdCollections.push(collectionName);
            },
            collection: (collectionName: string) => ({
                createIndexes: async (
                    indexes: Array<{ name?: string; unique?: boolean }>,
                ) => {
                    createdIndexes[collectionName] = indexes;
                    return indexes.map((index) => index.name ?? 'unnamed');
                },
            }),
        };

        await initializeStatisticsPersistence(fakeDb as never);

        expect(createdCollections).toEqual([
            statisticsCollectionNames.rawSnapshots,
            statisticsCollectionNames.effectiveStates,
            statisticsCollectionNames.weeklyAggregates,
        ]);
        expect(createdIndexes[statisticsCollectionNames.rawSnapshots]).toMatchObject([
            { name: 'raw_snapshots_by_stamm_and_recency' },
            { name: 'raw_snapshots_by_sent_at' },
        ]);
        expect(createdIndexes[statisticsCollectionNames.effectiveStates]).toMatchObject([
            { name: 'effective_states_by_stamm', unique: true },
        ]);
        expect(createdIndexes[statisticsCollectionNames.weeklyAggregates]).toMatchObject([
            { name: 'weekly_aggregates_by_week_and_type', unique: true },
        ]);
    });
});