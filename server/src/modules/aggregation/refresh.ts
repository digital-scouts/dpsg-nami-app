import type { RawSnapshotsRepository } from '../stammesSnapshot/persistence.js';
import {
    type EffectiveStatesRepository,
    toEffectiveState,
} from '../effectiveState/effectiveState.js';
import { computeBundAggregate, type WeeklyAggregatesRepository } from './aggregation.js';

// Die Aggregation laeuft auf dem materialisierten effektiven Stand, nie auf Rohsnapshots.
export const refreshBundAggregate = async (
    effectiveStatesRepository: EffectiveStatesRepository,
    weeklyAggregatesRepository: WeeklyAggregatesRepository,
    now: Date,
): Promise<void> => {
    const states = await effectiveStatesRepository.findAll();
    await weeklyAggregatesRepository.upsert(computeBundAggregate(states, now));
};

// Idempotenter Neuaufbau von effective_states aus raw_snapshots, z. B. beim Serverstart.
export const rebuildEffectiveStatesAndAggregate = async (
    rawSnapshotsRepository: RawSnapshotsRepository,
    effectiveStatesRepository: EffectiveStatesRepository,
    weeklyAggregatesRepository: WeeklyAggregatesRepository,
    now: Date,
): Promise<void> => {
    const latestSnapshots = await rawSnapshotsRepository.findLatestPerStamm();
    await effectiveStatesRepository.replaceAll(latestSnapshots.map(toEffectiveState));
    await refreshBundAggregate(effectiveStatesRepository, weeklyAggregatesRepository, now);
};
