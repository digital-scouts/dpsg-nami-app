import type { FastifyInstance } from 'fastify';

export const registerHealthRoutes = (server: FastifyInstance): void => {
    server.get('/health', async () => ({
        status: 'ok',
        service: 'nami-statistics-server',
    }));
};