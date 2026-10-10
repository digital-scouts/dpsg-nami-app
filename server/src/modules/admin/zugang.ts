import { createHmac } from 'node:crypto';

import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

import type { AdminConfig, AppConfig } from '../../app/config.js';
import { safeEqual, verifyAdminPassword } from './password.js';

// Gemeinsamer Zugang aller Admin-Seiten: Basic Auth, Rate-Limit, HTML-Header und Schutz der
// Formulare gegen fremde Seiten (CSRF), weil der Browser Basic Auth automatisch mitschickt.

const REALM = 'Basic realm="NaMi-Statistik", charset="UTF-8"';
// Wenige Versuche je Stunde, Route und IP, damit das Passwort nicht durchprobiert werden kann.
const ADMIN_RATE_LIMIT_MAX = 30;

export const HTML_HEADERS = {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
    'x-robots-tag': 'noindex',
    'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'",
};

export type Formular = Record<string, string>;

const parseBasicAuth = (header: string | undefined): { user: string; password: string } | null => {
    if (header == null || !header.startsWith('Basic ')) {
        return null;
    }
    const decoded = Buffer.from(header.slice(6).trim(), 'base64').toString('utf8');
    const trenner = decoded.indexOf(':');
    return trenner < 0 ? null : { user: decoded.slice(0, trenner), password: decoded.slice(trenner + 1) };
};

export const buildAdminZugang = (server: FastifyInstance, config: AppConfig, admin: AdminConfig) => {
    // Formulare kommen als application/x-www-form-urlencoded; ohne Zusatzpaket, begrenzt durch bodyLimit.
    if (!server.hasContentTypeParser('application/x-www-form-urlencoded')) {
        server.addContentTypeParser('application/x-www-form-urlencoded', { parseAs: 'string' }, (_request, body, done) => {
            const formular: Formular = {};
            for (const [name, wert] of new URLSearchParams(body as string)) {
                formular[name] = wert;
            }
            done(null, formular);
        });
    }

    // Fester Wert je Zugang: fremde Seiten kennen ihn nicht und koennen kein gueltiges Formular schicken.
    const csrf = createHmac('sha256', admin.passwordHash).update(`admin-formular:${admin.user}`).digest('base64url');

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

    // Token im Formular und, soweit der Browser sie schickt, Herkunft der Anfrage. Origin ist hinter
    // Caddy (Referrer-Policy no-referrer) bei Formularen oft "null"; dann zaehlt Sec-Fetch-Site.
    const formularErlaubt = (request: FastifyRequest): boolean => {
        const body = request.body as Formular | undefined;
        if (body == null || typeof body !== 'object' || !safeEqual(String(body.csrf ?? ''), csrf)) {
            return false;
        }
        const site = request.headers['sec-fetch-site'];
        if (typeof site === 'string' && site !== 'same-origin') {
            return false;
        }
        const origin = request.headers.origin;
        if (typeof origin === 'string' && origin !== 'null') {
            try {
                return new URL(origin).host === request.headers.host;
            } catch {
                return false;
            }
        }
        return true;
    };

    const fremdesFormular = (reply: FastifyReply) =>
        reply.status(403).header('cache-control', 'no-store').send({
            error: { code: 'admin_forbidden', message: 'Form not accepted' },
        });

    return {
        csrf,
        istAngemeldet,
        ablehnen,
        formularErlaubt,
        fremdesFormular,
        routeOptions: { config: { rateLimit: { max: ADMIN_RATE_LIMIT_MAX, timeWindow: config.rateLimitWindowMs } } },
    };
};

export type AdminZugang = ReturnType<typeof buildAdminZugang>;

export const feld = (formular: Formular | undefined, name: string): string =>
    formular != null && typeof formular[name] === 'string' ? formular[name] : '';
