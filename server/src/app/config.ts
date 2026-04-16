import { z } from 'zod';

const logLevels = ['fatal', 'error', 'warn', 'info', 'debug', 'trace'] as const;

const envSchema = z.object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    HOST: z.string().trim().min(1).default('0.0.0.0'),
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),
    LOG_LEVEL: z.enum(logLevels).default('info'),
    PSEUDONYMIZATION_SECRET: z.string().trim().min(1),
    MONGODB_URI: z
        .string()
        .trim()
        .url()
        .default('mongodb://localhost:27017'),
    MONGODB_DATABASE: z.string().trim().min(1).default('nami_statistics_local'),
});

export type AppConfig = {
    nodeEnv: 'development' | 'test' | 'production';
    host: string;
    port: number;
    logLevel: (typeof logLevels)[number];
    pseudonymizationSecret: string;
    mongoDbUri: string;
    mongoDbDatabase: string;
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
        mongoDbUri: parsed.MONGODB_URI,
        mongoDbDatabase: parsed.MONGODB_DATABASE,
    };
};