import { MongoClient } from 'mongodb';

import type { AppConfig } from '../../app/config.js';

export const buildMongoDbClient = (config: AppConfig): MongoClient =>
    new MongoClient(config.mongoDbUri, {
        appName: 'nami-statistics-server',
        connectTimeoutMS: 5000,
        serverSelectionTimeoutMS: 5000,
    });

export const connectToMongoDb = async (
    client: MongoClient,
    config: AppConfig,
): Promise<void> => {
    await client.connect();
    await client.db(config.mongoDbDatabase).command({ ping: 1 });
};