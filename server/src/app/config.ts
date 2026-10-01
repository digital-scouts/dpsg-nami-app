import { z } from 'zod';

import { isAdminPasswordHash } from '../modules/admin/password.js';

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
    ADMIN_USER: optionalString,
    ADMIN_PASSWORD_HASH: optionalString,
    REPORT_TELEGRAM_BOT_TOKEN: optionalString,
    REPORT_TELEGRAM_CHAT_ID: optionalString,
    PUBLIC_BASE_URL: optionalString.pipe(z.string().url().optional()),
}).refine(
    // Synthetische Staemme nur fluechtig im Speicher, nie in der produktiven MongoDB.
    (env) => env.MOCK_SEED_STAMM_COUNT === 0 || env.STORAGE_BACKEND === 'memory',
    { message: 'MOCK_SEED_STAMM_COUNT requires STORAGE_BACKEND=memory', path: ['MOCK_SEED_STAMM_COUNT'] },
).refine(
    (env) => (env.ADMIN_USER == null) === (env.ADMIN_PASSWORD_HASH == null),
    { message: 'ADMIN_USER and ADMIN_PASSWORD_HASH must be set together', path: ['ADMIN_USER'] },
).refine(
    (env) => env.ADMIN_PASSWORD_HASH == null || isAdminPasswordHash(env.ADMIN_PASSWORD_HASH),
    { message: 'ADMIN_PASSWORD_HASH must be created with npm run admin:hash', path: ['ADMIN_PASSWORD_HASH'] },
).refine(
    // Halb konfiguriert wuerde Telegram still nie benachrichtigen.
    (env) => (env.REPORT_TELEGRAM_BOT_TOKEN == null) === (env.REPORT_TELEGRAM_CHAT_ID == null),
    { message: 'REPORT_TELEGRAM_BOT_TOKEN and REPORT_TELEGRAM_CHAT_ID must be set together', path: ['REPORT_TELEGRAM_BOT_TOKEN'] },
);

export type AdminConfig = {
    user: string;
    passwordHash: string;
};

export type TelegramConfig = {
    botToken: string;
    chatId: string;
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
    // null: keine Web-Ansicht unter /admin.
    admin: AdminConfig | null;
    // null: keine Telegram-Nachricht zum Monatsreport.
    telegram: TelegramConfig | null;
    // Fuer den Link auf /admin in der Telegram-Nachricht, z. B. https://namiapp.scout-link.de
    publicBaseUrl: string | null;
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
        admin: parsed.ADMIN_USER != null && parsed.ADMIN_PASSWORD_HASH != null
            ? { user: parsed.ADMIN_USER, passwordHash: parsed.ADMIN_PASSWORD_HASH }
            : null,
        telegram: parsed.REPORT_TELEGRAM_BOT_TOKEN != null && parsed.REPORT_TELEGRAM_CHAT_ID != null
            ? { botToken: parsed.REPORT_TELEGRAM_BOT_TOKEN, chatId: parsed.REPORT_TELEGRAM_CHAT_ID }
            : null,
        publicBaseUrl: parsed.PUBLIC_BASE_URL?.replace(/\/+$/, '') ?? null,
    };
};
