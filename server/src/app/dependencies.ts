import type { FeedFetcher } from '../modules/admin/feeds.js';
import type { WeeklyAggregatesRepository } from '../modules/aggregation/aggregation.js';
import type { EffectiveStatesRepository } from '../modules/effectiveState/effectiveState.js';
import type { ReadinessProbe } from '../modules/health/route.js';
import type { MonthlyReportsRepository } from '../modules/report/report.js';
import type { SenderRepository } from '../modules/senderAuth/senderAuth.js';
import type { RawSnapshotsRepository } from '../modules/stammesSnapshot/persistence.js';
import type { Clock } from '../shared/time.js';

export type ServerDependencies = {
    rawSnapshotsRepository: RawSnapshotsRepository;
    senderRepository: SenderRepository;
    effectiveStatesRepository: EffectiveStatesRepository;
    weeklyAggregatesRepository: WeeklyAggregatesRepository;
    monthlyReportsRepository: MonthlyReportsRepository;
    readinessProbe: ReadinessProbe;
    clock: Clock;
    // Laedt notifications.json und version.json fuer /admin/betrieb; ohne Angabe per HTTPS.
    feedFetcher?: FeedFetcher;
};
