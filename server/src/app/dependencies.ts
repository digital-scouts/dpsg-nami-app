import type { MeldungenRepository, VersionenRepository } from '../modules/appFeeds/model.js';
import type { WeeklyAggregatesRepository } from '../modules/aggregation/aggregation.js';
import type { EffectiveStatesRepository } from '../modules/effectiveState/effectiveState.js';
import type { ReadinessProbe } from '../modules/health/route.js';
import type { MonthlyReportsRepository } from '../modules/report/report.js';
import type { SenderRepository } from '../modules/senderAuth/senderAuth.js';
import type { RawSnapshotsRepository } from '../modules/stammesSnapshot/persistence.js';
import type { Notifier } from '../shared/notifier.js';
import type { Clock } from '../shared/time.js';

export type ServerDependencies = {
    rawSnapshotsRepository: RawSnapshotsRepository;
    senderRepository: SenderRepository;
    effectiveStatesRepository: EffectiveStatesRepository;
    weeklyAggregatesRepository: WeeklyAggregatesRepository;
    monthlyReportsRepository: MonthlyReportsRepository;
    meldungenRepository: MeldungenRepository;
    versionenRepository: VersionenRepository;
    readinessProbe: ReadinessProbe;
    clock: Clock;
    // Meldet Aenderungen an Meldungen und Versionen; ohne Telegram-Konfiguration keiner.
    notifier?: Notifier | null;
};
