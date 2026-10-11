# Mobile Daten einschränken

Stand: 2026-10-11. Was der Schalter „Mobile Daten einschränken“ bewirkt (#204). Gestaltung: `design/entscheidung/2026-10-11-mobile-daten.md`.

## Grundregel

Der Schalter hält große und häufige Abrufe zurück, solange kein WLAN besteht. Verbindungen, die weder WLAN noch Mobilfunk sind (etwa nur VPN), gelten als mobile Daten. Entschieden wird zentral in `NetworkAccessPolicy`; `allowMobileDataOverride` gibt einen einzelnen Zugriff frei.

| Art | Verhalten ohne WLAN | Beispiele |
|---|---|---|
| Notwendig | läuft immer | Login, Token erneuern und widerrufen, Meldungen, Versionsprüfung |
| Automatisch | wartet auf WLAN | Hitobito-Sync, Nachsenden der Warteschlange, Stammkarten-Refresh, Kachel-Vorabdownload, Bundesstatistik, Statistik-Standorte, Wiredash-Ereignisse |
| Selbst angestoßen | nach Bestätigung über mobile Daten | Mitgliederliste aktualisieren, Mitglied senden, Veranstaltungen, Karten, Adressvorschau, Adresssuche |
| Ein Knopf für genau einen Download | gilt selbst als Bestätigung | EFZ-Antrag herunterladen |

Eine Bestätigung gilt, bis man die Seite verlässt.

## Notwendige Abrufe

- **Meldungen:** im WLAN höchstens stündlich (`PULL_NOTIFICATIONS_MIN_FETCH_INTERVAL_HOURS`), über Mobilfunk bei aktivem Schalter höchstens alle 6 Stunden (`PullNotificationsRepositoryImpl.minFetchIntervalMobil`).
- **Versionsprüfung:** höchstens alle 12 Stunden (`APP_UPDATE_MIN_FETCH_INTERVAL_HOURS`), unabhängig vom Schalter.

## Selbst angestoßene Abrufe

- **Mitglied speichern:** Dialog „Änderung jetzt senden?“. „Jetzt senden“ sendet mit Freigabe. „Später im WLAN“ merkt die Änderung ohne Sendeversuch vor (`MemberEditModel.vormerkenFuerWlan`), Meldung „Gespeichert. Die Änderung wird im WLAN gesendet.“
- **Veranstaltungen:** Zustand „Nur im WLAN“ mit „Trotzdem laden“ (`VeranstaltungenModel.trotzdemLaden`) und „Abbrechen“. Echtes Offline zeigt weiter „Keine Verbindung“.
- **Karten** (Einstellungen, Statistik, Kartenvorschau): Kacheln nur aus dem Speicher (`KartenKacheln`, `MapTileCacheService.tileProvider(allowNetwork: false)`). Ein Hinweis „Karte nur aus dem Speicher“ mit „Über mobile Daten laden“ liegt auf der Karte, auf kleinen Karten als eine Zeile oben mit „Laden“.
- Bei erlaubtem Netz laden Einstellungs- und Statistik-Karte ihre Kacheln wie bisher direkt; ob sie den Kachel-Cache füllen, klärt #196.
- **Kartenvorschau ohne bekannte Koordinaten:** Hinweis mit „Laden“, danach Geokodierung mit Freigabe.
- **Adresssuche:** Hinweis „Vorschläge im WLAN“ unter dem Feld, „Vorschläge über mobile Daten laden“ gibt die Suche frei und fragt den getippten Text erneut ab.

## Wiredash

- Das SDK sendet jedes Ereignis wenige Sekunden nach `trackEvent` und lässt sich nicht pausieren. Deshalb hält `WiredashEventPuffer` Ereignisse vorher zurück.
- Bei aktivem Schalter ohne WLAN landen Ereignisse in SharedPreferences (`wiredash_event_puffer`), höchstens 200 und höchstens 3 Tage. Ältere fallen weg.
- Sobald WLAN da ist oder der Schalter ausgeht, gehen sie in Reihenfolge an Wiredash. Der echte Zeitpunkt reist als `occurred_at` mit, solange das Ereignis weniger als 10 Parameter hat.
- Ohne Einwilligung in Nutzungsereignisse wird nichts erfasst und nichts vorgemerkt.
- Nicht steuerbar: Der Ping des SDK beim App-Start (höchstens alle 30 Minuten). Feedback und Umfrage sendet der Nutzer selbst ab.
