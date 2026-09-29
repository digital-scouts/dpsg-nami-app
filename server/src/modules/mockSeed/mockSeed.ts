import type { ServerDependencies } from '../../app/dependencies.js';
import { rebuildEffectiveStatesAndAggregate } from '../aggregation/refresh.js';
import { buildRawSnapshotDocument } from '../stammesSnapshot/persistence.js';
import { pseudonymizeStammesSnapshot } from '../stammesSnapshot/pseudonymize.js';
import { parseStammesSnapshotPayload, SUPPORTED_SCHEMA_VERSION } from '../stammesSnapshot/schema.js';

// Synthetische Staemme fuer die Mock-Instanz (mock-namiapp.scout-link.de), damit eine
// einzelne Test-Installation ueber MIN_STAMM_COUNT_FOR_READ kommt und Bundeswerte erhaelt.

export const MOCK_SEED_INTERVAL_MS = 24 * 60 * 60 * 1000;

// So wenige Staemme liefern die seltenen Kennzahlen, damit die Unterdrueckung sichtbar wird.
export const MOCK_RARE_METRIC_STAMM_COUNT = 3;

const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;
const MAX_SOURCE_AGE_DAYS = 30;

// Deterministischer PRNG (mulberry32), damit jeder Seed-Stamm stabile Werte hat.
const createRandom = (seed: number) => {
    let state = seed >>> 0;

    return (min: number, max: number): number => {
        state = (state + 0x6d2b79f5) >>> 0;
        let t = state;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        const value = ((t ^ (t >>> 14)) >>> 0) / 4294967296;

        return min + Math.floor(value * (max - min + 1));
    };
};

type Random = ReturnType<typeof createRandom>;

const countByGender = (random: Random, min: number, max: number, withRare: boolean) => {
    const divers = withRare ? random(0, 1) : null;
    const geschlechtUnbekannt = random(0, 1);
    const binary = random(min, max);
    const maennlich = random(0, binary);
    const weiblich = binary - maennlich;

    return {
        gesamt: binary + (divers ?? 0) + geschlechtUnbekannt,
        maennlich,
        weiblich,
        divers,
        geschlecht_unbekannt: geschlechtUnbekannt,
    };
};

const leitende = (random: Random, withRare: boolean) => {
    const unter21 = random(0, 4);
    const von21Bis30 = random(2, 8);
    const von31Bis40 = random(0, 4);
    const von41Bis50 = random(0, 3);
    const von51Bis60 = random(0, 2);
    const ueber60 = withRare ? random(1, 2) : null;

    return {
        gesamt: unter21 + von21Bis30 + von31Bis40 + von41Bis50 + von51Bis60 + (ueber60 ?? 0),
        unter_21: unter21,
        von_21_bis_30: von21Bis30,
        von_31_bis_40: von31Bis40,
        von_41_bis_50: von41Bis50,
        von_51_bis_60: von51Bis60,
        ueber_60: ueber60,
    };
};

const buildMockMetrics = (index: number) => {
    const random = createRandom(index + 1);
    const withRare = index < MOCK_RARE_METRIC_STAMM_COUNT;

    const stufen = {
        biber: countByGender(random, 0, 12, withRare),
        woelflinge: countByGender(random, 5, 25, withRare),
        jungpfadfinder: countByGender(random, 5, 25, withRare),
        pfadfinder: countByGender(random, 3, 20, withRare),
        rover: countByGender(random, 0, 12, withRare),
    };
    const leitendeGesamt = leitende(random, withRare);
    const aktiveGesamt = Object.values(stufen).reduce((total, stufe) => total + stufe.gesamt, 0)
        + leitendeGesamt.gesamt;
    const familienermaessigt = Math.floor(aktiveGesamt * random(10, 25) / 100);
    const sozialermaessigt = Math.floor(aktiveGesamt * random(0, 8) / 100);

    return {
        aktive_mitglieder: {
            gesamt: aktiveGesamt,
            normaler_beitrag: aktiveGesamt - familienermaessigt - sozialermaessigt,
            familienermaessigter_beitrag: familienermaessigt,
            sozialermaessigter_beitrag: sozialermaessigt,
        },
        passive_mitglieder: random(0, 10),
        ...stufen,
        leitende: leitendeGesamt,
        leitende_biber: countByGender(random, 0, 3, false),
        leitende_woelflinge: countByGender(random, 1, 5, false),
        leitende_jungpfadfinder: countByGender(random, 1, 5, false),
        leitende_pfadfinder: countByGender(random, 1, 4, false),
        leitende_rover: countByGender(random, 0, 3, false),
        nicht_leitende_erwachsene: random(0, 8),
        stammesvorstand: random(2, 3),
        kuraten: random(0, 1),
    };
};

// Datenstaende relativ zu now gestaffelt, damit sie im Zwei-Monats-Fenster der Aggregation liegen.
export const buildMockSnapshotPayloads = (count: number, now: Date) =>
    Array.from({ length: count }, (_, index) => {
        const number = String(index + 1).padStart(2, '0');
        const sourceDataAsOf = new Date(now.getTime() - (index % MAX_SOURCE_AGE_DAYS) * DAY_MS - HOUR_MS);

        return {
            schema_version: SUPPORTED_SCHEMA_VERSION,
            stamm_id: `mock-stamm-${number}`,
            dv_id: `mock-dv-${(index % 5) + 1}`,
            sender_id: `mock-sender-${number}`,
            sent_at: new Date(sourceDataAsOf.getTime() + HOUR_MS / 2).toISOString(),
            source_data_as_of: sourceDataAsOf.toISOString(),
            metrics: buildMockMetrics(index),
        };
    });

// Laeuft durch dieselbe Validierung und Pseudonymisierung wie echte Snapshots. Seed-Sender
// werden nicht registriert: Lesen duerfen nur echte Installationen nach eigenem Senden.
export const seedMockSnapshots = async (
    dependencies: ServerDependencies,
    pseudonymizationSecret: string,
    count: number,
    now: Date,
): Promise<void> => {
    for (const payload of buildMockSnapshotPayloads(count, now)) {
        const snapshot = parseStammesSnapshotPayload(payload, now);
        await dependencies.rawSnapshotsRepository.insert(
            buildRawSnapshotDocument(pseudonymizeStammesSnapshot(snapshot, pseudonymizationSecret), now),
        );
    }

    await rebuildEffectiveStatesAndAggregate(
        dependencies.rawSnapshotsRepository,
        dependencies.effectiveStatesRepository,
        dependencies.weeklyAggregatesRepository,
        now,
    );
};
