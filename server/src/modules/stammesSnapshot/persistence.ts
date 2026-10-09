import type { PseudonymizedStammesSnapshot } from './pseudonymize.js';

export type RawSnapshotDocument = PseudonymizedStammesSnapshot & {
    received_at: Date;
    // Erster Eingang dieses Senders fuer diesen Stamm, von Snapshot zu Snapshot weitergetragen,
    // damit er die Speicherfrist einzelner Snapshots ueberdauert (Vorrang, siehe Haltefrist).
    first_seen_at: Date;
};

export type RawSnapshotInsertResult = {
    // false, wenn derselbe Sender denselben Datenstand fuer denselben Stamm bereits gesendet hat.
    inserted: boolean;
};

export type RawSnapshotsRepository = {
    insert(document: RawSnapshotDocument): Promise<RawSnapshotInsertResult>;
    // first_seen_at des aeltesten vorhandenen Snapshots dieses Senders fuer den Stamm, auch
    // aelterer Schema-Versionen; null beim ersten Kontakt.
    findFirstSeen(stammPseudonym: string, senderPseudonym: string): Promise<Date | null>;
    // Snapshots der aktuellen Schema-Version eines Stammes, eingegangen ab since.
    findByStammSince(stammPseudonym: string, since: Date): Promise<RawSnapshotDocument[]>;
    // Snapshots der aktuellen Schema-Version, eingegangen ab since.
    findSince(since: Date): Promise<RawSnapshotDocument[]>;
    // Alle Snapshots eines Senders, auch alter Schema-Versionen (Auskunft auf Anfrage).
    findBySender(senderPseudonym: string): Promise<RawSnapshotDocument[]>;
    // Loescht alle Snapshots eines Senders (Loeschung auf Anfrage), liefert die Anzahl.
    deleteBySender(senderPseudonym: string): Promise<number>;
    // Eingang des aeltesten gespeicherten Snapshots (jede Schema-Version), fuer die naechste Loeschung.
    findOldestReceivedAt(): Promise<Date | null>;
};

export const buildRawSnapshotDocument = (
    snapshot: PseudonymizedStammesSnapshot,
    receivedAt: Date = new Date(),
    firstSeenAt: Date | null = null,
): RawSnapshotDocument => ({
    ...snapshot,
    received_at: receivedAt,
    first_seen_at: firstSeenAt ?? receivedAt,
});
