import { createHmac } from 'node:crypto';

import type { StammesSnapshotPayload } from './schema.js';

export type PseudonymizedStammesSnapshot = Omit<
    StammesSnapshotPayload,
    'stamm_id' | 'sender_id'
> & {
    stamm_pseudonym: string;
    sender_pseudonym: string;
};

const buildPseudonym = (
    scope: 'stamm' | 'sender',
    value: string,
    secret: string,
): string => {
    const digest = createHmac('sha256', secret)
        .update(`${scope}:${value}`)
        .digest('hex');

    return `${scope}_${digest}`;
};

export const pseudonymizeStammesSnapshot = (
    snapshot: StammesSnapshotPayload,
    secret: string,
): PseudonymizedStammesSnapshot => ({
    schema_version: snapshot.schema_version,
    stamm_pseudonym: buildPseudonym('stamm', snapshot.stamm_id, secret),
    sender_pseudonym: buildPseudonym('sender', snapshot.sender_id, secret),
    dv_id: snapshot.dv_id,
    bezirk_id: snapshot.bezirk_id,
    sent_at: snapshot.sent_at,
    source_data_as_of: snapshot.source_data_as_of,
    metrics: snapshot.metrics,
});