import type { ServerDependencies } from '../../app/dependencies.js';
import { subtractUtcMonths } from '../../shared/time.js';
import {
    deriveStammState,
    type DerivedStammState,
    mergeAllStammSnapshots,
    snapshotWindowStart,
} from '../effectiveState/effectiveState.js';
import type { SenderActivity } from '../senderAuth/senderAuth.js';
import type { RawSnapshotDocument } from '../stammesSnapshot/persistence.js';
import { type Stufe, STUFEN } from '../stammesSnapshot/schema.js';

// Monatlicher Report ueber den Kreis der Teilnehmenden (spec/monatsreport.md). Enthaelt nur
// Zaehlwerte und die gespeicherten DV- und Bezirks-IDs.

export type ReportStatusRepository = {
    findLastReportedMonth(): Promise<string | null>;
    markReported(month: string, sentAt: Date): Promise<void>;
};

export type ReportMessage = {
    subject: string;
    text: string;
};

export type ReportMailer = {
    send(message: ReportMessage): Promise<void>;
};

const MONTH_PATTERN = /^(\d{4})-(0[1-9]|1[0-2])$/;

export const isValidMonth = (month: string): boolean => MONTH_PATTERN.test(month);

export const monthStart = (month: string): Date => {
    const match = MONTH_PATTERN.exec(month);
    if (match == null) {
        throw new Error(`Ungueltiger Monat: ${month}`);
    }
    return new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, 1));
};

export const toMonth = (date: Date): string =>
    `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;

export const previousMonth = (date: Date): string => toMonth(subtractUtcMonths(monthStart(toMonth(date)), 1));

const nextMonthStart = (month: string): Date => {
    const start = monthStart(month);
    return new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 1));
};

export type ReportFigures = {
    month: string;
    stichtag: Date;
    installationen: { aktiv: number; neu: number; gesamt: number };
    staemme: {
        teilnehmend: number;
        vollstaendig: number;
        nur_gruppen: number;
        gemischt: number;
        mehrere_sender: number;
    };
    gruppen: {
        mit_wert: number;
        je_stufe: Record<Stufe, number>;
        mehrfach_abgedeckt: number;
        verworfene_werte: number;
        unvollstaendige_stufen: number;
    };
    staemme_je_dv: Record<string, number>;
    staemme_je_bezirk: Record<string, number>;
};

const UNBEKANNT = 'unbekannt';

const zaehleJe = (werte: string[]): Record<string, number> => {
    const result: Record<string, number> = {};
    for (const wert of werte) {
        result[wert] = (result[wert] ?? 0) + 1;
    }
    return result;
};

// Berechnet die Kennzahlen zum Monatsende, als waere der Stichtag "jetzt": Es zaehlen nur
// Snapshots, die bis dahin eingegangen sind und im Zwei-Monats-Fenster davor liegen.
export const computeReportFigures = (
    month: string,
    rawSnapshots: RawSnapshotDocument[],
    senders: SenderActivity[],
): ReportFigures => {
    const start = monthStart(month);
    const end = nextMonthStart(month);
    const stichtag = new Date(end.getTime() - 1);
    const since = snapshotWindowStart(stichtag);
    const imMonat = (datum: Date) => datum.getTime() >= start.getTime() && datum.getTime() < end.getTime();

    const bisStichtag = rawSnapshots.filter((snapshot) =>
        snapshot.received_at.getTime() < end.getTime()
        && snapshot.source_data_as_of.getTime() <= stichtag.getTime());
    const derived = mergeAllStammSnapshots(bisStichtag, since)
        .map((state) => deriveStammState(state, since))
        .filter((stamm): stamm is DerivedStammState => stamm != null);

    const jeStufe = Object.fromEntries(STUFEN.map((stufe) => [
        stufe,
        derived.reduce((summe, stamm) => summe + stamm.gruppen.filter((gruppe) => gruppe.stufe === stufe).length, 0),
    ])) as Record<Stufe, number>;
    const alleGruppen = derived.flatMap((stamm) => stamm.state.gruppen);

    return {
        month,
        stichtag,
        installationen: {
            aktiv: new Set(rawSnapshots.filter((snapshot) => imMonat(snapshot.received_at))
                .map((snapshot) => snapshot.sender_pseudonym)).size,
            neu: senders.filter((sender) => imMonat(sender.created_at)).length,
            gesamt: senders.filter((sender) => sender.created_at.getTime() < end.getTime()).length,
        },
        staemme: {
            teilnehmend: derived.length,
            vollstaendig: derived.filter((stamm) => stamm.art === 'vollstaendig').length,
            nur_gruppen: derived.filter((stamm) => stamm.art === 'nur_gruppen').length,
            gemischt: derived.filter((stamm) => stamm.art === 'gemischt').length,
            mehrere_sender: derived.filter((stamm) => stamm.state.sender_count > 1).length,
        },
        gruppen: {
            mit_wert: derived.reduce((summe, stamm) => summe + stamm.gruppen.length, 0),
            je_stufe: jeStufe,
            mehrfach_abgedeckt: alleGruppen.filter((gruppe) => gruppe.abdeckende_sender > 1).length,
            verworfene_werte: alleGruppen.reduce((summe, gruppe) => summe + Math.max(0, gruppe.abdeckende_sender - 1), 0),
            unvollstaendige_stufen: derived.reduce((summe, stamm) => summe + stamm.unvollstaendige_stufen, 0),
        },
        staemme_je_dv: zaehleJe(derived.map((stamm) => stamm.state.dv_id ?? UNBEKANNT)),
        staemme_je_bezirk: zaehleJe(derived.map((stamm) => stamm.state.bezirk_id ?? UNBEKANNT)),
    };
};

const STUFEN_NAMEN: Record<Stufe, string> = {
    biber: 'Biber',
    woelflinge: 'Wölflinge',
    jungpfadfinder: 'Jungpfadfinder',
    pfadfinder: 'Pfadfinder',
    rover: 'Rover',
};

const datum = (date: Date): string =>
    `${String(date.getUTCDate()).padStart(2, '0')}.${String(date.getUTCMonth() + 1).padStart(2, '0')}.${date.getUTCFullYear()}`;

export const formatMonthlyReport = (
    aktuell: ReportFigures,
    vormonat: ReportFigures,
    minStammCount: number,
): ReportMessage => {
    const zeile = (label: string, wert: number, vorher?: number, einzug = 2) =>
        `${' '.repeat(einzug)}${`${label}:`.padEnd(34 - einzug)}${String(wert).padStart(5)}${vorher == null ? '' : `  (${vorher})`}`;
    const regionen = (titel: string, aktuelleWerte: Record<string, number>, vorherigeWerte: Record<string, number>) => {
        const schluessel = Object.keys(aktuelleWerte).sort((a, b) =>
            (aktuelleWerte[b] ?? 0) - (aktuelleWerte[a] ?? 0) || a.localeCompare(b));
        const erreicht = schluessel.filter((key) => key !== UNBEKANNT && (aktuelleWerte[key] ?? 0) >= minStammCount).length;
        return [
            `${titel} (${erreicht} mit mindestens ${minStammCount} Stämmen)`,
            ...(schluessel.length === 0 ? ['  keine'] : schluessel.map((key) => {
                const wert = aktuelleWerte[key] ?? 0;
                const marke = key !== UNBEKANNT && wert >= minStammCount ? ' ✓' : '';
                return `${zeile(key, wert, vorherigeWerte[key] ?? 0)}${marke}`;
            })),
        ];
    };

    const { installationen, staemme, gruppen } = aktuell;
    const text = [
        `NaMi-Statistikserver – Monatsreport ${aktuell.month}`,
        '',
        `Stichtag ${datum(aktuell.stichtag)}. Werte in Klammern: Vormonat (${vormonat.month}).`,
        '',
        'Installationen',
        zeile('aktiv im Monat', installationen.aktiv, vormonat.installationen.aktiv),
        zeile('neu im Monat', installationen.neu, vormonat.installationen.neu),
        zeile('gesamt', installationen.gesamt, vormonat.installationen.gesamt),
        '',
        'Stämme',
        zeile('teilnehmend', staemme.teilnehmend, vormonat.staemme.teilnehmend),
        zeile('vollständig', staemme.vollstaendig, vormonat.staemme.vollstaendig, 4),
        zeile('nur Gruppen', staemme.nur_gruppen, vormonat.staemme.nur_gruppen, 4),
        zeile('gemischt', staemme.gemischt, vormonat.staemme.gemischt, 4),
        zeile('mit mehreren Sendern', staemme.mehrere_sender, vormonat.staemme.mehrere_sender),
        '',
        'Gruppen',
        zeile('mit Wert', gruppen.mit_wert, vormonat.gruppen.mit_wert),
        ...STUFEN.map((stufe) => zeile(STUFEN_NAMEN[stufe], gruppen.je_stufe[stufe], vormonat.gruppen.je_stufe[stufe], 4)),
        zeile('von mehreren abgedeckt', gruppen.mehrfach_abgedeckt, vormonat.gruppen.mehrfach_abgedeckt),
        zeile('verworfene ältere Gruppenwerte', gruppen.verworfene_werte, vormonat.gruppen.verworfene_werte),
        zeile('unvollständige Stufen', gruppen.unvollstaendige_stufen, vormonat.gruppen.unvollstaendige_stufen),
        '',
        ...regionen('Stämme je DV', aktuell.staemme_je_dv, vormonat.staemme_je_dv),
        '',
        ...regionen('Stämme je Bezirk', aktuell.staemme_je_bezirk, vormonat.staemme_je_bezirk),
        '',
        '„Unvollständige Stufen“ zählt Stamm-Stufen-Paare, bei denen mindestens eine Gruppe keinen Wert hat.',
        'Der Report enthält nur Zählwerte und die gespeicherten DV- und Bezirks-IDs.',
    ].join('\n');

    return {
        subject: `NaMi-Statistik: Monatsreport ${aktuell.month} – ${staemme.teilnehmend} Stämme, ${installationen.aktiv} aktive Installationen`,
        text,
    };
};

// Laedt alle Snapshots, die fuer Monat und Vormonat gebraucht werden, und baut den Report.
export const buildMonthlyReport = async (
    dependencies: Pick<ServerDependencies, 'rawSnapshotsRepository' | 'senderRepository'>,
    month: string,
    minStammCount: number,
): Promise<ReportMessage> => {
    const vormonat = toMonth(subtractUtcMonths(monthStart(month), 1));
    const rawSnapshots = await dependencies.rawSnapshotsRepository.findSince(snapshotWindowStart(monthStart(vormonat)));
    const senders = await dependencies.senderRepository.listActivity();

    return formatMonthlyReport(
        computeReportFigures(month, rawSnapshots, senders),
        computeReportFigures(vormonat, rawSnapshots, senders),
        minStammCount,
    );
};

// Verschickt den Report des Vormonats, falls er noch nicht verschickt wurde. Liefert den
// berichteten Monat oder null.
export const runMonthlyReportIfDue = async (
    dependencies: Pick<ServerDependencies, 'rawSnapshotsRepository' | 'senderRepository' | 'reportStatusRepository'>,
    mailer: ReportMailer,
    minStammCount: number,
    now: Date,
): Promise<string | null> => {
    const month = previousMonth(now);
    const zuletzt = await dependencies.reportStatusRepository.findLastReportedMonth();

    if (zuletzt != null && zuletzt >= month) {
        return null;
    }

    await mailer.send(await buildMonthlyReport(dependencies, month, minStammCount));
    await dependencies.reportStatusRepository.markReported(month, now);

    return month;
};
