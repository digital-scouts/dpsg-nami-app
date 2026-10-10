import type { FastifyInstance } from 'fastify';

import type { AppConfig } from '../../app/config.js';
import type { ServerDependencies } from '../../app/dependencies.js';
import { computeCurrentFigures } from '../report/report.js';
import { retentionEnd, senderRetentionStart } from '../../shared/retention.js';
import { BUND_AGGREGATION_TYPE } from '../aggregation/aggregation.js';
import { sortiereMeldungen } from '../appFeeds/model.js';
import { type Befund, pruefeBestand } from '../appFeeds/pruefung.js';
import { type BetriebsDaten, renderBetriebPage } from './betriebPage.js';
import { renderAdminPage } from './page.js';
import { registerPflegeRoutes } from './pflegeRoute.js';
import { buildAdminZugang, HTML_HEADERS } from './zugang.js';

const SNAPSHOT_FENSTER_TAGE = 30;
const TAG_MS = 24 * 60 * 60 * 1000;

export const registerAdminRoutes = (
    server: FastifyInstance,
    config: AppConfig,
    dependencies: ServerDependencies,
): void => {
    const admin = config.admin;
    if (admin == null) {
        return;
    }
    const zugang = buildAdminZugang(server, config, admin);
    const { istAngemeldet, ablehnen } = zugang;

    server.get(
        '/admin',
        zugang.routeOptions,
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

    server.get(
        '/admin/betrieb',
        zugang.routeOptions,
        async (request, reply) => {
            if (!istAngemeldet(request)) {
                return ablehnen(reply);
            }
            const now = dependencies.clock();
            const datenbank = await dependencies.readinessProbe.pingDatabase().then(() => 'ok' as const, () => 'fehler' as const);
            const [meldungen, versionen, letztesBackup, aggregat, berichte, snapshots, aeltesterSnapshot, sender] = datenbank === 'ok'
                ? await Promise.all([
                    dependencies.meldungenRepository.findAll(),
                    dependencies.versionenRepository.findAll(),
                    dependencies.readinessProbe.findLastBackupAt(),
                    dependencies.weeklyAggregatesRepository.findLatest(BUND_AGGREGATION_TYPE),
                    dependencies.monthlyReportsRepository.findAll(),
                    dependencies.rawSnapshotsRepository.findSince(new Date(now.getTime() - SNAPSHOT_FENSTER_TAGE * TAG_MS)),
                    dependencies.rawSnapshotsRepository.findOldestReceivedAt(),
                    dependencies.senderRepository.listActivity(),
                ])
                : [[], [], null, null, [], [], null, []];
            const senderEnden = sender.map((s) => retentionEnd(senderRetentionStart(s)).getTime());

            const befunde: Befund[] = datenbank === 'ok'
                ? pruefeBestand(meldungen, versionen, now)
                : [{ stufe: 'fehler', text: 'MongoDB ist nicht erreichbar.' }];

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
                meldungen: sortiereMeldungen(meldungen),
                versionen,
                befunde,
            };
            return reply.headers(HTML_HEADERS).send(renderBetriebPage(daten));
        },
    );

    registerPflegeRoutes(server, config, dependencies, zugang);
};
