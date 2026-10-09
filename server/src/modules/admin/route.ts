import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

import type { AppConfig } from '../../app/config.js';
import type { ServerDependencies } from '../../app/dependencies.js';
import { computeCurrentFigures } from '../report/report.js';
import { retentionEnd, senderRetentionStart } from '../../shared/retention.js';
import { BUND_AGGREGATION_TYPE } from '../aggregation/aggregation.js';
import { type BetriebsDaten, type FeedErgebnis, renderBetriebPage } from './betriebPage.js';
import { type FeedFetcher, httpFeedFetcher, type MeldungZeile, type PlattformVersion, pruefeMeldungen, pruefeVersionen } from './feeds.js';
import { renderAdminPage } from './page.js';
import { safeEqual, verifyAdminPassword } from './password.js';

const REALM = 'Basic realm="NaMi-Statistik", charset="UTF-8"';
// Wenige Versuche je Stunde und IP, damit das Passwort nicht durchprobiert werden kann.
const ADMIN_RATE_LIMIT_MAX = 30;
// Feeds hoechstens alle fuenf Minuten von GitHub Pages holen.
const FEED_CACHE_MS = 5 * 60 * 1000;
const SNAPSHOT_FENSTER_TAGE = 30;
const TAG_MS = 24 * 60 * 60 * 1000;

const HTML_HEADERS = {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
    'x-robots-tag': 'noindex',
    'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'",
};

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

            return reply.headers(HTML_HEADERS).send(renderAdminPage(aktuell, berichte, config.minStammCountForRead, config.gitSha));
        },
    );

    const feedFetcher: FeedFetcher = dependencies.feedFetcher ?? httpFeedFetcher;
    let feedCache: { abgerufen: Date; meldungen: FeedErgebnis<unknown>; versionen: FeedErgebnis<unknown> } | null = null;

    const ladeFeed = async (url: string): Promise<FeedErgebnis<unknown>> => {
        try {
            return { ok: true, daten: await feedFetcher.fetchJson(url) };
        } catch (error) {
            return { ok: false, fehler: error instanceof Error ? error.message : String(error) };
        }
    };

    const feeds = async (now: Date) => {
        if (feedCache == null || now.getTime() - feedCache.abgerufen.getTime() >= FEED_CACHE_MS) {
            const [meldungen, versionen] = await Promise.all([ladeFeed(admin.notificationsUrl), ladeFeed(admin.versionUrl)]);
            feedCache = { abgerufen: now, meldungen, versionen };
        }
        return feedCache;
    };

    server.get(
        '/admin/betrieb',
        { config: { rateLimit: { max: ADMIN_RATE_LIMIT_MAX, timeWindow: config.rateLimitWindowMs } } },
        async (request, reply) => {
            if (!istAngemeldet(request)) {
                return ablehnen(reply);
            }
            const now = dependencies.clock();
            const datenbank = await dependencies.readinessProbe.pingDatabase().then(() => 'ok' as const, () => 'fehler' as const);
            const [feed, letztesBackup, aggregat, berichte, snapshots, aeltesterSnapshot, sender] = datenbank === 'ok'
                ? await Promise.all([
                    feeds(now),
                    dependencies.readinessProbe.findLastBackupAt(),
                    dependencies.weeklyAggregatesRepository.findLatest(BUND_AGGREGATION_TYPE),
                    dependencies.monthlyReportsRepository.findAll(),
                    dependencies.rawSnapshotsRepository.findSince(new Date(now.getTime() - SNAPSHOT_FENSTER_TAGE * TAG_MS)),
                    dependencies.rawSnapshotsRepository.findOldestReceivedAt(),
                    dependencies.senderRepository.listActivity(),
                ])
                : [await feeds(now), null, null, [], [], null, []];
            const senderEnden = sender.map((s) => retentionEnd(senderRetentionStart(s)).getTime());

            const befunde = [];
            let meldungen: FeedErgebnis<MeldungZeile[]>;
            if (feed.meldungen.ok) {
                const ergebnis = pruefeMeldungen(feed.meldungen.daten, now);
                meldungen = { ok: true, daten: ergebnis.zeilen };
                befunde.push(...ergebnis.befunde);
            } else {
                meldungen = feed.meldungen;
                befunde.push({ stufe: 'fehler' as const, text: `notifications.json nicht abrufbar: ${feed.meldungen.fehler}` });
            }
            let versionen: FeedErgebnis<PlattformVersion[]>;
            if (feed.versionen.ok) {
                const ergebnis = pruefeVersionen(feed.versionen.daten);
                versionen = { ok: true, daten: ergebnis.plattformen };
                befunde.push(...ergebnis.befunde);
            } else {
                versionen = feed.versionen;
                befunde.push({ stufe: 'fehler' as const, text: `version.json nicht abrufbar: ${feed.versionen.fehler}` });
            }
            if (datenbank === 'fehler') {
                befunde.push({ stufe: 'fehler' as const, text: 'MongoDB ist nicht erreichbar.' });
            }

            const eingaenge = snapshots.map((s) => s.received_at.getTime());
            const daten: BetriebsDaten = {
                stand: now,
                version: config.gitSha,
                datenbank,
                letztesBackup,
                letztesAggregat: aggregat?.generated_at ?? null,
                letzterMonatsreport: berichte[0]?.month ?? null,
                letzterSnapshot: eingaenge.length > 0 ? new Date(Math.max(...eingaenge)) : null,
                snapshotsLetzte7Tage: eingaenge.filter((t) => t >= now.getTime() - 7 * TAG_MS).length,
                naechsteSnapshotLoeschung: aeltesterSnapshot == null ? null : retentionEnd(aeltesterSnapshot),
                naechsteSenderLoeschung: senderEnden.length > 0 ? new Date(Math.min(...senderEnden)) : null,
                anzahlSender: sender.length,
                feedAbgerufen: feed.abgerufen,
                meldungen,
                versionen,
                befunde,
                notificationsUrl: admin.notificationsUrl,
                versionUrl: admin.versionUrl,
            };
            return reply.headers(HTML_HEADERS).send(renderBetriebPage(daten));
        },
    );
};
