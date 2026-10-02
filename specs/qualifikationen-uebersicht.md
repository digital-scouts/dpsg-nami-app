# Qualifikationen-Übersicht: Anforderungen

Stand: 2026-10-02, in Planung. Diese Spec beschreibt die Erweiterung der Seite „Qualifikationen“ (Einstellungen, Schnellzugriff) von einer reinen EFZ-Liste zu einer konfigurierbaren Übersicht über alle Qualifikationsarten. Die visuellen Entwürfe entstehen in Feedback-Runden unter `design/qualifikationen/`.

## Ausgangslage

- `lib/presentation/screens/settings_qualifikationen_page.dart` zeigt nur das EFZ. Gezeigt wird jede Person mit einer heute aktiven Rolle, die keine reine Mitgliedsrolle ist (`IstFuehrungszeugnispflichtigUseCase`).
- Die Daten kommen offline aus dem Arbeitskontext (`efzEinsichtnahmen`, `efzStand`).
- Seit den Mitgliedsdetails (`specs/mitgliedsdetails-redesign.md`) liegen auch alle Hitobito-Qualifikationen offline im Arbeitskontext (`qualifikationen`, `qualifikationenStand`). Die Übersicht nutzt sie noch nicht.
- `alleQualifikationsarten` enthält nur `efzQualifikationsart` (`lib/domain/qualifikation/qualifikationsart.dart`).

## Vorbild

Campflow zeigt je Qualifikation eine Karte mit:
- Name,
- Symbol,
- „erfüllt / benötigt“ (etwa „11 / 12“),
- Regelmäßigkeit („Alle 5 Jahre“),
- Zahl der Fälligen („1 überfällig“, „1 demnächst fällig“),
- einem Statusbalken in Grün, Orange und Rot.

Ein Zahnrad öffnet die Einstellungen der Qualifikation, ein „+“ fügt eine weitere hinzu. Personenkreise stellt Campflow aus Rollen, Alter und Labels zusammen.

## Festgelegte Anforderungen

**Übersicht**
- Je angezeigter Qualifikation eine Karte nach dem Vorbild.
- Ein Tipp auf die Karte zeigt die Personen des Personenkreises mit ihrem Status. Ein Tipp auf eine Person öffnet die Mitgliedsdetails.

**Angezeigte Qualifikationen**
- Vorgabe: EFZ, Präventionsschulung und Erste Hilfe.
- Vorgaben lassen sich entfernen und ändern, weitere Arten lassen sich hinzufügen.
- Juleica wird nicht eigens behandelt, sie erscheint wie jede andere Art, sobald Hitobito sie liefert.

**Personenkreis je Qualifikation**
- Er wird aus Rollen gebildet:
  - Rollenart (Leitung, Amt, Mitglied),
  - Stufe,
  - konkreter Rollentyp (etwa Vorstand oder Kurat),
  - Alter von/bis.
- Labels sind nicht vorgesehen, weil die JSON:API keine Tags an Personen liefert. Sie kommen nach, sobald das möglich ist.
- Die Regeln gelten app-weit. Sie verweisen deshalb auf Rollentypen, nicht auf Gruppen-IDs eines Layers.

**Gültigkeit**
- Sie kommt aus Hitobito: `validity` der Art, `finish_at` der Qualifikation.
- Nur beim EFZ stellt man sie selbst ein, Vorgabe 5 Jahre (`efzQualifikationsart.gueltigkeitsjahre`).

**Erinnerungen auf der Quali-Seite**
- Je Qualifikation einstellbar: frei wählbare Tage vorher oder keine Erinnerung.
- Umfang „alle im Personenkreis“ oder „nur meine“.
- Kanal: lokale Push-Benachrichtigung auf diesem Gerät.

**Eigene Qualifikationen, für alle Nutzer**
- In den Benachrichtigungs-Einstellungen: Schalter an/aus, Mehrfachauswahl der Arten, Tage frei wählbar.
- Zusätzlich eine In-App-Meldung im Meldungs-Hub (`NotificationsHub.buildInternal`).

**Premium**
- Die Quali-Seite ist Kandidat für das Supporter-Paket (`SupportAccess`).
- Die Mitgliedsdetails mit dem Qualifikationen-Tab und die Erinnerungen an eigene Qualifikationen bleiben frei.

**Speicherung**
- Alle Einstellungen gelten pro App, nicht pro Arbeitskontext (SharedPreferences).
- Sie überstehen den Logout und werden erst beim vollständigen Zurücksetzen gelöscht.

**Katalog**
- Zur Auswahl stehen die Arten, die im aktuellen Arbeitskontext vorkommen.
- Einstellungen zu einmal gesehenen Arten bleiben erhalten, auch wenn die Art im aktuellen Kontext fehlt.

## Datenquellen

| Daten | Quelle | Hinweis |
|---|---|---|
| Qualifikationen | `GET /api/qualifications?include=qualification_kind` | `person_id`, `qualification_kind_id`, `start_at`, `finish_at`, `qualified_at`, `origin` |
| Qualifikationsart | nur als Include | `label`, `description`, `validity`, `reactivateable`, `required_training_days` |
| EFZ | `GET /api/efz_einsichtnahmen` | eigene DPSG-Ressource, keine Qualifikationsart |
| Rollen, Alter | Arbeitskontext | `Mitglied.roles`, `Mitglied.geburtsdatum` |
| Eigene Person | `AuthProfile.namiId` | gleich `Mitglied.personId` |

Befunde zur API:
- **Kein globaler Endpoint:** Hitobito hat kein `GET /api/qualification_kinds`. `QualificationKindResource` ist laut Quelltext „only included via qualifications“, die Webliste ist nur für Admins.
- **Kursarten:** `GET /api/event_kinds` verweist nicht auf Qualifikationsarten.
- **DPSG-Wagon:** bringt keine Qualifikationsarten als Seeds mit. Die Arten pflegen Admins auf der Instanz, die IDs sind instanzspezifisch.
- **Folge:** Sichtbar sind nur Arten, die mindestens eine Person im geladenen Arbeitskontext besitzt.
- **Stand im Code:** `validity` wird bereits angefragt, aber noch nicht geparst. Gespeichert wird bisher nur die `art_id`.

## Edge Cases

- **Gespeicherte Art fehlt im Kontext:** Die Einstellungen bleiben erhalten. Die Karte zeigt „0 / n“, alle im Personenkreis fehlen. Die Art lässt sich ausblenden.
- **Keine EFZ-Berechtigung:** Die EFZ-Karte zeigt „keine Berechtigung“ statt Zahlen. Die anderen Karten bleiben nutzbar.
- **Mehrere Personenkreise:** Eine Person kann in mehreren Kreisen liegen. Sie zählt je Qualifikation einmal.
- **Mehrere Qualifikationen derselben Art:** Es zählt die mit dem spätesten `finish_at`. Ohne Ablauf geht vor einem Ablaufdatum.
- **Abgelaufen, aber reaktivierbar:** Das zählt als überfällig, mit dem Hinweis „reaktivierbar“.
- **Ohne Ablauf (`validity` leer):** Das zählt als gültig. Die Karte zeigt „ohne Ablauf“ statt „Alle n Jahre“.
- **Unbekanntes Geburtsdatum:** Altersregeln treffen nicht. Die Person fällt aus Kreisen mit Altersgrenze heraus und erscheint als Hinweis in der Vorschau.
- **Gleiche Art in zwei Instanzen:** Die Zuordnung der Vorgaben läuft über den Namen. Nach dem ersten Treffer gilt die Art-ID.
- **Viele Abläufe:** iOS erlaubt höchstens 64 geplante Mitteilungen. Fremde Abläufe werden pro Tag gebündelt, die Anzahl ist begrenzt.
- **Logout:** Geplante Mitteilungen mit Namen werden gelöscht. Die Einstellungen bleiben.
- **Lange nicht geöffnet:** Erinnerungen beruhen auf dem letzten Sync, eine Hintergrundaktualisierung gibt es nicht.
- **Demo-Modus:** Synthetische Arten mit festen IDs. Die Einstellungen liegen nur im Speicher und gehen beim Neustart verloren.
