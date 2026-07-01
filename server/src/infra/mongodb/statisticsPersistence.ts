import type { Db, IndexDescription } from 'mongodb';

import type { RawSnapshotDocument, RawSnapshotsRepository } from '../../modules/stammesSnapshot/persistence.js';

export const statisticsCollectionNames = {
    rawSnapshots: 'raw_snapshots',
    effectiveStates: 'effective_states',
    weeklyAggregates: 'weekly_aggregates',
} as const;

const rawSnapshotsIndexes: IndexDescription[] = [
    {
        key: {
            stamm_pseudonym: 1,
            source_data_as_of: -1,
            sent_at: -1,
        },
        name: 'raw_snapshots_by_stamm_and_recency',
    },
    {
        key: {
            sent_at: -1,
        },
        name: 'raw_snapshots_by_sent_at',
    },
];

const effectiveStatesIndexes: IndexDescription[] = [
    {
        key: {
            stamm_pseudonym: 1,
        },
        name: 'effective_states_by_stamm',
        unique: true,
    },
];

const weeklyAggregatesIndexes: IndexDescription[] = [
    {
        key: {
            aggregation_week: 1,
            aggregation_type: 1,
        },
        name: 'weekly_aggregates_by_week_and_type',
        unique: true,
    },
];

const ensureCollectionExists = async (db: Db, collectionName: string): Promise<void> => {
    const existingCollections = await db.listCollections({ name: collectionName }, { nameOnly: true }).toArray();

    if (existingCollections.length === 0) {
        await db.createCollection(collectionName);
    }
};

export const initializeStatisticsPersistence = async (db: Db): Promise<void> => {
    await ensureCollectionExists(db, statisticsCollectionNames.rawSnapshots);
    await ensureCollectionExists(db, statisticsCollectionNames.effectiveStates);
    await ensureCollectionExists(db, statisticsCollectionNames.weeklyAggregates);

    await db.collection(statisticsCollectionNames.rawSnapshots).createIndexes(rawSnapshotsIndexes);
    await db.collection(statisticsCollectionNames.effectiveStates).createIndexes(effectiveStatesIndexes);
    await db.collection(statisticsCollectionNames.weeklyAggregates).createIndexes(weeklyAggregatesIndexes);
};

export const buildRawSnapshotsRepository = (db: Db): RawSnapshotsRepository => ({
    insert: async (document: RawSnapshotDocument): Promise<void> => {
        await db
            .collection<RawSnapshotDocument>(statisticsCollectionNames.rawSnapshots)
            .insertOne(document);
    },
});