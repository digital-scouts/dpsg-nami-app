import { defineConfig } from 'vitest/config';

export default defineConfig({
    test: {
        // Der erste Lauf von mongodb-memory-server laedt das MongoDB-Binary herunter.
        hookTimeout: 120_000,
        testTimeout: 20_000,
    },
});
