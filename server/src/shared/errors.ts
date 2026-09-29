type ErrorLike = {
    statusCode?: number;
    code?: string;
    message?: string;
    fields?: string[];
};

export class AppError extends Error {
    constructor(
        message: string,
        readonly statusCode = 500,
        readonly code = 'internal_error',
        readonly fields?: string[],
    ) {
        super(message);
        this.name = 'AppError';
    }
}

// Fastify-interne Fehlercodes (FST_*) werden auf stabile, dokumentierte Codes abgebildet.
const codeForClientStatus = (statusCode: number): string => {
    switch (statusCode) {
        case 413:
            return 'payload_too_large';
        case 415:
            return 'unsupported_media_type';
        case 429:
            return 'rate_limited';
        default:
            return 'invalid_request';
    }
};

export const asAppError = (error: unknown): AppError => {
    if (error instanceof AppError) {
        return error;
    }

    if (typeof error === 'object' && error != null) {
        const errorLike = error as ErrorLike;
        const statusCode = errorLike.statusCode ?? 500;

        // Interne Fehlermeldungen (z. B. von MongoDB) duerfen nicht an Clients gelangen.
        if (statusCode >= 500) {
            return new AppError('Unexpected server error');
        }

        return new AppError(
            errorLike.message ?? 'Invalid request',
            statusCode,
            codeForClientStatus(statusCode),
            errorLike.fields,
        );
    }

    return new AppError('Unexpected server error');
};
