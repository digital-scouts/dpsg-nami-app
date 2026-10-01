import type { ServerDependencies } from '../../app/dependencies.js';
import type { WeeklyAggregateDocument } from '../../modules/aggregation/aggregation.js';
import type { EffectiveStateDocument } from '../../modules/effectiveState/effectiveState.js';
import type { MonthlyReportDocument } from '../../modules/report/report.js';
import type { SenderDocument } from '../../modules/senderAuth/senderAuth.js';
import type { RawSnapshotDocument } from '../../modules/stammesSnapshot/persistence.js';
import { SUPPORTED_SCHEMA_VERSION } from '../../modules/stammesSnapshot/schema.js';
import { type Clock, systemClock } from '../../shared/time.js';

// In-Memory-Umsetzung aller Repositories fuer Tests und Server-Instanzen ohne MongoDB.
// Die Regeln (Dubletten, TOFU, Filter auf die aktuelle Schema-Version) entsprechen der
// MongoDB-Umsetzung.
export type StatisticsMemoryStore = {
    rawSnapshots: RawSnapshotDocument[];
    senders: Map<string, SenderDocument>;
    effectiveStates: Map<string, EffectiveStateDocument>;
    weeklyAggregates: Map<string, WeeklyAggregateDocument>;
    lastBackupAt: Date | null;
    monthlyReports: Map<string, MonthlyReportDocument>;
};

export const createStatisticsMemoryStore = (): StatisticsMemoryStore => ({
    rawSnapshots: [],
    senders: new Map(),
    effectiveStates: new Map(),
    weeklyAggregates: new Map(),
    lastBackupAt: null,
    monthlyReports: new Map(),
});

const isDuplicateRawSnapshot = (a: RawSnapshotDocument, b: RawSnapshotDocument): boolean =>
    a.stamm_pseudonym === b.stamm_pseudonym
    && a.sender_pseudonym === b.sender_pseudonym
    && a.source_data_as_of.getTime() === b.source_data_as_of.getTime()
    && a.schema_version === b.schema_version;

const isCurrentSince = (document: RawSnapshotDocument, since: Date): boolean =>
    document.schema_version === SUPPORTED_SCHEMA_VERSION
    && (document.source_data_as_of.getTime() >= since.getTime() || document.received_at.getTime() >= since.getTime());

export const buildMemoryDependencies = (
    store: StatisticsMemoryStore = createStatisticsMemoryStore(),
    clock: Clock = systemClock,
): ServerDependencies => ({
    clock,
    rawSnapshotsRepository: {
        insert: async (document) => {
            if (store.rawSnapshots.some((existing) => isDuplicateRawSnapshot(existing, document))) {
                return { inserted: false };
            }
            store.rawSnapshots.push(document);
            return { inserted: true };
        },
        findByStammSince: async (stammPseudonym, since) =>
            store.rawSnapshots.filter((document) =>
                document.stamm_pseudonym === stammPseudonym
                && document.schema_version === SUPPORTED_SCHEMA_VERSION
                && document.source_data_as_of.getTime() >= since.getTime()),
        findSince: async (since) => store.rawSnapshots.filter((document) => isCurrentSince(document, since)),
    },
    senderRepository: {
        findByPseudonym: async (senderPseudonym) => store.senders.get(senderPseudonym) ?? null,
        registerIfAbsent: async (document) => {
            if (store.senders.has(document.sender_pseudonym)) {
                return 'already_registered';
            }
            store.senders.set(document.sender_pseudonym, { ...document });
            return 'registered';
        },
        markSuccessfulSend: async (senderPseudonym, sentAt) => {
            const sender = store.senders.get(senderPseudonym);
            if (sender != null) {
                sender.last_successful_send_at = sentAt;
            }
        },
        listActivity: async () =>
            [...store.senders.values()].map(({ created_at, last_successful_send_at }) => ({
                created_at,
                last_successful_send_at,
            })),
    },
    effectiveStatesRepository: {
        upsert: async (state) => {
            store.effectiveStates.set(state.stamm_pseudonym, state);
        },
        remove: async (stammPseudonym) => {
            store.effectiveStates.delete(stammPseudonym);
        },
        replaceAll: async (states) => {
            store.effectiveStates.clear();
            for (const state of states) {
                store.effectiveStates.set(state.stamm_pseudonym, state);
            }
        },
        findAll: async () => [...store.effectiveStates.values()],
    },
    weeklyAggregatesRepository: {
        upsert: async (document) => {
            store.weeklyAggregates.set(`${document.aggregation_week}:${document.aggregation_type}`, document);
        },
        findLatest: async (aggregationType) =>
            [...store.weeklyAggregates.values()]
                .filter((document) => document.aggregation_type === aggregationType)
                .sort((a, b) => b.generated_at.getTime() - a.generated_at.getTime())[0] ?? null,
    },
    monthlyReportsRepository: {
        insertIfAbsent: async (document) => {
            if (!store.monthlyReports.has(document.month)) {
                store.monthlyReports.set(document.month, document);
            }
        },
        find: async (month) => store.monthlyReports.get(month) ?? null,
        findAll: async () => [...store.monthlyReports.values()].sort((a, b) => b.month.localeCompare(a.month)),
        markNotified: async (month, notifiedAt) => {
            const report = store.monthlyReports.get(month);
            if (report != null) {
                report.notified_at = notifiedAt;
            }
        },
    },
    readinessProbe: {
        pingDatabase: async () => undefined,
        findLastBackupAt: async () => store.lastBackupAt,
    },
});
