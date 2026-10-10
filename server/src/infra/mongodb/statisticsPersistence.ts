import { type Collection, type Db, type Filter, type IndexDescription, MongoServerError, type OptionalUnlessRequiredId, type WithoutId } from 'mongodb';

import type { ServerDependencies } from '../../app/dependencies.js';
import type {
    MeldungDocument,
    MeldungenRepository,
    VersionDocument,
    VersionenRepository,
} from '../../modules/appFeeds/model.js';
import type { WeeklyAggregateDocument, WeeklyAggregatesRepository } from '../../modules/aggregation/aggregation.js';
import type { EffectiveStateDocument, EffectiveStatesRepository } from '../../modules/effectiveState/effectiveState.js';
import type { ReadinessProbe } from '../../modules/health/route.js';
import type { MonthlyReportDocument, MonthlyReportsRepository } from '../../modules/report/report.js';
import type { SenderDocument, SenderRepository } from '../../modules/senderAuth/senderAuth.js';
import type { RawSnapshotDocument, RawSnapshotsRepository } from '../../modules/stammesSnapshot/persistence.js';
import { SUPPORTED_SCHEMA_VERSION } from '../../modules/stammesSnapshot/schema.js';
import { RETENTION_MONTHS, retentionEnd } from '../../shared/retention.js';
import { type Clock, systemClock } from '../../shared/time.js';

export const statisticsCollectionNames = {
    rawSnapshots: 'raw_snapshots',
    effectiveStates: 'effective_states',
    weeklyAggregates: 'weekly_aggregates',
    senders: 'senders',
    monthlyReports: 'monthly_reports',
    opsStatus: 'ops_status',
    appNotifications: 'app_notifications',
    appVersions: 'app_versions',
} as const;

const rawSnapshotsIndexes: IndexDescription[] = [
    {
        key: {
            stamm_pseudonym: 1,
            received_at: -1,
        },
        name: 'raw_snapshots_by_stamm_and_received_at',
    },
    {
        // Fuer first_seen_at beim Eingang: aeltester Snapshot je Stamm und Sender.
        key: {
            stamm_pseudonym: 1,
            sender_pseudonym: 1,
            received_at: 1,
        },
        name: 'raw_snapshots_by_stamm_sender_and_received_at',
    },
    {
        key: {
            received_at: -1,
        },
        name: 'raw_snapshots_by_received_at',
    },
    {
        key: {
            sender_pseudonym: 1,
        },
        name: 'raw_snapshots_by_sender',
    },
    {
        // Speicherfrist: MongoDB loescht den Snapshot, sobald expires_at erreicht ist.
        key: {
            expires_at: 1,
        },
        name: 'raw_snapshots_ttl',
        expireAfterSeconds: 0,
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
const obsoleteRawSnapshotIndexes = [
    'raw_snapshots_dedup',
    'raw_snapshots_by_stamm_and_recency',
    'raw_snapshots_by_sent_at',
    'raw_snapshots_by_source_data_as_of',
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
    {
        // Speicherfrist ab der letzten erfolgreichen Sendung bzw. der Anlage.
        key: {
            expires_at: 1,
        },
        name: 'senders_ttl',
        expireAfterSeconds: 0,
    },
];

// Ablaufzeitpunkt fuer die TTL-Indizes; die Fachlogik sieht das Feld nicht.
type StoredRawSnapshot = RawSnapshotDocument & { expires_at: Date };
type StoredSender = SenderDocument & { expires_at: Date };

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
    await ensureCollectionExists(db, statisticsCollectionNames.appNotifications);
    await ensureCollectionExists(db, statisticsCollectionNames.appVersions);

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

    // Eintraege aus der Zeit vor der Speicherfrist nachtraeglich mit Ablauf versehen.
    await rawSnapshots.updateMany({ expires_at: { $exists: false } }, [
        { $set: { expires_at: { $dateAdd: { startDate: '$received_at', unit: 'month', amount: RETENTION_MONTHS } } } },
    ]);
    await db.collection(statisticsCollectionNames.senders).updateMany({ expires_at: { $exists: false } }, [
        {
            $set: {
                expires_at: {
                    $dateAdd: {
                        startDate: { $ifNull: ['$last_successful_send_at', '$created_at'] },
                        unit: 'month',
                        amount: RETENTION_MONTHS,
                    },
                },
            },
        },
    ]);
};

// Dokumente ohne MongoDB-interne _id an die Fachlogik geben.
const withoutId = { projection: { _id: 0 } } as const;
const withoutInternals = { projection: { _id: 0, expires_at: 0 } } as const;

export const buildRawSnapshotsRepository = (db: Db): RawSnapshotsRepository => {
    const collection = db.collection<StoredRawSnapshot>(statisticsCollectionNames.rawSnapshots);

    return {
        insert: async (document) => {
            try {
                await collection.insertOne({ ...document, expires_at: retentionEnd(document.received_at) });
                return { inserted: true };
            } catch (error) {
                if (isDuplicateKeyError(error)) {
                    return { inserted: false };
                }
                throw error;
            }
        },
        findFirstSeen: async (stammPseudonym, senderPseudonym) => {
            const aeltester = await collection.findOne(
                { stamm_pseudonym: stammPseudonym, sender_pseudonym: senderPseudonym },
                { projection: { _id: 0, first_seen_at: 1, received_at: 1 }, sort: { received_at: 1 } },
            );
            return aeltester == null ? null : aeltester.first_seen_at ?? aeltester.received_at;
        },
        findByStammSince: async (stammPseudonym, since) =>
            collection
                .find(
                    {
                        stamm_pseudonym: stammPseudonym,
                        schema_version: SUPPORTED_SCHEMA_VERSION,
                        received_at: { $gte: since },
                    },
                    withoutInternals,
                )
                .toArray(),
        findSince: async (since) =>
            collection
                .find(
                    {
                        schema_version: SUPPORTED_SCHEMA_VERSION,
                        received_at: { $gte: since },
                    },
                    withoutInternals,
                )
                .toArray(),
        findBySender: async (senderPseudonym) =>
            collection.find({ sender_pseudonym: senderPseudonym }, { ...withoutInternals, sort: { received_at: 1 } }).toArray(),
        findOldestReceivedAt: async () => {
            const aeltester = await collection.findOne({}, { projection: { _id: 0, received_at: 1 }, sort: { received_at: 1 } });
            return aeltester?.received_at ?? null;
        },
        deleteBySender: async (senderPseudonym) =>
            (await collection.deleteMany({ sender_pseudonym: senderPseudonym })).deletedCount,
    };
};

export const buildSenderRepository = (db: Db): SenderRepository => {
    const collection = db.collection<StoredSender>(statisticsCollectionNames.senders);

    return {
        findByPseudonym: async (senderPseudonym) =>
            collection.findOne({ sender_pseudonym: senderPseudonym }, withoutInternals),
        registerIfAbsent: async (document) => {
            try {
                await collection.insertOne({ ...document, expires_at: retentionEnd(document.created_at) });
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
                { $max: { last_successful_send_at: sentAt, expires_at: retentionEnd(sentAt) } },
            );
        },
        listActivity: async () =>
            collection
                .find({}, { projection: { _id: 0, created_at: 1, last_successful_send_at: 1 } })
                .toArray(),
        delete: async (senderPseudonym) =>
            (await collection.deleteOne({ sender_pseudonym: senderPseudonym })).deletedCount > 0,
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

// Meldung bzw. Plattform als _id; anlegen per insertOne (frei), aendern nur mit gelesenem updated_at.
type StoredMeldung = Omit<MeldungDocument, 'id'> & { _id: string };
type StoredVersion = Omit<VersionDocument, 'plattform'> & { _id: string };

const alsMeldung = ({ _id, ...rest }: StoredMeldung): MeldungDocument => ({ id: _id, ...rest });
const alsVersion = ({ _id, ...rest }: StoredVersion): VersionDocument => ({ plattform: _id as VersionDocument['plattform'], ...rest });

const speichereBedingt = async <T extends { _id: string; updated_at: Date }>(
    collection: Collection<T>,
    document: T,
    erwartet: Date | null,
): Promise<boolean> => {
    if (erwartet == null) {
        try {
            await collection.insertOne(document as OptionalUnlessRequiredId<T>);
            return true;
        } catch (error) {
            if (isDuplicateKeyError(error)) {
                return false;
            }
            throw error;
        }
    }
    const ergebnis = await collection.replaceOne(
        { _id: document._id, updated_at: erwartet } as Filter<T>,
        document as WithoutId<T>,
    );
    return ergebnis.matchedCount === 1;
};

export const buildMeldungenRepository = (db: Db): MeldungenRepository => {
    const collection = db.collection<StoredMeldung>(statisticsCollectionNames.appNotifications);

    return {
        findAll: async () => (await collection.find({}).toArray()).map(alsMeldung),
        find: async (id) => {
            const gefunden = await collection.findOne({ _id: id });
            return gefunden == null ? null : alsMeldung(gefunden);
        },
        save: async ({ id, ...rest }, erwartet) => speichereBedingt(collection, { _id: id, ...rest }, erwartet),
        delete: async (id, erwartet) => (await collection.deleteOne({ _id: id, updated_at: erwartet })).deletedCount === 1,
    };
};

export const buildVersionenRepository = (db: Db): VersionenRepository => {
    const collection = db.collection<StoredVersion>(statisticsCollectionNames.appVersions);

    return {
        findAll: async () => (await collection.find({}).toArray()).map(alsVersion),
        save: async ({ plattform, ...rest }, erwartet) => speichereBedingt(collection, { _id: plattform, ...rest }, erwartet),
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
    meldungenRepository: buildMeldungenRepository(db),
    versionenRepository: buildVersionenRepository(db),
    readinessProbe: buildReadinessProbe(db),
});
