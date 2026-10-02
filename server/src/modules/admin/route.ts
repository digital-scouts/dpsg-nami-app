import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

import type { AppConfig } from '../../app/config.js';
import type { ServerDependencies } from '../../app/dependencies.js';
import { computeCurrentFigures } from '../report/report.js';
import { renderAdminPage } from './page.js';
import { safeEqual, verifyAdminPassword } from './password.js';

const REALM = 'Basic realm="NaMi-Statistik", charset="UTF-8"';
// Wenige Versuche je Stunde und IP, damit das Passwort nicht durchprobiert werden kann.
const ADMIN_RATE_LIMIT_MAX = 30;

const parseBasicAuth = (header: string | undefined): { user: string; password: string } | null => {
    if (header == null || !header.startsWith('Basic ')) {
        return null;
    }
    const decoded = Buffer.from(header.slice(6).trim(), 'base64').toString('utf8');
    const trenner = decoded.indexOf(':');
    return trenner < 0 ? null : { user: decoded.slice(0, trenner), password: decoded.slice(trenner + 1) };
};

export const registerAdminRoutes = (
    server: FastifyInstance,
    config: AppConfig,
    dependencies: ServerDependencies,
): void => {
    const admin = config.admin;
    if (admin == null) {
        return;
    }

    const istAngemeldet = (request: FastifyRequest): boolean => {
        const zugang = parseBasicAuth(request.headers.authorization);
        if (zugang == null) {
            return false;
        }
        // Passwort immer pruefen, damit die Antwortzeit nichts ueber den Benutzernamen verraet.
        const passwortOk = verifyAdminPassword(zugang.password, admin.passwordHash);
        return safeEqual(zugang.user, admin.user) && passwortOk;
    };

    const ablehnen = (reply: FastifyReply) =>
        reply.status(401).header('www-authenticate', REALM).header('cache-control', 'no-store').send({
            error: { code: 'admin_unauthorized', message: 'Login required' },
        });

    server.get(
        '/admin',
        { config: { rateLimit: { max: ADMIN_RATE_LIMIT_MAX, timeWindow: config.rateLimitWindowMs } } },
        async (request, reply) => {
            if (!istAngemeldet(request)) {
                return ablehnen(reply);
            }
            const now = dependencies.clock();
            const [aktuell, berichte] = await Promise.all([
                computeCurrentFigures(dependencies, now),
                dependencies.monthlyReportsRepository.findAll(),
            ]);

            return reply
                .header('content-type', 'text/html; charset=utf-8')
                .header('cache-control', 'no-store')
                .header('x-robots-tag', 'noindex')
                .header('content-security-policy', "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'")
                .send(renderAdminPage(aktuell, berichte, config.minStammCountForRead, config.gitSha));
        },
    );
};
