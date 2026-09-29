import { createHmac } from 'node:crypto';

import type { StammesSnapshotPayload } from './schema.js';

export type PseudonymizedStammesSnapshot = Omit<
    StammesSnapshotPayload,
    'stamm_id' | 'sender_id' | 'sent_at' | 'source_data_as_of'
> & {
    stamm_pseudonym: string;
    sender_pseudonym: string;
    sent_at: Date;
    source_data_as_of: Date;
};

export const buildPseudonym = (
    scope: 'stamm' | 'sender',
    value: string,
    secret: string,
): string => {
    const digest = createHmac('sha256', secret)
        .update(`${scope}:${value}`)
        .digest('hex');

    return `${scope}_${digest}`;
};

// Zeitstempel werden als Date (UTC) gespeichert, damit Sortierung und Vergleiche
// unabhaengig vom gesendeten Zeitzonen-Offset korrekt sind.
export const pseudonymizeStammesSnapshot = (
    snapshot: StammesSnapshotPayload,
    secret: string,
): PseudonymizedStammesSnapshot => ({
    schema_version: snapshot.schema_version,
    stamm_pseudonym: buildPseudonym('stamm', snapshot.stamm_id, secret),
    sender_pseudonym: buildPseudonym('sender', snapshot.sender_id, secret),
    dv_id: snapshot.dv_id,
    bezirk_id: snapshot.bezirk_id,
    sent_at: new Date(snapshot.sent_at),
    source_data_as_of: new Date(snapshot.source_data_as_of),
    metrics: snapshot.metrics,
});
