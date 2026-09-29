import type { FastifyInstance } from 'fastify';

import type { AppConfig } from '../../app/config.js';
import type { ServerDependencies } from '../../app/dependencies.js';
import { BUND_AGGREGATION_TYPE } from '../aggregation/aggregation.js';

export type ReadinessProbe = {
    pingDatabase(): Promise<void>;
    // Wird von server/deploy/backup.sh nach erfolgreichem mongodump in ops_status gesetzt.
    findLastBackupAt(): Promise<Date | null>;
};

const SERVICE_NAME = 'nami-statistics-server';

export const registerHealthRoutes = (
    server: FastifyInstance,
    config: AppConfig,
    dependencies: ServerDependencies,
): void => {
    // Liveness fuer den Docker-Healthcheck: prueft nur, ob der Prozess antwortet.
    server.get('/health', async () => ({
        status: 'ok',
        service: SERVICE_NAME,
    }));

    // Readiness fuer das externe Monitoring: prueft die Datenbank und liefert Betriebsdaten.
    server.get('/health/ready', async (request, reply) => {
        try {
            await dependencies.readinessProbe.pingDatabase();
        } catch (error) {
            request.log.error(error, 'Readiness check failed: database unreachable');
            reply.status(503);

            return {
                status: 'error',
                service: SERVICE_NAME,
                version: config.gitSha,
                checks: { mongodb: 'error' },
            };
        }

        const [lastBackupAt, latestAggregate] = await Promise.all([
            dependencies.readinessProbe.findLastBackupAt(),
            dependencies.weeklyAggregatesRepository.findLatest(BUND_AGGREGATION_TYPE),
        ]);

        return {
            status: 'ok',
            service: SERVICE_NAME,
            version: config.gitSha,
            checks: {
                mongodb: 'ok',
                last_backup_at: lastBackupAt?.toISOString() ?? null,
                aggregate_generated_at: latestAggregate?.generated_at.toISOString() ?? null,
            },
        };
    });
};
