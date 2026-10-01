import { buildServer } from '../../src/app/buildServer.js';
import { type AppConfig, loadConfig } from '../../src/app/config.js';
import type { ServerDependencies } from '../../src/app/dependencies.js';
import {
    buildMemoryDependencies,
    createStatisticsMemoryStore,
    type StatisticsMemoryStore,
} from '../../src/infra/memory/statisticsMemoryStore.js';
import { SUPPORTED_SCHEMA_VERSION } from '../../src/modules/stammesSnapshot/schema.js';

export const TEST_SECRET = 'a'.repeat(64);
export const OTHER_SECRET = 'b'.repeat(64);

export const buildTestConfig = (overrides: NodeJS.ProcessEnv = {}): AppConfig =>
    loadConfig({
        NODE_ENV: 'test',
        LOG_LEVEL: 'fatal',
        PSEUDONYMIZATION_SECRET: 'test-secret',
        SENDER_SECRET_PEPPER: 'test-pepper',
        ...overrides,
    });

export const gruppe = (
    gruppeId: string,
    stufe: string,
    mitglieder: number | null,
    leitende: number | null = 1,
    overrides: Record<string, unknown> = {},
) => ({
    gruppe_id: gruppeId,
    stufe,
    abgedeckt: true,
    mitglieder: { gesamt: mitglieder },
    leitende: { gesamt: leitende },
    ...overrides,
});

// Nicht abgedeckte Gruppe: nur Teil der Gruppenstruktur.
export const fremdeGruppe = (gruppeId: string, stufe: string) => ({
    gruppe_id: gruppeId,
    stufe,
    abgedeckt: false,
});

export const createValidPayload = (overrides: Record<string, unknown> = {}) => ({
    schema_version: SUPPORTED_SCHEMA_VERSION,
    stamm_id: 'stamm-123',
    dv_id: 'dv-1',
    sender_id: 'install-77',
    sent_at: '2026-04-09T18:30:00Z',
    source_data_as_of: '2026-04-09T18:00:00Z',
    abdeckung: 'stamm',
    gruppen: [gruppe('g-biber', 'biber', 5)],
    metrics: {
        leitende: {
            gesamt: 3,
        },
    },
    ...overrides,
});

export const authHeader = (secret: string = TEST_SECRET) => ({
    authorization: `Bearer ${secret}`,
});

export type MutableClock = {
    now: Date;
    clock: () => Date;
};

export const createMutableClock = (initial: string): MutableClock => {
    const state: MutableClock = {
        now: new Date(initial),
        clock: () => state.now,
    };
    return state;
};

export const buildMemoryTestServer = (options: {
    config?: AppConfig;
    store?: StatisticsMemoryStore;
    clock?: () => Date;
    dependencies?: Partial<ServerDependencies>;
} = {}) => {
    const store = options.store ?? createStatisticsMemoryStore();
    const dependencies: ServerDependencies = {
        ...buildMemoryDependencies(store, options.clock ?? (() => new Date('2026-04-10T08:00:00Z'))),
        ...options.dependencies,
    };
    const server = buildServer(options.config ?? buildTestConfig(), dependencies);

    return { server, store, dependencies };
};
