import { z } from 'zod';

const logLevels = ['fatal', 'error', 'warn', 'info', 'debug', 'trace'] as const;

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
});

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
    };
};
