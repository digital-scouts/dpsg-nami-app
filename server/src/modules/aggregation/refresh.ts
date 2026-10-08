import type { ServerDependencies } from '../../app/dependencies.js';
import {
    deriveStammState,
    type DerivedStammState,
    mergeAllStammSnapshots,
    snapshotWindowStart,
} from '../effectiveState/effectiveState.js';
import { BUND_AGGREGATION_TYPE, computeBundAggregate, computeBundAggregateFromDerived } from './aggregation.js';

// Das Bundesaggregat wird nicht nach jedem Snapshot neu berechnet, sonst liesse sich der Beitrag
// eines einzelnen Stammes aus zwei aufeinanderfolgenden Abrufen herausrechnen (S-01, S-12):
// - Wochenlauf (montags): alle Staemme neu; ihre Staende werden bis zum naechsten Wochenlauf
//   eingefroren (effective_states).
// - Nachtlauf (taeglich): nur Staemme, die noch nicht veroeffentlicht sind, kommen dazu.
export const PUBLICATION_HOUR_UTC = 3;
const WEEKLY_PUBLICATION_DAY_UTC = 1;
const DAY_MS = 24 * 60 * 60 * 1000;

type PublicationDependencies = Pick<
    ServerDependencies,
    'rawSnapshotsRepository' | 'effectiveStatesRepository' | 'weeklyAggregatesRepository'
>;

// Letzter Zeitpunkt des Nachtlaufs (03:00 UTC) bis einschliesslich now.
export const lastNightlySlot = (now: Date): Date => {
    const heute = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), PUBLICATION_HOUR_UTC);
    return new Date(heute <= now.getTime() ? heute : heute - DAY_MS);
};

// Letzter Zeitpunkt des Wochenlaufs (Montag 03:00 UTC) bis einschliesslich now.
export const lastWeeklySlot = (now: Date): Date => {
    const slot = lastNightlySlot(now);
    const tageZurueck = (slot.getUTCDay() - WEEKLY_PUBLICATION_DAY_UTC + 7) % 7;
    return new Date(slot.getTime() - tageZurueck * DAY_MS);
};

const loadCurrentStates = async (dependencies: PublicationDependencies, now: Date) => {
    const since = snapshotWindowStart(now);
    return mergeAllStammSnapshots(await dependencies.rawSnapshotsRepository.findSince(since), since, now);
};

// Wochenlauf: alle Staemme aus den Rohsnapshots neu zusammenfuehren und veroeffentlichen.
export const publishFullAggregate = async (dependencies: PublicationDependencies, now: Date): Promise<void> => {
    const states = await loadCurrentStates(dependencies, now);
    await dependencies.effectiveStatesRepository.replaceAll(states);
    await dependencies.weeklyAggregatesRepository.upsert(computeBundAggregate(states, now));
};

// Nachtlauf: Neue Staemme kommen dazu, bestehende bleiben auf dem Stand des Wochenlaufs, auch
// beim Zwei-Monats-Fenster. Liefert, ob sich das Aggregat geaendert hat.
export const publishNewStaemme = async (dependencies: PublicationDependencies, now: Date): Promise<boolean> => {
    const latest = await dependencies.weeklyAggregatesRepository.findLatest(BUND_AGGREGATION_TYPE);
    if (latest == null) {
        await publishFullAggregate(dependencies, now);
        return true;
    }

    const veroeffentlicht = await dependencies.effectiveStatesRepository.findAll();
    const bekannt = new Set(veroeffentlicht.map((state) => state.stamm_pseudonym));
    const since = snapshotWindowStart(now);
    const neue = (await loadCurrentStates(dependencies, now))
        .filter((state) => !bekannt.has(state.stamm_pseudonym))
        .flatMap((state) => {
            const derived = deriveStammState(state, since);
            return derived == null ? [] : [derived];
        });

    if (neue.length === 0) {
        await dependencies.weeklyAggregatesRepository.upsert({ ...latest, checked_at: now });
        return false;
    }

    for (const stamm of neue) {
        await dependencies.effectiveStatesRepository.upsert(stamm.state);
    }
    const eingefrorenSeit = snapshotWindowStart(latest.full_refresh_at);
    const eingefroren = veroeffentlicht
        .map((state) => deriveStammState(state, eingefrorenSeit))
        .filter((derived): derived is DerivedStammState => derived != null);
    await dependencies.weeklyAggregatesRepository.upsert(
        computeBundAggregateFromDerived([...eingefroren, ...neue], now, latest.full_refresh_at),
    );
    return true;
};

// Stuendlich und beim Start: holt einen faelligen Wochen- oder Nachtlauf nach.
export const runAggregatePublicationIfDue = async (
    dependencies: PublicationDependencies,
    now: Date,
): Promise<'woche' | 'nacht' | null> => {
    const latest = await dependencies.weeklyAggregatesRepository.findLatest(BUND_AGGREGATION_TYPE);

    if (latest?.full_refresh_at == null || latest.full_refresh_at.getTime() < lastWeeklySlot(now).getTime()) {
        await publishFullAggregate(dependencies, now);
        return 'woche';
    }

    if (latest.checked_at == null || latest.checked_at.getTime() < lastNightlySlot(now).getTime()) {
        return await publishNewStaemme(dependencies, now) ? 'nacht' : null;
    }

    return null;
};
