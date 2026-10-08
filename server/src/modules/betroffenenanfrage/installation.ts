import type { ServerDependencies } from '../../app/dependencies.js';
import { publishFullAggregate } from '../aggregation/refresh.js';
import type { RawSnapshotDocument } from '../stammesSnapshot/persistence.js';
import { buildPseudonym } from '../stammesSnapshot/pseudonymize.js';

// Auskunft und Loeschung auf Anfrage (Art. 15/17 DSGVO). Die betroffene Person nennt die
// Installations-ID aus der App; der Server kennt nur deren Pseudonym und rechnet es hier nach.

type Dependencies = Pick<
    ServerDependencies,
    'rawSnapshotsRepository' | 'senderRepository' | 'effectiveStatesRepository' | 'weeklyAggregatesRepository'
>;

export type InstallationsAuskunft = {
    sender_pseudonym: string;
    // Ohne Secret-Hash: Er ist kein Inhalt der Anfrage und darf den Server nicht verlassen.
    sender: { created_at: Date; last_successful_send_at: Date | null } | null;
    snapshots: RawSnapshotDocument[];
};

export type InstallationsLoeschung = {
    sender_pseudonym: string;
    geloeschte_snapshots: number;
    sender_geloescht: boolean;
};

const senderPseudonymFuer = (senderId: string, pseudonymizationSecret: string): string => {
    const id = senderId.trim();
    if (id.length === 0) {
        throw new Error('Installations-ID fehlt.');
    }
    return buildPseudonym('sender', id, pseudonymizationSecret);
};

export const auskunftFuerInstallation = async (
    dependencies: Dependencies,
    senderId: string,
    pseudonymizationSecret: string,
): Promise<InstallationsAuskunft> => {
    const senderPseudonym = senderPseudonymFuer(senderId, pseudonymizationSecret);
    const sender = await dependencies.senderRepository.findByPseudonym(senderPseudonym);

    return {
        sender_pseudonym: senderPseudonym,
        sender: sender == null
            ? null
            : { created_at: sender.created_at, last_successful_send_at: sender.last_successful_send_at },
        snapshots: await dependencies.rawSnapshotsRepository.findBySender(senderPseudonym),
    };
};

// Loescht Snapshots und Sender und veroeffentlicht das Aggregat sofort ohne sie neu.
export const loescheInstallation = async (
    dependencies: Dependencies,
    senderId: string,
    pseudonymizationSecret: string,
    now: Date,
): Promise<InstallationsLoeschung> => {
    const senderPseudonym = senderPseudonymFuer(senderId, pseudonymizationSecret);
    const geloeschteSnapshots = await dependencies.rawSnapshotsRepository.deleteBySender(senderPseudonym);
    const senderGeloescht = await dependencies.senderRepository.delete(senderPseudonym);

    // Geloeschte Daten sollen sofort aus dem Aggregat verschwinden, nicht erst im Wochenlauf.
    await publishFullAggregate(dependencies, now);

    return {
        sender_pseudonym: senderPseudonym,
        geloeschte_snapshots: geloeschteSnapshots,
        sender_geloescht: senderGeloescht,
    };
};
