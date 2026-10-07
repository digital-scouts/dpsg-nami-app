import { createHmac, timingSafeEqual } from 'node:crypto';

import { AppError } from '../../shared/errors.js';

// Installations-Credentials: Die App erzeugt pro Installation eine zufaellige ID (sender_id)
// und ein Secret. Beim ersten erfolgreichen Senden wird das Secret-Hash hinterlegt
// (Trust on First Use); danach muss jedes Secret dazu passen.

export type SenderDocument = {
    sender_pseudonym: string;
    secret_hash: string;
    created_at: Date;
    last_successful_send_at: Date | null;
};

export type SenderRegistrationResult = 'registered' | 'already_registered';

export type SenderRepository = {
    findByPseudonym(senderPseudonym: string): Promise<SenderDocument | null>;
    // Legt den Sender nur an, wenn es ihn noch nicht gibt (atomar, unique auf sender_pseudonym).
    registerIfAbsent(document: SenderDocument): Promise<SenderRegistrationResult>;
    markSuccessfulSend(senderPseudonym: string, sentAt: Date): Promise<void>;
    // Nur Zeitpunkte, ohne Pseudonym und Secret-Hash, fuer den Monatsreport.
    listActivity(): Promise<SenderActivity[]>;
    // Loeschung auf Anfrage; true, wenn es den Sender gab.
    delete(senderPseudonym: string): Promise<boolean>;
};

export type SenderActivity = Pick<SenderDocument, 'created_at' | 'last_successful_send_at'>;

const MIN_SECRET_LENGTH = 32;
const MAX_SECRET_LENGTH = 256;

export const PARTICIPATION_WINDOW_DAYS = 14;

export const hashSenderSecret = (secret: string, pepper: string): string =>
    createHmac('sha256', pepper).update(secret).digest('hex');

const secretHashesMatch = (expectedHash: string, actualHash: string): boolean => {
    const expected = Buffer.from(expectedHash, 'hex');
    const actual = Buffer.from(actualHash, 'hex');

    return expected.length === actual.length && timingSafeEqual(expected, actual);
};

const invalidCredentialsError = () =>
    new AppError('Sender credentials are invalid', 401, 'invalid_sender_credentials');

export const extractBearerSecret = (authorizationHeader: string | undefined): string => {
    const match = /^Bearer\s+(\S+)$/i.exec(authorizationHeader?.trim() ?? '');
    const secret = match?.[1];

    if (secret == null) {
        throw new AppError('Sender credentials are missing', 401, 'missing_sender_credentials');
    }

    if (secret.length < MIN_SECRET_LENGTH || secret.length > MAX_SECRET_LENGTH) {
        throw invalidCredentialsError();
    }

    return secret;
};

export const verifyOrRegisterSender = async (
    repository: SenderRepository,
    senderPseudonym: string,
    secret: string,
    pepper: string,
    now: Date,
): Promise<void> => {
    const secretHash = hashSenderSecret(secret, pepper);
    const existing = await repository.findByPseudonym(senderPseudonym);

    if (existing != null) {
        if (!secretHashesMatch(existing.secret_hash, secretHash)) {
            throw invalidCredentialsError();
        }
        return;
    }

    const result = await repository.registerIfAbsent({
        sender_pseudonym: senderPseudonym,
        secret_hash: secretHash,
        created_at: now,
        last_successful_send_at: null,
    });

    if (result === 'already_registered') {
        // Parallele Erstregistrierung: erneut gegen den gespeicherten Hash pruefen.
        const concurrent = await repository.findByPseudonym(senderPseudonym);

        if (concurrent == null || !secretHashesMatch(concurrent.secret_hash, secretHash)) {
            throw invalidCredentialsError();
        }
    }
};

export const assertActiveParticipant = async (
    repository: SenderRepository,
    senderPseudonym: string,
    secret: string,
    pepper: string,
    now: Date,
): Promise<void> => {
    const sender = await repository.findByPseudonym(senderPseudonym);

    if (sender == null) {
        throw new AppError('Sender has not shared any snapshot yet', 403, 'not_participating');
    }

    if (!secretHashesMatch(sender.secret_hash, hashSenderSecret(secret, pepper))) {
        throw invalidCredentialsError();
    }

    const participationStart = now.getTime() - PARTICIPATION_WINDOW_DAYS * 24 * 60 * 60 * 1000;
    const lastSend = sender.last_successful_send_at;

    if (lastSend == null || lastSend.getTime() < participationStart) {
        throw new AppError(
            `Sender has not shared a snapshot within the last ${PARTICIPATION_WINDOW_DAYS} days`,
            403,
            'not_participating',
        );
    }
};
