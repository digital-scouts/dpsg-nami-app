import type { FastifyInstance } from 'fastify';

import type { AppConfig } from '../../app/config.js';
import type { ServerDependencies } from '../../app/dependencies.js';
import { refreshBundAggregate } from '../aggregation/refresh.js';
import { extractBearerSecret, verifyOrRegisterSender } from '../senderAuth/senderAuth.js';
import { toEffectiveState } from '../effectiveState/effectiveState.js';
import { buildRawSnapshotDocument } from './persistence.js';
import { pseudonymizeStammesSnapshot } from './pseudonymize.js';
import { parseStammesSnapshotPayload } from './schema.js';

export const registerStammesSnapshotRoutes = (
    server: FastifyInstance,
    config: AppConfig,
    dependencies: ServerDependencies,
): void => {
    server.post(
        '/snapshots/stamm',
        {
            config: {
                rateLimit: {
                    max: config.rateLimitIngestMax,
                    timeWindow: config.rateLimitWindowMs,
                },
            },
        },
        async (request, reply) => {
            const now = dependencies.clock();
            const snapshot = parseStammesSnapshotPayload(request.body, now);
            const secret = extractBearerSecret(request.headers.authorization);
            const pseudonymizedSnapshot = pseudonymizeStammesSnapshot(
                snapshot,
                config.pseudonymizationSecret,
            );

            await verifyOrRegisterSender(
                dependencies.senderRepository,
                pseudonymizedSnapshot.sender_pseudonym,
                secret,
                config.senderSecretPepper,
                now,
            );

            const rawSnapshotDocument = buildRawSnapshotDocument(pseudonymizedSnapshot, now);
            const { inserted } = await dependencies.rawSnapshotsRepository.insert(rawSnapshotDocument);

            // Auch ein erneut gesendeter, identischer Datenstand zaehlt als Teilnahme.
            await dependencies.senderRepository.markSuccessfulSend(
                pseudonymizedSnapshot.sender_pseudonym,
                now,
            );

            if (inserted) {
                await dependencies.effectiveStatesRepository.upsertIfNewer(
                    toEffectiveState(rawSnapshotDocument),
                );
                await refreshBundAggregate(
                    dependencies.effectiveStatesRepository,
                    dependencies.weeklyAggregatesRepository,
                    now,
                );
            }

            reply.status(204).send();
        },
    );
};
