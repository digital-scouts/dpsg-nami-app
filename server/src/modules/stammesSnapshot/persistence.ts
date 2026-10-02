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
    // Snapshots der aktuellen Schema-Version eines Stammes mit source_data_as_of ab since.
    findByStammSince(stammPseudonym: string, since: Date): Promise<RawSnapshotDocument[]>;
    // Snapshots der aktuellen Schema-Version mit source_data_as_of oder received_at ab since.
    findSince(since: Date): Promise<RawSnapshotDocument[]>;
};

export const buildRawSnapshotDocument = (
    snapshot: PseudonymizedStammesSnapshot,
    receivedAt: Date = new Date(),
): RawSnapshotDocument => ({
    ...snapshot,
    received_at: receivedAt,
});
