import type { FastifyInstance } from 'fastify';

import type { AppConfig } from '../../app/config.js';
import type { ServerDependencies } from '../../app/dependencies.js';
import { AppError } from '../../shared/errors.js';
import { buildPseudonym } from '../stammesSnapshot/pseudonymize.js';
import { assertActiveParticipant, extractBearerSecret } from '../senderAuth/senderAuth.js';
import {
    BUND_AGGREGATION_TYPE,
    formatAggregatedMetrics,
    formatGruppenJeStufe,
    tagesgenau,
    teilnahmeUeber,
} from './aggregation.js';

export const APPROXIMATION_NOTICE =
    'Annäherung aus freiwillig geteilten Stammesdaten teilnehmender App-Nutzer. '
    + 'Keine amtliche und keine repräsentative Statistik.';

export const registerAggregateRoutes = (
    server: FastifyInstance,
    config: AppConfig,
    dependencies: ServerDependencies,
): void => {
    server.get(
        '/aggregates/bund/latest',
        {
            config: {
                rateLimit: {
                    max: config.rateLimitReadMax,
                    timeWindow: config.rateLimitWindowMs,
                },
            },
        },
        async (request) => {
            const senderIdHeader = request.headers['x-sender-id'];
            const senderId = typeof senderIdHeader === 'string' ? senderIdHeader.trim() : '';

            if (senderId === '') {
                throw new AppError('Sender credentials are missing', 401, 'missing_sender_credentials');
            }

            const secret = extractBearerSecret(request.headers.authorization);
            const now = dependencies.clock();

            await assertActiveParticipant(
                dependencies.senderRepository,
                buildPseudonym('sender', senderId, config.pseudonymizationSecret),
                secret,
                config.senderSecretPepper,
                now,
            );

            const aggregate = await dependencies.weeklyAggregatesRepository.findLatest(BUND_AGGREGATION_TYPE);
            const participatingStammCount = aggregate?.participating_stamm_count ?? 0;
            const hasEnoughParticipation =
                aggregate?.metrics != null && participatingStammCount >= config.minStammCountForRead;

            return {
                status: hasEnoughParticipation ? 'ok' : 'insufficient_participation',
                aggregation_type: BUND_AGGREGATION_TYPE,
                aggregation_week: aggregate?.aggregation_week ?? null,
                generated_at: aggregate?.generated_at.toISOString() ?? null,
                // Nur als Bereich "ueber X", mindestens min_stamm_count - 1; darunter genuegt der Status.
                teilnehmende_staemme_ueber: hasEnoughParticipation
                    ? Math.max(teilnahmeUeber(participatingStammCount), config.minStammCountForRead - 1)
                    : null,
                min_stamm_count: config.minStammCountForRead,
                data_as_of: {
                    oldest: aggregate?.oldest_data_as_of == null ? null : tagesgenau(aggregate.oldest_data_as_of).toISOString(),
                    newest: aggregate?.newest_data_as_of == null ? null : tagesgenau(aggregate.newest_data_as_of).toISOString(),
                },
                notice: APPROXIMATION_NOTICE,
                metrics: hasEnoughParticipation && aggregate?.metrics != null
                    ? formatAggregatedMetrics(aggregate.metrics, config.minStammCountForRead)
                    : null,
                gruppen_je_stufe: hasEnoughParticipation && aggregate?.gruppen_je_stufe != null
                    ? formatGruppenJeStufe(aggregate.gruppen_je_stufe, config.minStammCountForRead)
                    : null,
            };
        },
    );
};
