import rateLimit from '@fastify/rate-limit';
import Fastify from 'fastify';

import { buildMemoryDependencies } from '../infra/memory/statisticsMemoryStore.js';
import { registerAdminRoutes } from '../modules/admin/route.js';
import { registerAggregateRoutes } from '../modules/aggregation/route.js';
import { registerHealthRoutes } from '../modules/health/route.js';
import { registerStammesSnapshotRoutes } from '../modules/stammesSnapshot/route.js';
import { AppError, asAppError } from '../shared/errors.js';
import type { AppConfig } from './config.js';
import type { ServerDependencies } from './dependencies.js';
import { buildLoggerOptions } from './logger.js';

export type { ServerDependencies } from './dependencies.js';

export const buildServer = (
    config: AppConfig,
    dependencies: ServerDependencies = buildMemoryDependencies(),
) => {
    const server = Fastify({
        logger: buildLoggerOptions(config),
        bodyLimit: config.bodyLimitBytes,
        // Hinter Caddy liefert X-Forwarded-For die echte Client-IP fuer das Rate-Limit.
        trustProxy: config.trustProxyHops > 0 ? config.trustProxyHops : false,
    });

    server.decorate('appConfig', config);

    // Nur Routen mit eigener rateLimit-Konfiguration werden begrenzt (Ingest und Read).
    void server.register(rateLimit, {
        global: false,
        errorResponseBuilder: () =>
            new AppError('Too many requests', 429, 'rate_limited'),
    });

    void server.register(async (instance) => {
        registerHealthRoutes(instance, config, dependencies);
        registerStammesSnapshotRoutes(instance, config, dependencies);
        registerAggregateRoutes(instance, config, dependencies);
        registerAdminRoutes(instance, config, dependencies);
    });

    server.setNotFoundHandler((request, reply) => {
        reply.status(404).send({
            error: {
                code: 'not_found',
                message: `Route ${request.method} ${request.url} not found`,
            },
        });
    });

    server.setErrorHandler((error, request, reply) => {
        const appError = asAppError(error);

        if (appError.statusCode >= 500) {
            request.log.error(error, 'Unhandled request error');
        }

        const errorPayload: {
            code: string;
            message: string;
            fields?: string[];
        } = {
            code: appError.code,
            message: appError.message,
        };

        if (appError.fields != null && appError.fields.length > 0) {
            errorPayload.fields = appError.fields;
        }

        reply.status(appError.statusCode).send({
            error: errorPayload,
        });
    });

    return server;
};
