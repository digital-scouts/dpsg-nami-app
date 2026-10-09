# Update-Hinweise und Sicherheitsupdate

Stand: 2026-10-10. Die App liest `docs/version.json` (GitHub Pages, Adresse unverändert) höchstens alle `APP_UPDATE_MIN_FETCH_INTERVAL_HOURS` Stunden. Offline nutzt sie den zuletzt geladenen Stand. Gestaltung: `design/entscheidung/2026-10-09-schreibpfad-sicherheitsupdate.md` (#197).

## Normale Updates

- Unter `latest`: einmal je Start der Hinweis „Update verfügbar“.
- Unter `min_supported`: Hinweis „Update erforderlich“, aber **ohne Sperre**. Notfallkontakte und Daten müssen erreichbar bleiben.

## Sicherheitsupdate

Optionaler Block je Plattform:

```json
"security": {
  "min_version": "1.0.1",
  "betrifft": "Anmeldung bei Hitobito",
  "betrifft_en": "Sign-in to Hitobito",
  "daten_loeschen": false
}
```

Liegt die installierte Version unter `min_version`:

1. Sheet „Sicherheitsupdate erforderlich“ mit „Betrifft“, „Jetzt aktualisieren“ und „In 3 Stunden erinnern“. Es lässt sich nicht wegwischen.
2. „Später“ geht zweimal. Die Nachfrage kommt jeweils nach 3 Stunden wieder (Start, Resume oder Timer).
3. Nach dem zweiten „Später“ steht oben über jeder Seite ein Countdown-Streifen mit Restzeit und „Jetzt aktualisieren“.
4. Läuft der Countdown ab, sperrt sich die App bis zum Update. Die Sperre bleibt offline und über Neustarts bestehen. Der Sync pausiert.
   - `daten_loeschen: false` (Standard): Die Daten bleiben verschlüsselt. „Notfallkontakte“ zeigt eine reine Leseliste mit Namen und Telefonnummern.
   - `daten_loeschen: true` (Datenleck): Beim Sperren meldet die App ab und löscht die Mitgliederdaten. Es gibt keinen Notfallzugang.

„Jetzt aktualisieren“ öffnet den Store und verbraucht keinen Aufschub. Ist danach noch die alte Version installiert, kommt die Nachfrage beim nächsten Resume wieder. Eine zurückgestellte Uhr verlängert keine Wartezeit.

Zustand: `SharedPreferences` unter `app_update_security_state`. Regel: `lib/domain/app_update/sicherheits_update_regel.dart`, Ablauf: `SicherheitsUpdateModel`.

## Auslösen und zurücknehmen

- **Auslösen:** In `docs/version.json` bei der betroffenen Plattform den Block `security` mit der ersten behobenen Version als `min_version` eintragen, erst nachdem diese Version in dem Store verfügbar ist. Bei einem Datenleck `daten_loeschen: true` setzen.
- **Wirkung:** Spätestens nach dem Abrufintervall. „Erneut prüfen“ auf der Sperre lädt das Manifest sofort.
- **Zurücknehmen:** Den Block entfernen. Beim nächsten Abruf verschwinden Nachfrage, Countdown und Sperre; der gespeicherte Stand wird gelöscht. Bereits gelöschte Daten lädt die App nach dem Anmelden neu.
- Ältere App-Versionen kennen den Block nicht und zeigen weiter nur die normalen Hinweise.
