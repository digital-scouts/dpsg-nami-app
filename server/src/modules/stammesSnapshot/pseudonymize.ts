import { createHmac } from 'node:crypto';

import type { SnapshotGruppe, StammesSnapshotPayload } from './schema.js';

export type PseudonymizedGruppe = Omit<SnapshotGruppe, 'gruppe_id'> & {
    gruppe_pseudonym: string;
};

export type PseudonymizedStammesSnapshot = Omit<
    StammesSnapshotPayload,
    'stamm_id' | 'sender_id' | 'source_data_as_of' | 'gruppen'
> & {
    stamm_pseudonym: string;
    sender_pseudonym: string;
    source_data_as_of: Date;
    gruppen: PseudonymizedGruppe[];
};

export const buildPseudonym = (
    scope: 'stamm' | 'sender' | 'gruppe',
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
    source_data_as_of: new Date(snapshot.source_data_as_of),
    abdeckung: snapshot.abdeckung,
    gruppen: snapshot.gruppen.map(({ gruppe_id: gruppeId, ...gruppe }) => ({
        gruppe_pseudonym: buildPseudonym('gruppe', gruppeId, secret),
        ...gruppe,
    })),
    metrics: snapshot.metrics,
});
