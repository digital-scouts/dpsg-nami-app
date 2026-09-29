export type Clock = () => Date;

export const systemClock: Clock = () => new Date();

export const subtractUtcMonths = (date: Date, months: number): Date => {
    const result = new Date(date.getTime());
    result.setUTCMonth(result.getUTCMonth() - months);
    return result;
};

export const subtractDays = (date: Date, days: number): Date =>
    new Date(date.getTime() - days * 24 * 60 * 60 * 1000);

// ISO-8601-Woche, z. B. "2026-W40". Die Woche gehoert zu dem Jahr, in dem ihr Donnerstag liegt.
export const toIsoWeek = (date: Date): string => {
    const target = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
    const dayOfWeek = target.getUTCDay() === 0 ? 7 : target.getUTCDay();
    target.setUTCDate(target.getUTCDate() + 4 - dayOfWeek);

    const weekYear = target.getUTCFullYear();
    const firstDayOfYear = Date.UTC(weekYear, 0, 1);
    const week = Math.ceil(((target.getTime() - firstDayOfYear) / (24 * 60 * 60 * 1000) + 1) / 7);

    return `${weekYear}-W${String(week).padStart(2, '0')}`;
};
