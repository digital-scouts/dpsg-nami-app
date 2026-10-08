import type { RawSnapshotsRepository } from '../stammesSnapshot/persistence.js';
import {
    type EffectiveStatesRepository,
    mergeAllStammSnapshots,
    mergeStammSnapshots,
    snapshotWindowStart,
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

// Fuehrt die Snapshots eines Stammes im Fenster neu zusammen, z. B. nach einem neuen Snapshot.
export const refreshEffectiveStateForStamm = async (
    rawSnapshotsRepository: RawSnapshotsRepository,
    effectiveStatesRepository: EffectiveStatesRepository,
    stammPseudonym: string,
    now: Date,
): Promise<void> => {
    const since = snapshotWindowStart(now);
    const state = mergeStammSnapshots(await rawSnapshotsRepository.findByStammSince(stammPseudonym, since), since, now);

    if (state == null) {
        await effectiveStatesRepository.remove(stammPseudonym);
    } else {
        await effectiveStatesRepository.upsert(state);
    }
};

// Idempotenter Neuaufbau von effective_states aus raw_snapshots, z. B. beim Serverstart.
export const rebuildEffectiveStatesAndAggregate = async (
    rawSnapshotsRepository: RawSnapshotsRepository,
    effectiveStatesRepository: EffectiveStatesRepository,
    weeklyAggregatesRepository: WeeklyAggregatesRepository,
    now: Date,
): Promise<void> => {
    const since = snapshotWindowStart(now);
    await effectiveStatesRepository.replaceAll(mergeAllStammSnapshots(await rawSnapshotsRepository.findSince(since), since, now));
    await refreshBundAggregate(effectiveStatesRepository, weeklyAggregatesRepository, now);
};
