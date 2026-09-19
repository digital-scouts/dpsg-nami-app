import type { PseudonymizedStammesSnapshot } from './pseudonymize.js';

export type RawSnapshotDocument = PseudonymizedStammesSnapshot & {
    received_at: string;
};

export type RawSnapshotsRepository = {
    insert(document: RawSnapshotDocument): Promise<void>;
};

export const buildRawSnapshotDocument = (
    snapshot: PseudonymizedStammesSnapshot,
    receivedAt = new Date().toISOString(),
): RawSnapshotDocument => ({
    ...snapshot,
    received_at: receivedAt,
});

export const buildNoopRawSnapshotsRepository = (): RawSnapshotsRepository => ({
    insert: async () => undefined,
});