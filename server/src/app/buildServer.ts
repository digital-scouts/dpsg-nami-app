import Fastify from 'fastify';

import { registerHealthRoutes } from '../modules/health/route.js';
import { buildNoopRawSnapshotsRepository, type RawSnapshotsRepository } from '../modules/stammesSnapshot/persistence.js';
import { registerStammesSnapshotRoutes } from '../modules/stammesSnapshot/route.js';
import { asAppError } from '../shared/errors.js';
import type { AppConfig } from './config.js';
import { buildLoggerOptions } from './logger.js';

export type ServerDependencies = {
    rawSnapshotsRepository: RawSnapshotsRepository;
};

const buildDefaultDependencies = (): ServerDependencies => ({
    rawSnapshotsRepository: buildNoopRawSnapshotsRepository(),
});

export const buildServer = (
    config: AppConfig,
    dependencies: ServerDependencies = buildDefaultDependencies(),
) => {
    const server = Fastify({
        logger: buildLoggerOptions(config),
    });

    server.decorate('appConfig', config);

    registerHealthRoutes(server);
    registerStammesSnapshotRoutes(server, config, dependencies.rawSnapshotsRepository);

    server.setNotFoundHandler((request, reply) => {
        reply.status(404).send({
            error: {
                code: 'not_found',
                message: `Route ${request.method} ${request.url} not found`,
            },
        });
    });

    server.setErrorHandler((error, _request, reply) => {
        const appError = asAppError(error);
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