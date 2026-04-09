import type { AppConfig } from './config.js';

export const buildLoggerOptions = (
    config: AppConfig,
) => {
    if (config.nodeEnv === 'development') {
        return {
            level: config.logLevel,
            transport: {
                target: 'pino-pretty',
                options: {
                    colorize: true,
                    translateTime: 'SYS:standard',
                    ignore: 'pid,hostname',
                },
            },
        };
    }

    return {
        level: config.logLevel,
    };
};