import type { PseudonymizedStammesSnapshot } from './pseudonymize.js';

export type RawSnapshotDocument = PseudonymizedStammesSnapshot & {
    received_at: Date;
};

export type RawSnapshotInsertResult = {
    // false, wenn derselbe Sender denselben Datenstand fuer denselben Stamm bereits gesendet hat.
    inserted: boolean;
};

export type RawSnapshotsRepository = {
    insert(document: RawSnapshotDocument): Promise<RawSnapshotInsertResult>;
    // Pro Stamm der fachlich neueste Snapshot (source_data_as_of, bei Gleichstand sent_at).
    findLatestPerStamm(): Promise<RawSnapshotDocument[]>;
};

export const buildRawSnapshotDocument = (
    snapshot: PseudonymizedStammesSnapshot,
    receivedAt: Date = new Date(),
): RawSnapshotDocument => ({
    ...snapshot,
    received_at: receivedAt,
});
