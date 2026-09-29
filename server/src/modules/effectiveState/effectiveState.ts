import type { RawSnapshotDocument } from '../stammesSnapshot/persistence.js';

// Effektiver Stand: pro Stamm genau der fachlich neueste gueltige Snapshot.
export type EffectiveStateDocument = RawSnapshotDocument;

export type EffectiveStatesRepository = {
    // Schreibt den Snapshot nur, wenn er neuer ist als der gespeicherte Stand (idempotent).
    upsertIfNewer(state: EffectiveStateDocument): Promise<void>;
    replaceAll(states: EffectiveStateDocument[]): Promise<void>;
    findAll(): Promise<EffectiveStateDocument[]>;
};

type SnapshotRecency = Pick<RawSnapshotDocument, 'source_data_as_of' | 'sent_at'>;

// Primaer entscheidet source_data_as_of, nur bei Gleichstand sent_at.
export const isNewerSnapshot = (candidate: SnapshotRecency, current: SnapshotRecency): boolean => {
    const candidateSource = candidate.source_data_as_of.getTime();
    const currentSource = current.source_data_as_of.getTime();

    if (candidateSource !== currentSource) {
        return candidateSource > currentSource;
    }

    return candidate.sent_at.getTime() > current.sent_at.getTime();
};

export const toEffectiveState = (snapshot: RawSnapshotDocument): EffectiveStateDocument => ({
    schema_version: snapshot.schema_version,
    stamm_pseudonym: snapshot.stamm_pseudonym,
    sender_pseudonym: snapshot.sender_pseudonym,
    dv_id: snapshot.dv_id,
    bezirk_id: snapshot.bezirk_id,
    sent_at: snapshot.sent_at,
    source_data_as_of: snapshot.source_data_as_of,
    received_at: snapshot.received_at,
    metrics: snapshot.metrics,
});

export const selectEffectiveSnapshots = (snapshots: RawSnapshotDocument[]): RawSnapshotDocument[] => {
    const latestByStamm = new Map<string, RawSnapshotDocument>();

    for (const snapshot of snapshots) {
        const current = latestByStamm.get(snapshot.stamm_pseudonym);

        if (current == null || isNewerSnapshot(snapshot, current)) {
            latestByStamm.set(snapshot.stamm_pseudonym, snapshot);
        }
    }

    return [...latestByStamm.values()];
};
