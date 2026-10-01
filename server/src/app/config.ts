import { z } from 'zod';

const logLevels = ['fatal', 'error', 'warn', 'info', 'debug', 'trace'] as const;
const storageBackends = ['mongodb', 'memory'] as const;

// Leere Werte (z. B. "REPORT_SMTP_HOST=" in der .env) gelten als nicht gesetzt.
const optionalString = z
    .string()
    .trim()
    .optional()
    .transform((value) => (value == null || value === '' ? undefined : value));

const envSchema = z.object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    HOST: z.string().trim().min(1).default('0.0.0.0'),
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),
    LOG_LEVEL: z.enum(logLevels).default('info'),
    PSEUDONYMIZATION_SECRET: z.string().trim().min(1),
    SENDER_SECRET_PEPPER: z.string().trim().min(1),
    MONGODB_URI: z
        .string()
        .trim()
        .url()
        .default('mongodb://localhost:27017'),
    MONGODB_DATABASE: z.string().trim().min(1).default('nami_statistics_local'),
    TRUST_PROXY_HOPS: z.coerce.number().int().min(0).max(10).default(0),
    BODY_LIMIT_BYTES: z.coerce.number().int().min(1024).default(32 * 1024),
    RATE_LIMIT_WINDOW_MS: z.coerce.number().int().min(1000).default(60 * 60 * 1000),
    RATE_LIMIT_INGEST_MAX: z.coerce.number().int().min(1).default(30),
    RATE_LIMIT_READ_MAX: z.coerce.number().int().min(1).default(120),
    MIN_STAMM_COUNT_FOR_READ: z.coerce.number().int().min(1).default(5),
    GIT_SHA: z.string().trim().min(1).default('unknown'),
    STORAGE_BACKEND: z.enum(storageBackends).default('mongodb'),
    MOCK_SEED_STAMM_COUNT: z.coerce.number().int().min(0).max(1000).default(0),
    REPORT_SMTP_HOST: optionalString,
    REPORT_SMTP_PORT: z.coerce.number().int().min(1).max(65535).default(587),
    REPORT_SMTP_USER: optionalString,
    REPORT_SMTP_PASS: optionalString,
    REPORT_MAIL_FROM: optionalString,
    REPORT_MAIL_TO: optionalString,
}).refine(
    // Synthetische Staemme nur fluechtig im Speicher, nie in der produktiven MongoDB.
    (env) => env.MOCK_SEED_STAMM_COUNT === 0 || env.STORAGE_BACKEND === 'memory',
    { message: 'MOCK_SEED_STAMM_COUNT requires STORAGE_BACKEND=memory', path: ['MOCK_SEED_STAMM_COUNT'] },
).refine(
    // Ein halb konfigurierter Report wuerde still nie verschickt.
    (env) => env.REPORT_SMTP_HOST == null || (env.REPORT_MAIL_FROM != null && env.REPORT_MAIL_TO != null),
    { message: 'REPORT_SMTP_HOST requires REPORT_MAIL_FROM and REPORT_MAIL_TO', path: ['REPORT_SMTP_HOST'] },
);

export type ReportConfig = {
    smtpHost: string;
    smtpPort: number;
    smtpUser: string | null;
    smtpPass: string | null;
    mailFrom: string;
    mailTo: string[];
};

export type AppConfig = {
    nodeEnv: 'development' | 'test' | 'production';
    host: string;
    port: number;
    logLevel: (typeof logLevels)[number];
    pseudonymizationSecret: string;
    senderSecretPepper: string;
    mongoDbUri: string;
    mongoDbDatabase: string;
    trustProxyHops: number;
    bodyLimitBytes: number;
    rateLimitWindowMs: number;
    rateLimitIngestMax: number;
    rateLimitReadMax: number;
    minStammCountForRead: number;
    gitSha: string;
    storageBackend: (typeof storageBackends)[number];
    mockSeedStammCount: number;
    // null, wenn kein Monatsreport verschickt werden soll.
    report: ReportConfig | null;
};

export const loadConfig = (
    env: NodeJS.ProcessEnv = process.env,
): AppConfig => {
    const parsed = envSchema.parse(env);

    return {
        nodeEnv: parsed.NODE_ENV,
        host: parsed.HOST,
        port: parsed.PORT,
        logLevel: parsed.LOG_LEVEL,
        pseudonymizationSecret: parsed.PSEUDONYMIZATION_SECRET,
        senderSecretPepper: parsed.SENDER_SECRET_PEPPER,
        mongoDbUri: parsed.MONGODB_URI,
        mongoDbDatabase: parsed.MONGODB_DATABASE,
        trustProxyHops: parsed.TRUST_PROXY_HOPS,
        bodyLimitBytes: parsed.BODY_LIMIT_BYTES,
        rateLimitWindowMs: parsed.RATE_LIMIT_WINDOW_MS,
        rateLimitIngestMax: parsed.RATE_LIMIT_INGEST_MAX,
        rateLimitReadMax: parsed.RATE_LIMIT_READ_MAX,
        minStammCountForRead: parsed.MIN_STAMM_COUNT_FOR_READ,
        gitSha: parsed.GIT_SHA,
        storageBackend: parsed.STORAGE_BACKEND,
        mockSeedStammCount: parsed.MOCK_SEED_STAMM_COUNT,
        report: parsed.REPORT_SMTP_HOST == null
            ? null
            : {
                smtpHost: parsed.REPORT_SMTP_HOST,
                smtpPort: parsed.REPORT_SMTP_PORT,
                smtpUser: parsed.REPORT_SMTP_USER ?? null,
                smtpPass: parsed.REPORT_SMTP_PASS ?? null,
                mailFrom: parsed.REPORT_MAIL_FROM ?? '',
                mailTo: (parsed.REPORT_MAIL_TO ?? '').split(',').map((address) => address.trim()).filter(Boolean),
            },
    };
};
