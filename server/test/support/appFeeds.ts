import type { MeldungDocument, VersionDocument } from '../../src/modules/appFeeds/model.js';
import { hashAdminPassword } from '../../src/modules/admin/password.js';
import { buildTestConfig } from './fixtures.js';

export const adminConfig = (overrides: NodeJS.ProcessEnv = {}) => buildTestConfig({
    ADMIN_USER: 'betrieb',
    ADMIN_PASSWORD_HASH: hashAdminPassword('ein-langes-passwort'),
    ...overrides,
});

export const basic = () => ({
    authorization: `Basic ${Buffer.from('betrieb:ein-langes-passwort').toString('base64')}`,
});

export const meldung = (overrides: Partial<MeldungDocument> = {}): MeldungDocument => ({
    id: 'wartung',
    type: 'warn',
    platform: 'all',
    title: { de: 'Wartung', en: 'Maintenance' },
    body: { de: 'Text', en: 'Text' },
    starts_at: new Date('2026-04-01T00:00:00Z'),
    ends_at: new Date('2026-04-20T00:00:00Z'),
    external_link: 'https://status.example.org',
    deep_link: null,
    created_at: new Date('2026-03-30T10:00:00Z'),
    updated_at: new Date('2026-03-30T10:00:00Z'),
    ...overrides,
});

export const version = (overrides: Partial<VersionDocument> = {}): VersionDocument => ({
    plattform: 'ios',
    latest: '1.0.0',
    min_supported: '1.0.0',
    store_url: 'https://apps.apple.com/de/app/nami/id6468066816',
    security: null,
    updated_at: new Date('2026-04-09T21:14:00Z'),
    ...overrides,
});
