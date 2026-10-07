// Speicherfrist fuer Rohsnapshots und Sender (Datenschutzerklaerung: 14 Monate). Sie deckt den
// Backfill der Monatsberichte (REPORT_BACKFILL_MONTHS plus Zwei-Monats-Fenster) ab.
export const RETENTION_MONTHS = 14;

export const addUtcMonths = (date: Date, months: number): Date => {
    const result = new Date(date.getTime());
    result.setUTCMonth(result.getUTCMonth() + months);
    return result;
};

// Zeitpunkt, ab dem ein Eintrag geloescht wird.
export const retentionEnd = (from: Date): Date => addUtcMonths(from, RETENTION_MONTHS);

// Rohsnapshots laufen ab Eingang, Sender ab der letzten erfolgreichen Sendung (sonst Anlage).
export const senderRetentionStart = (sender: { created_at: Date; last_successful_send_at: Date | null }): Date =>
    sender.last_successful_send_at ?? sender.created_at;
