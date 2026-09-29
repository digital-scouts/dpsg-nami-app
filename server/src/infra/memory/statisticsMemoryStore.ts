import type { ServerDependencies } from '../../app/dependencies.js';
import type { WeeklyAggregateDocument } from '../../modules/aggregation/aggregation.js';
import {
    type EffectiveStateDocument,
    isNewerSnapshot,
    selectEffectiveSnapshots,
} from '../../modules/effectiveState/effectiveState.js';
import type { SenderDocument } from '../../modules/senderAuth/senderAuth.js';
import type { RawSnapshotDocument } from '../../modules/stammesSnapshot/persistence.js';
import { type Clock, systemClock } from '../../shared/time.js';

// In-Memory-Umsetzung aller Repositories fuer Tests und Server-Instanzen ohne MongoDB.
// Die Regeln (Dubletten, Upsert-if-newer, TOFU) entsprechen der MongoDB-Umsetzung.
export type StatisticsMemoryStore = {
    rawSnapshots: RawSnapshotDocument[];
    senders: Map<string, SenderDocument>;
    effectiveStates: Map<string, EffectiveStateDocument>;
    weeklyAggregates: Map<string, WeeklyAggregateDocument>;
    lastBackupAt: Date | null;
};

export const createStatisticsMemoryStore = (): StatisticsMemoryStore => ({
    rawSnapshots: [],
    senders: new Map(),
    effectiveStates: new Map(),
    weeklyAggregates: new Map(),
    lastBackupAt: null,
});

const isDuplicateRawSnapshot = (a: RawSnapshotDocument, b: RawSnapshotDocument): boolean =>
    a.stamm_pseudonym === b.stamm_pseudonym
    && a.sender_pseudonym === b.sender_pseudonym
    && a.source_data_as_of.getTime() === b.source_data_as_of.getTime();

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
        findLatestPerStamm: async () => selectEffectiveSnapshots(store.rawSnapshots),
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
    },
    effectiveStatesRepository: {
        upsertIfNewer: async (state) => {
            const current = store.effectiveStates.get(state.stamm_pseudonym);
            if (current == null || isNewerSnapshot(state, current)) {
                store.effectiveStates.set(state.stamm_pseudonym, state);
            }
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
    readinessProbe: {
        pingDatabase: async () => undefined,
        findLastBackupAt: async () => store.lastBackupAt,
    },
});
