import { createHash } from 'node:crypto';

import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

import type { AppConfig } from '../../app/config.js';
import type { ServerDependencies } from '../../app/dependencies.js';
import { meldungFuerApp, PLATTFORMEN, sortiereMeldungen, versionFuerApp } from './model.js';

// Viele Apps teilen sich eine IP (Mobilfunk, WLAN im Stammesheim); jede fragt hoechstens stuendlich.
const FEED_RATE_LIMIT_MAX = 600;

// Ohne Login, im Format der frueheren notifications.json und version.json. Die App fragt selten;
// mit ETag kostet eine unveraenderte Antwort nur 304.
const sendeJson = (request: FastifyRequest, reply: FastifyReply, daten: unknown) => {
    const body = JSON.stringify(daten);
    const etag = `"${createHash('sha256').update(body).digest('base64url').slice(0, 27)}"`;
    reply.header('etag', etag).header('cache-control', 'no-cache');
    if (request.headers['if-none-match'] === etag) {
        return reply.status(304).send();
    }
    return reply.type('application/json; charset=utf-8').send(body);
};

export const registerAppFeedRoutes = (
    server: FastifyInstance,
    config: AppConfig,
    dependencies: ServerDependencies,
): void => {
    const rateLimit = { max: FEED_RATE_LIMIT_MAX, timeWindow: config.rateLimitWindowMs };

    server.get('/app/notifications', { config: { rateLimit } }, async (request, reply) => {
        const meldungen = sortiereMeldungen(await dependencies.meldungenRepository.findAll());
        return sendeJson(request, reply, { items: meldungen.map(meldungFuerApp) });
    });

    server.get('/app/version', { config: { rateLimit } }, async (request, reply) => {
        const versionen = await dependencies.versionenRepository.findAll();
        if (versionen.length === 0) {
            // Die App behaelt dann ihren letzten Stand.
            return reply.status(404).send({ error: { code: 'not_found', message: 'No versions configured' } });
        }
        const daten = Object.fromEntries(PLATTFORMEN.flatMap((plattform) => {
            const version = versionen.find((v) => v.plattform === plattform);
            return version == null ? [] : [[plattform, versionFuerApp(version)]];
        }));
        return sendeJson(request, reply, daten);
    });
};
