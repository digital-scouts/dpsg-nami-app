// Kurze Textnachricht an den Betreiber, z. B. per Telegram: Monatsreport und Aenderungen an
// Meldungen und Versionen fuer die App.
export type Notifier = {
    send(text: string): Promise<void>;
};
