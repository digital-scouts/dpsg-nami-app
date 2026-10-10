// Der Betreiber gibt Zeiten in deutscher Zeit ein (datetime-local ohne Zone); gespeichert wird UTC.

const FORMAT = new Intl.DateTimeFormat('de-DE', {
    timeZone: 'Europe/Berlin',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    weekday: 'short',
    hourCycle: 'h23',
});

const teile = (date: Date) => {
    const t = Object.fromEntries(FORMAT.formatToParts(date).map((p) => [p.type, p.value]));
    return {
        jahr: Number(t.year),
        monat: Number(t.month),
        tag: Number(t.day),
        stunde: Number(t.hour),
        minute: Number(t.minute),
        wochentag: (t.weekday ?? '').replace('.', ''),
    };
};

// Abstand der deutschen Zeit zu UTC zu diesem Zeitpunkt in ms (Winter 1 h, Sommer 2 h).
const versatz = (date: Date): number => {
    const t = teile(date);
    return Date.UTC(t.jahr, t.monat - 1, t.tag, t.stunde, t.minute) - Math.floor(date.getTime() / 60000) * 60000;
};

const zwei = (wert: number) => String(wert).padStart(2, '0');

// Wert fuer <input type="datetime-local">, z. B. 2026-10-12T18:00.
export const alsBerlinFeld = (date: Date): string => {
    const t = teile(date);
    return `${t.jahr}-${zwei(t.monat)}-${zwei(t.tag)}T${zwei(t.stunde)}:${zwei(t.minute)}`;
};

// Leer heisst null; eine Zeit, die es in deutscher Zeit nicht gibt (Zeitumstellung), ist ungueltig.
export const ausBerlinFeld = (wert: string): Date | null | 'ungueltig' => {
    const text = wert.trim();
    if (text === '') {
        return null;
    }
    const treffer = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/.exec(text);
    if (treffer == null) {
        return 'ungueltig';
    }
    const [jahr, monat, tag, stunde, minute] = treffer.slice(1).map(Number);
    const geschaetzt = Date.UTC(jahr, monat - 1, tag, stunde, minute);
    const erster = new Date(geschaetzt - versatz(new Date(geschaetzt)));
    const ergebnis = new Date(geschaetzt - versatz(erster));
    return alsBerlinFeld(ergebnis) === text ? ergebnis : 'ungueltig';
};

// Lesbar fuer Admin-Seiten und Telegram, z. B. „Sa 12.10.2026, 18:00“.
export const alsBerlinText = (date: Date): string => {
    const t = teile(date);
    return `${t.wochentag} ${zwei(t.tag)}.${zwei(t.monat)}.${t.jahr}, ${zwei(t.stunde)}:${zwei(t.minute)}`;
};
