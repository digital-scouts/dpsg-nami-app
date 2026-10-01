import { type Db, type IndexDescription, MongoServerError } from 'mongodb';

import type { ServerDependencies } from '../../app/dependencies.js';
import type { WeeklyAggregateDocument, WeeklyAggregatesRepository } from '../../modules/aggregation/aggregation.js';
import type { EffectiveStateDocument, EffectiveStatesRepository } from '../../modules/effectiveState/effectiveState.js';
import type { ReadinessProbe } from '../../modules/health/route.js';
import type { MonthlyReportDocument, MonthlyReportsRepository } from '../../modules/report/report.js';
import type { SenderDocument, SenderRepository } from '../../modules/senderAuth/senderAuth.js';
import type { RawSnapshotDocument, RawSnapshotsRepository } from '../../modules/stammesSnapshot/persistence.js';
import { SUPPORTED_SCHEMA_VERSION } from '../../modules/stammesSnapshot/schema.js';
import { type Clock, systemClock } from '../../shared/time.js';

export const statisticsCollectionNames = {
    rawSnapshots: 'raw_snapshots',
    effectiveStates: 'effective_states',
    weeklyAggregates: 'weekly_aggregates',
    senders: 'senders',
    monthlyReports: 'monthly_reports',
    opsStatus: 'ops_status',
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
    {
        key: {
            source_data_as_of: -1,
        },
        name: 'raw_snapshots_by_source_data_as_of',
    },
    {
        key: {
            received_at: -1,
        },
        name: 'raw_snapshots_by_received_at',
    },
    {
        // Mit Schema-Version, damit ein neuer Snapshot nicht an einem alten gleichen Datenstands scheitert.
        key: {
            stamm_pseudonym: 1,
            sender_pseudonym: 1,
            source_data_as_of: 1,
            schema_version: 1,
        },
        name: 'raw_snapshots_dedup_by_version',
        unique: true,
    },
];

// Indizes frueherer Staende, die beim Start entfernt werden.
const obsoleteRawSnapshotIndexes = ['raw_snapshots_dedup'];

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

const monthlyReportsIndexes: IndexDescription[] = [
    {
        key: {
            month: 1,
        },
        name: 'monthly_reports_by_month',
        unique: true,
    },
];

const sendersIndexes: IndexDescription[] = [
    {
        key: {
            sender_pseudonym: 1,
        },
        name: 'senders_by_pseudonym',
        unique: true,
    },
];

const DUPLICATE_KEY_ERROR_CODE = 11000;

const isDuplicateKeyError = (error: unknown): boolean =>
    error instanceof MongoServerError && error.code === DUPLICATE_KEY_ERROR_CODE;

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
    await ensureCollectionExists(db, statisticsCollectionNames.senders);
    await ensureCollectionExists(db, statisticsCollectionNames.monthlyReports);

    const rawSnapshots = db.collection(statisticsCollectionNames.rawSnapshots);
    const existingRawIndexes = (await rawSnapshots.indexes()).map((index) => index.name);
    for (const name of obsoleteRawSnapshotIndexes) {
        if (existingRawIndexes.includes(name)) {
            await rawSnapshots.dropIndex(name);
        }
    }
    await rawSnapshots.createIndexes(rawSnapshotsIndexes);
    await db.collection(statisticsCollectionNames.effectiveStates).createIndexes(effectiveStatesIndexes);
    await db.collection(statisticsCollectionNames.weeklyAggregates).createIndexes(weeklyAggregatesIndexes);
    await db.collection(statisticsCollectionNames.senders).createIndexes(sendersIndexes);
    await db.collection(statisticsCollectionNames.monthlyReports).createIndexes(monthlyReportsIndexes);
};

// Dokumente ohne MongoDB-interne _id an die Fachlogik geben.
const withoutId = { projection: { _id: 0 } } as const;

export const buildRawSnapshotsRepository = (db: Db): RawSnapshotsRepository => {
    const collection = db.collection<RawSnapshotDocument>(statisticsCollectionNames.rawSnapshots);

    return {
        insert: async (document) => {
            try {
                await collection.insertOne({ ...document });
                return { inserted: true };
            } catch (error) {
                if (isDuplicateKeyError(error)) {
                    return { inserted: false };
                }
                throw error;
            }
        },
        findByStammSince: async (stammPseudonym, since) =>
            collection
                .find(
                    {
                        stamm_pseudonym: stammPseudonym,
                        schema_version: SUPPORTED_SCHEMA_VERSION,
                        source_data_as_of: { $gte: since },
                    },
                    withoutId,
                )
                .toArray(),
        findSince: async (since) =>
            collection
                .find(
                    {
                        schema_version: SUPPORTED_SCHEMA_VERSION,
                        $or: [{ source_data_as_of: { $gte: since } }, { received_at: { $gte: since } }],
                    },
                    withoutId,
                )
                .toArray(),
    };
};

export const buildSenderRepository = (db: Db): SenderRepository => {
    const collection = db.collection<SenderDocument>(statisticsCollectionNames.senders);

    return {
        findByPseudonym: async (senderPseudonym) =>
            collection.findOne({ sender_pseudonym: senderPseudonym }, withoutId),
        registerIfAbsent: async (document) => {
            try {
                await collection.insertOne({ ...document });
                return 'registered';
            } catch (error) {
                if (isDuplicateKeyError(error)) {
                    return 'already_registered';
                }
                throw error;
            }
        },
        markSuccessfulSend: async (senderPseudonym, sentAt) => {
            await collection.updateOne(
                { sender_pseudonym: senderPseudonym },
                { $max: { last_successful_send_at: sentAt } },
            );
        },
        listActivity: async () =>
            collection
                .find({}, { projection: { _id: 0, created_at: 1, last_successful_send_at: 1 } })
                .toArray(),
    };
};

export const buildEffectiveStatesRepository = (db: Db): EffectiveStatesRepository => {
    const collection = db.collection<EffectiveStateDocument>(statisticsCollectionNames.effectiveStates);

    return {
        upsert: async (state) => {
            await collection.replaceOne({ stamm_pseudonym: state.stamm_pseudonym }, { ...state }, { upsert: true });
        },
        remove: async (stammPseudonym) => {
            await collection.deleteOne({ stamm_pseudonym: stammPseudonym });
        },
        replaceAll: async (states) => {
            const stammPseudonyms = states.map((state) => state.stamm_pseudonym);

            if (states.length > 0) {
                await collection.bulkWrite(
                    states.map((state) => ({
                        replaceOne: {
                            filter: { stamm_pseudonym: state.stamm_pseudonym },
                            replacement: { ...state },
                            upsert: true,
                        },
                    })),
                );
            }

            await collection.deleteMany({ stamm_pseudonym: { $nin: stammPseudonyms } });
        },
        findAll: async () => collection.find({}, withoutId).toArray(),
    };
};

export const buildWeeklyAggregatesRepository = (db: Db): WeeklyAggregatesRepository => {
    const collection = db.collection<WeeklyAggregateDocument>(statisticsCollectionNames.weeklyAggregates);

    return {
        upsert: async (document) => {
            await collection.replaceOne(
                {
                    aggregation_week: document.aggregation_week,
                    aggregation_type: document.aggregation_type,
                },
                { ...document },
                { upsert: true },
            );
        },
        findLatest: async (aggregationType) =>
            collection.findOne(
                { aggregation_type: aggregationType },
                { ...withoutId, sort: { generated_at: -1 } },
            ),
    };
};

type OpsStatusDocument = {
    _id: string;
    last_success_at?: Date;
};

export const buildMonthlyReportsRepository = (db: Db): MonthlyReportsRepository => {
    const collection = db.collection<MonthlyReportDocument>(statisticsCollectionNames.monthlyReports);

    return {
        insertIfAbsent: async (document) => {
            try {
                await collection.insertOne({ ...document });
            } catch (error) {
                if (!isDuplicateKeyError(error)) {
                    throw error;
                }
            }
        },
        find: async (month) => collection.findOne({ month }, withoutId),
        findAll: async () => collection.find({}, { ...withoutId, sort: { month: -1 } }).toArray(),
        markNotified: async (month, notifiedAt) => {
            await collection.updateOne({ month }, { $set: { notified_at: notifiedAt } });
        },
    };
};

export const buildReadinessProbe = (db: Db): ReadinessProbe => ({
    pingDatabase: async () => {
        await db.command({ ping: 1 });
    },
    findLastBackupAt: async () => {
        const status = await db
            .collection<OpsStatusDocument>(statisticsCollectionNames.opsStatus)
            .findOne({ _id: 'backup' });

        return status?.last_success_at ?? null;
    },
});

export const buildMongoDependencies = (db: Db, clock: Clock = systemClock): ServerDependencies => ({
    clock,
    rawSnapshotsRepository: buildRawSnapshotsRepository(db),
    senderRepository: buildSenderRepository(db),
    effectiveStatesRepository: buildEffectiveStatesRepository(db),
    weeklyAggregatesRepository: buildWeeklyAggregatesRepository(db),
    monthlyReportsRepository: buildMonthlyReportsRepository(db),
    readinessProbe: buildReadinessProbe(db),
});
