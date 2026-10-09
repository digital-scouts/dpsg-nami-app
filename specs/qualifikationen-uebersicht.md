# Qualifikationen-Übersicht: Anforderungen

Stand: 2026-10-02, umgesetzt. Diese Spec beschreibt die Erweiterung der Seite „Qualifikationen“ (Einstellungen, Schnellzugriff) von einer reinen EFZ-Liste zu einer konfigurierbaren Übersicht über alle Qualifikationsarten. Die Entscheidungen der drei Entwurfsrunden stehen in `design/entscheidung/2026-10-02-qualifikationen-uebersicht.md`.

## Umgesetzter Stand

- **Arten:** Qualifikationen tragen die Gültigkeit ihrer Art (`validity`). Die Arten leitet das Read Model aus den Qualifikationen ab (`HitobitoQualifikationsart`); eine eigene Liste gibt es nicht.
- **Domain** (`lib/domain/qualifikation/`):
  - `Personenkreis` mit Regeln aus Rollenart, Stufe, Rollentyp und Alter; „und“ bindet stärker als „oder“.
  - `QualifikationsEinstellungen` mit Vorgaben aus `QualifikationsVorgaben`.
  - `ErmittleQualifikationsUebersichtUseCase`: Katalog und Zeilen.
  - `PlaneQualifikationsErinnerungenUseCase`: Erinnerungsplan und eigene Abläufe.
- **Speicherung:** in SharedPreferences (`qualifikationsEinstellungenJson`), im Demo-Modus nur im Speicher.
- **Oberfläche:**
  - Übersicht: `settings_qualifikationen_page.dart`.
  - Personenliste, Auswahl und Einstellungen: unter `lib/presentation/screens/qualifikationen/`.
  - „Meine Qualifikationen“ im Abschnitt Benachrichtigungen (`settings_notification_page.dart`).
- **Erinnerungen:** `QualifikationsErinnerungService` plant lokale Mitteilungen um 9 Uhr.
  - Er nutzt die IDs 95000–95099 und räumt beim Abmelden nur diesen Bereich.
  - Gemeldete Abläufe merkt er sich unter `qualifikationsErinnerungenGeplant`.
- **Meldung im Hub:** `qualifikation-laeuft-ab`. Ein Tipp öffnet die eigenen Mitgliedsdetails.
- **Förderer:** Die Übersicht hängt an `SupportAccess.qualifikationenFrei`, also am Förderer-Abo. Bis zur Store-Anbindung simuliert der Testschalter `supporterTestZugang` in Debug & Tools einen Kauf (keiner, ein Design-Paket oder Förderer), standardmäßig keiner. Der Demo-Modus ist freigeschaltet.
- **Offen:**
  - Ein Tipp auf eine Push-Mitteilung öffnet nur die App, Deep-Links fehlen noch.
  - Die Labels für Prävention und Erste Hilfe auf dpsg.puzzle.ch sind noch zu prüfen. Die Muster stehen in `QualifikationsVorgaben`.

## Ausgangslage vor der Umsetzung

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

**Übersicht** (Entwurf U3)
- Je angezeigter Qualifikation eine Zeile in einer gemeinsamen Karte: Symbol, Name, Regelmäßigkeit, „n fehlen · n bald“, Balken, „erfüllt / benötigt“.
- Status:
  - Fehlt und abgelaufen zählen gemeinsam als „fehlt“ und sind im Balken rot.
  - „Demnächst fällig“ ist orange und beginnt beim Erinnerungs-Vorlauf der Qualifikation.
  - „Erfüllt“ zählt gültig und demnächst fällig.
- Ein Tipp auf eine Zeile öffnet die Personenliste mit dem Umschalter „Handlungsbedarf / Alle“ (Entwurf D2).
  - Abgelaufene behalten dort ihr Label „abgelaufen“.
  - Ein Tipp auf eine Person öffnet die Mitgliedsdetails.
- Ein Zahnrad oben rechts und „Qualifikation hinzufügen“ öffnen die Auswahl. Darin schaltet man Arten an und aus, ändert die Reihenfolge per Ziehen und öffnet mit dem Pfeil die Einstellungen einer Art. In der Personenliste führt das Zahnrad direkt zu den Einstellungen der Art.

**Angezeigte Qualifikationen**
- Vorgabe: EFZ, Präventionsschulung und Erste Hilfe.
- Vorgaben lassen sich ausblenden und ändern, weitere Arten lassen sich einblenden.
- Sichtbar sind nur Arten, die im aktuellen Arbeitskontext jemand hat; das EFZ ist immer sichtbar. Arten, die gerade niemand hat, erscheinen auch nicht in der Auswahl. Ihre Einstellungen bleiben gespeichert und gelten wieder, sobald jemand die Qualifikation hat.
- Juleica wird nicht eigens behandelt, sie erscheint wie jede andere Art, sobald Hitobito sie liefert.

**Personenkreis je Qualifikation** (Entwurf P1, Regeln aus Bausteinen)
- Er wird aus Rollen gebildet:
  - Rollenart (Leitung, Amt, Mitglied),
  - Stufe,
  - konkreter Rollentyp (etwa Vorstand oder Kurat),
  - Alter von/bis.
- Labels sind nicht vorgesehen, weil die JSON:API keine Tags an Personen liefert. Sie kommen nach, sobald das möglich ist.
- Die Regeln gelten app-weit. Sie verweisen deshalb auf Rollentypen, nicht auf Gruppen-IDs eines Layers.

**Gültigkeit**
- Sie kommt aus Hitobito: `validity` der Art, `finish_at` der Qualifikation.
- Das EFZ gilt fest 5 Jahre ab dem Ausstellungsdatum der letzten Einsichtnahme (`efzQualifikationsart.gueltigkeitsjahre`), nicht einstellbar und ohne Zusatz. Bei Hitobito-Arten steht „aus Hitobito“.

**Erinnerungen auf der Quali-Seite**
- Je Qualifikation einstellbar: frei wählbare Tage vorher oder keine Erinnerung.
- „Von wem“: von allen im Personenkreis oder nur von mir. Erinnert wird immer der Nutzer selbst. Fremde Abläufe werden pro Tag gebündelt.
- Kanal: lokale Push-Benachrichtigung auf diesem Gerät.

**Eigene Qualifikationen, für alle Nutzer**
- In den Benachrichtigungs-Einstellungen: Schalter an/aus, Mehrfachauswahl der Arten, Tage frei wählbar.
- Zusätzlich eine In-App-Meldung im Meldungs-Hub (`NotificationsHub.buildInternal`).

**Premium**
- Die Quali-Seite gehört zum Förderer-Abo (`SupportAccess.qualifikationenFrei`).
- Die Mitgliedsdetails mit dem Qualifikationen-Tab und die Erinnerungen an eigene Qualifikationen bleiben frei.
- Gesperrt zeigt die Seite nur einen Hinweis (Entwurf L2).
- Übergangsweise simuliert der Testschalter „Simulierter Kauf“ in Debug & Tools den Förderer, bis die Store-Anbindung steht.

**Speicherung**
- Alle Einstellungen gelten pro App, nicht pro Arbeitskontext (SharedPreferences).
- Sie überstehen den Logout und werden erst beim vollständigen Zurücksetzen gelöscht.

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

- **Gespeicherte Art fehlt im Kontext:** Sie erscheint weder in der Übersicht noch in der Auswahl. Die Einstellungen bleiben erhalten und gelten wieder, sobald jemand sie hat.
- **Keine EFZ-Berechtigung:** Die EFZ-Karte zeigt „keine Berechtigung“ statt Zahlen. Die anderen Karten bleiben nutzbar.
- **Mehrere Personenkreise:** Eine Person kann in mehreren Kreisen liegen. Sie zählt je Qualifikation einmal.
- **Mehrere Qualifikationen derselben Art:** Es zählt die mit dem spätesten `finish_at`. Ohne Ablauf geht vor einem Ablaufdatum.
- **Abgelaufen, aber reaktivierbar:** Das zählt als fehlt, mit dem Label „abgelaufen“ und dem Hinweis „reaktivierbar“.
- **Ohne Ablauf (`validity` leer):** Das zählt als gültig. Die Karte zeigt „ohne Ablauf“ statt „Alle n Jahre“.
- **Unbekanntes Geburtsdatum:** Altersregeln treffen nicht. Die Person fällt aus Kreisen mit Altersgrenze heraus und erscheint als Hinweis in der Vorschau.
- **Gleiche Art in zwei Instanzen:** Die Zuordnung der Vorgaben läuft über den Namen. Nach dem ersten Treffer gilt die Art-ID.
- **Viele Abläufe:** iOS erlaubt höchstens 64 geplante Mitteilungen. Fremde Abläufe werden pro Tag gebündelt, die Anzahl ist begrenzt.
- **Logout:** Geplante und bereits angezeigte Mitteilungen mit Namen werden gelöscht. Die Einstellungen bleiben.
- **Planungsfehler:** Schlägt das Planen fehl, bleiben die bisherigen Erinnerungen bestehen. Beim nächsten Anlass (Änderung, Rückkehr in die App) wird erneut geplant.
- **Mitteilungen aus und wieder an:** Beim Ausschalten werden Erinnerungen entfernt. Noch nicht zugestellte gelten nicht als gemeldet und kommen nach dem Einschalten wieder, verpasste spätestens am nächsten Morgen.
- **Zeitzone:** Wechselt die Zeitzone oder die Sommerzeit, plant die App beim nächsten Abgleich neu, damit die Erinnerungen wieder um 9 Uhr Ortszeit kommen.
- **Zustellzeit:** Android stellt ungenau zu (`inexactAllowWhileIdle`), die Uhrzeit kann sich im Ruhezustand verschieben. Exakte Alarme sind bewusst nicht vorgesehen, sie bräuchten eine Berechtigung ohne Nutzen für Tageserinnerungen.
- **Lange nicht geöffnet:** Erinnerungen beruhen auf dem letzten Sync, eine Hintergrundaktualisierung gibt es nicht.
- **Demo-Modus:** Synthetische Arten mit festen IDs. Die Einstellungen liegen nur im Speicher und gehen beim Neustart verloren.
