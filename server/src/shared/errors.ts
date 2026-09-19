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

export const asAppError = (error: unknown): AppError => {
    if (error instanceof AppError) {
        return error;
    }

    if (typeof error === 'object' && error != null) {
        const errorLike = error as ErrorLike;

        return new AppError(
            errorLike.message ?? 'Unexpected server error',
            errorLike.statusCode ?? 500,
            errorLike.code ?? 'internal_error',
            errorLike.fields,
        );
    }

    return new AppError('Unexpected server error');
};