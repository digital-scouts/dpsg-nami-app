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

export type ReportMessage = {
    subject: string;
    text: string;
};

// Kurze Nachricht nach Abschluss eines Monats, z. B. per Telegram.
export type ReportNotifier = {
    send(text: string): Promise<void>;
};

export type MonthlyReportDocument = {
    month: string;
    figures: ReportFigures;
    created_at: Date;
    notified_at: Date | null;
};

export type MonthlyReportsRepository = {
    // Legt den Bericht nur an, wenn es fuer den Monat noch keinen gibt.
    insertIfAbsent(document: MonthlyReportDocument): Promise<void>;
    find(month: string): Promise<MonthlyReportDocument | null>;
    // Neueste zuerst.
    findAll(): Promise<MonthlyReportDocument[]>;
    markNotified(month: string, notifiedAt: Date): Promise<void>;
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
        // Staemme, fuer die nur Teilnahmen ohne Werte vorliegen (z. B. Leitungen ohne lesbare
        // Rollen). Sie zaehlen nicht als teilnehmend. Fehlt in Berichten vor 2026-10.
        ohne_werte?: number;
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

// Berechnet die Kennzahlen zum Stichtag, als waere er "jetzt": Es zaehlen nur Snapshots, die
// bis dahin und im Zwei-Monats-Fenster davor eingegangen sind. Standard ist das
// Monatsende; fuer den laufenden Monat gilt der aktuelle Zeitpunkt.
export const computeReportFigures = (
    month: string,
    rawSnapshots: RawSnapshotDocument[],
    senders: SenderActivity[],
    bis?: Date,
): ReportFigures => {
    const start = monthStart(month);
    const monatsEnde = nextMonthStart(month);
    const stichtag = new Date(Math.min(monatsEnde.getTime() - 1, (bis ?? monatsEnde).getTime()));
    const end = new Date(stichtag.getTime() + 1);
    const since = snapshotWindowStart(stichtag);
    const imMonat = (datum: Date) => datum.getTime() >= start.getTime() && datum.getTime() < end.getTime();

    const bisStichtag = rawSnapshots.filter((snapshot) => snapshot.received_at.getTime() < end.getTime());
    const merged = mergeAllStammSnapshots(bisStichtag, since, stichtag);
    const derived = merged
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
            ohne_werte: merged.length - derived.length,
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
        zeile('nur Teilnahme ohne Werte', staemme.ohne_werte ?? 0, vormonat.staemme.ohne_werte ?? 0),
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
        '„Nur Teilnahme ohne Werte“ zählt Stämme, deren Sender teilen wollen, aber keine lesbaren Werte haben; sie zählen nicht als teilnehmend.',
        'Der Report enthält nur Zählwerte und die gespeicherten DV- und Bezirks-IDs.',
    ].join('\n');

    return {
        subject: `NaMi-Statistik: Monatsreport ${aktuell.month} – ${staemme.teilnehmend} Stämme, ${installationen.aktiv} aktive Installationen`,
        text,
    };
};

const loadReportInputs = async (
    dependencies: Pick<ServerDependencies, 'rawSnapshotsRepository' | 'senderRepository'>,
    fruehesterMonat: string,
) => ({
    rawSnapshots: await dependencies.rawSnapshotsRepository.findSince(snapshotWindowStart(monthStart(fruehesterMonat))),
    senders: await dependencies.senderRepository.listActivity(),
});

const vormonatVon = (month: string): string => toMonth(subtractUtcMonths(monthStart(month), 1));

// Textfassung fuer die Kommandozeile.
export const buildMonthlyReport = async (
    dependencies: Pick<ServerDependencies, 'rawSnapshotsRepository' | 'senderRepository'>,
    month: string,
    minStammCount: number,
): Promise<ReportMessage> => {
    const vormonat = vormonatVon(month);
    const { rawSnapshots, senders } = await loadReportInputs(dependencies, vormonat);

    return formatMonthlyReport(
        computeReportFigures(month, rawSnapshots, senders),
        computeReportFigures(vormonat, rawSnapshots, senders),
        minStammCount,
    );
};

export const formatTelegramMessage = (
    aktuell: ReportFigures,
    vormonat: ReportFigures | null,
    minStammCount: number,
    adminUrl: string | null,
): string => {
    const vorher = (wert: number | undefined) => (wert == null ? '' : ` (${wert})`);
    const regionen = (werte: Record<string, number>) =>
        Object.entries(werte).filter(([key, wert]) => key !== UNBEKANNT && wert >= minStammCount).length;

    return [
        `NaMi-Statistik ${aktuell.month}`,
        `Stämme: ${aktuell.staemme.teilnehmend}${vorher(vormonat?.staemme.teilnehmend)}`
            + ` – vollständig ${aktuell.staemme.vollstaendig}, nur Gruppen ${aktuell.staemme.nur_gruppen}, gemischt ${aktuell.staemme.gemischt}`
            + `, ohne Werte ${aktuell.staemme.ohne_werte ?? 0}`,
        `Aktive Installationen: ${aktuell.installationen.aktiv}${vorher(vormonat?.installationen.aktiv)}, neu ${aktuell.installationen.neu}`,
        `Gruppen mit Wert: ${aktuell.gruppen.mit_wert}${vorher(vormonat?.gruppen.mit_wert)}, mehrfach abgedeckt ${aktuell.gruppen.mehrfach_abgedeckt}`,
        `DVs mit ≥ ${minStammCount} Stämmen: ${regionen(aktuell.staemme_je_dv)}, Bezirke: ${regionen(aktuell.staemme_je_bezirk)}`,
        ...(adminUrl == null ? [] : ['', adminUrl]),
    ].join('\n');
};

// Wie viele abgeschlossene Monate rueckwirkend berechnet werden, wenn Berichte fehlen.
export const REPORT_BACKFILL_MONTHS = 12;

// Legt fehlende Monatsberichte an (rueckwirkend aus den Rohdaten) und benachrichtigt einmal
// ueber den Vormonat. Liefert den gemeldeten Monat oder null.
export const runMonthlyReportIfDue = async (
    dependencies: Pick<ServerDependencies, 'rawSnapshotsRepository' | 'senderRepository' | 'monthlyReportsRepository'>,
    notifier: ReportNotifier | null,
    options: { minStammCount: number; adminUrl: string | null },
    now: Date,
): Promise<string | null> => {
    const vormonat = previousMonth(now);
    const monate = Array.from({ length: REPORT_BACKFILL_MONTHS }, (_, index) =>
        toMonth(subtractUtcMonths(monthStart(vormonat), index)));
    const vorhanden = new Set((await dependencies.monthlyReportsRepository.findAll()).map((report) => report.month));
    const fehlend = monate.filter((month) => !vorhanden.has(month));

    if (fehlend.length > 0) {
        const { rawSnapshots, senders } = await loadReportInputs(dependencies, fehlend[fehlend.length - 1] ?? vormonat);
        for (const month of fehlend) {
            const figures = computeReportFigures(month, rawSnapshots, senders);
            // Leere Monate vor den ersten Daten nicht rueckwirkend anlegen.
            if (month !== vormonat && figures.installationen.gesamt === 0 && figures.staemme.teilnehmend === 0) {
                continue;
            }
            await dependencies.monthlyReportsRepository.insertIfAbsent({
                month,
                figures,
                created_at: now,
                // Nur der Vormonat wird gemeldet, rueckwirkend angelegte Monate nicht.
                notified_at: month === vormonat ? null : now,
            });
        }
    }

    const bericht = await dependencies.monthlyReportsRepository.find(vormonat);
    if (notifier == null || bericht == null || bericht.notified_at != null) {
        return null;
    }

    const vorher = await dependencies.monthlyReportsRepository.find(vormonatVon(vormonat));
    await notifier.send(formatTelegramMessage(bericht.figures, vorher?.figures ?? null, options.minStammCount, options.adminUrl));
    await dependencies.monthlyReportsRepository.markNotified(vormonat, now);

    return vormonat;
};

// Laufender Monat bis jetzt, fuer die Web-Ansicht.
export const computeCurrentFigures = async (
    dependencies: Pick<ServerDependencies, 'rawSnapshotsRepository' | 'senderRepository'>,
    now: Date,
): Promise<ReportFigures> => {
    const month = toMonth(now);
    const { rawSnapshots, senders } = await loadReportInputs(dependencies, month);
    return computeReportFigures(month, rawSnapshots, senders, now);
};
