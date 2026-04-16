import type { FastifyInstance } from 'fastify';

import type { AppConfig } from '../../app/config.js';
import type { RawSnapshotsRepository } from './persistence.js';
import { buildRawSnapshotDocument } from './persistence.js';
import { pseudonymizeStammesSnapshot } from './pseudonymize.js';
import { parseStammesSnapshotPayload } from './schema.js';

export const registerStammesSnapshotRoutes = (
    server: FastifyInstance,
    config: AppConfig,
    rawSnapshotsRepository: RawSnapshotsRepository,
): void => {
    server.post('/snapshots/stamm', async (request, reply) => {
        const snapshot = parseStammesSnapshotPayload(request.body);
        const pseudonymizedSnapshot = pseudonymizeStammesSnapshot(
            snapshot,
            config.pseudonymizationSecret,
        );
        const rawSnapshotDocument = buildRawSnapshotDocument(pseudonymizedSnapshot);

        await rawSnapshotsRepository.insert(rawSnapshotDocument);

        reply.status(204).send();
    });
};