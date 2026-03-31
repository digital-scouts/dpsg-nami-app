# GitHub-Issue-Backlog zur Einführung des Hitobito-Arbeitskontexts

## Zweck

Dieses Dokument übersetzt das Arbeitskontext-Konzept in kleine, kopierfertige Tickets für GitHub-Issues. Es trennt bewusst zwischen MVP-Starttickets und späteren Folge- oder Klärungstickets, damit offene, aber notwendige Themen nicht verloren gehen.

## Fachliche Leitplanken

- Arbeitskontext bleibt immer genau ein Layer.
- Rechte verkleinern nur den sichtbaren Bestand innerhalb des Layers.
- Technisch sichtbare Layer sind nicht automatisch relevante App-Layer.
- Relevante Layer werden aus eigenen Rollen und arbeitskontextrelevanten Lese- oder Schreibrechten abgeleitet.
- `contact_data` und ähnliche Zusatzrechte erzeugen keinen eigenen Arbeitskontext.
- Die App arbeitet im MVP mit dem aus Hitobito lesbar zurückgelieferten Bestand und führt kein eigenes Rechte-Modell ein.
- Personen werden Gruppen über Rollen zugeordnet.
- Leere Gruppen ohne Personen werden in der Leseansicht nicht angezeigt.
- Leere Layer bleiben als mögliche Arbeitskontexte zulässig.
- Sonstige Gruppen sind keine vordefinierten Hauptfilter.
- In-App-Stufen werden im MVP global im Code aus genau einer zugeordneten Hitobito-Gruppe hergeleitet.
- Eine Hitobito-Gruppe wird im MVP höchstens genau einer In-App-Stufe zugeordnet.
- Kontextwechsel ist bewusst und wechselt zwischen Layern.
- Offline ist im MVP genau ein Arbeitskontext lokal verfügbar.
- Unterlayer gehören nicht automatisch dazu.
- Suche und Statistik bleiben kontextgebunden.

## MVP-Starttickets

### Ticket 1: Arbeitskontext-Domainmodell und verfügbare Layer definieren

- Titel: Arbeitskontext-Domainmodell und verfügbare Layer definieren
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Das Domainmodell für aktiven Layer und verfügbare Layer ist in `lib/domain/arbeitskontext/arbeitskontext.dart` umgesetzt und durch `test/arbeitskontext_test.dart` fachlich abgesichert.
- Ziel: Ein belastbares Domänenmodell schaffen, das den aktiven Arbeitskontext als genau einen Layer abbildet und die Basis für alle Folgearbeiten bildet.
- Kurzbeschreibung: Es soll ein fachliches Modell für den aktiven Arbeitskontext eingeführt werden. Dieses Modell kapselt den aktiven Layer, die verfügbaren wechselbaren Layer und die Regel, dass Unterlayer nicht automatisch zum Kontext gehören. Rechte verändern dabei nicht den Kontext selbst, sondern nur den lesbaren Bestand innerhalb des Layers.
- Akzeptanzkriterien:
  - Es gibt ein klar benanntes Domänenkonzept für den aktiven Arbeitskontext.
  - Das Modell bildet genau einen aktiven Layer ab.
  - Verfügbare Wechselziele werden als Menge anderer zugänglicher Layer geführt.
  - Unterlayer werden nicht implizit in denselben Arbeitskontext aufgenommen.
  - Die Fachregel "Rechte verkleinern nur die sichtbare Teilmenge innerhalb des Layers" ist im Modell oder in zugehörigen Regeln dokumentiert.
- Abhängigkeiten: Keine.
- Nicht Teil dieses Tickets: UI für Kontextwechsel, Offline-Persistenz, konkrete Listen- oder Suchdarstellung.

### Ticket 2: Startkontext aus `primary_group` und relevanten Layern ableiten

- Titel: Startkontext aus `primary_group` und relevanten Layern ableiten
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Abstrakter Input und Startkontext-Resolver sind in `lib/domain/arbeitskontext/startkontext_input.dart` und `lib/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart` umgesetzt und durch `test/bestimme_startkontext_usecase_test.dart` abgesichert. Die produktive Verdrahtung auf fachlich relevante Layer aus Rollen und Rechten ist in `lib/presentation/model/arbeitskontext_model.dart` umgesetzt.
- Ziel: Beim App-Start zuverlässig einen initialen Arbeitskontext bestimmen, ohne zusätzliche Nutzereingaben zu verlangen.
- Kurzbeschreibung: Der initiale Arbeitskontext soll aus `primary_group` beziehungsweise dem daraus ableitbaren Primary Layer bestimmt werden, sofern dieser zu den relevanten Layern der Person gehört. Falls das nicht belastbar möglich ist, soll ein stabil sortierter Fallback auf einen anderen relevanten Layer greifen. Die Entscheidung muss deterministisch und für spätere Debugging-Fälle nachvollziehbar sein.
- Akzeptanzkriterien:
  - Wenn `primary_group` eindeutig auf einen Layer verweist oder zu einem Layer auflösbar ist, wird dieser Layer als Startkontext genutzt, sofern er für die App relevant ist.
  - Wenn `primary_group` nicht brauchbar ist, wird ein definierter Fallback aus der Liste relevanter Layer verwendet.
  - Der Fallback ist stabil sortiert und liefert bei gleichem Datenstand denselben Startkontext.
  - Das Verhalten ist für typische und fehlerhafte Fälle testbar beschrieben.
- Abhängigkeiten: Ticket 1.
- Nicht Teil dieses Tickets: Persistenz des zuletzt genutzten Kontexts, Kontextwechsel-UI.

### Ticket 2a: Relevante Layer aus Rollen und Berechtigungen ableiten

- Titel: Relevante Layer aus Rollen und Berechtigungen ableiten
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Die Ableitung relevanter Layer ist mit `lib/domain/arbeitskontext/relevante_layer_input.dart` und `lib/domain/arbeitskontext/usecases/bestimme_relevante_layer_usecase.dart` umgesetzt. `lib/presentation/model/arbeitskontext_model.dart` nutzt diese Ableitung produktiv für Startkontext und Kontextwechsel, `lib/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart` führt keine technisch sichtbaren Layer mehr wieder ein, und `test/bestimme_relevante_layer_usecase_test.dart` sowie `test/arbeitskontext_model_test.dart` sichern das Verhalten ab.
- Ziel: Die App soll nur solche Layer als Arbeitskontexte anbieten, die sich fachlich aus den eigenen Rollen des Nutzers ableiten lassen.
- Kurzbeschreibung: Vor Startkontext und Kontextwechsel muss die App zwischen technisch sichtbaren Layern und fachlich relevanten Layern unterscheiden. Relevante Layer werden aus eigenen Rollen und arbeitskontextrelevanten Lese- oder Schreibrechten abgeleitet. Zusatzrechte wie `contact_data` dürfen die angebotene Layerliste nicht erweitern.
- Akzeptanzkriterien:
  - `layer_read` und `layer_full` machen genau den zugehörigen Layer relevant.
  - `layer_and_below_read` und `layer_and_below_full` machen den zugehörigen Layer und die darunterliegenden Layer relevant.
  - `group_read`, `group_and_below_read` und `group_and_below_full` machen den zugehörigen Layer relevant, ohne automatisch weitere Layer zu öffnen.
  - `contact_data`, Finanz- und Antragsrechte erweitern die angebotene Layerliste nicht.
  - Leere Layer bleiben als relevante Arbeitskontexte zulässig.
  - Ohne arbeitskontextrelevantes Layer- oder Gruppen-Lese- beziehungsweise Schreibrecht entsteht ein expliziter Nicht-Unterstuetzt-Zustand.
- Abhängigkeiten: Ticket 1.
- Nicht Teil dieses Tickets: UI für Kontextwechsel, Detailmodellierung von Admin- oder Impersonation-Fällen.

### Ticket 3: Lesbaren Layer-Bestand aus Hitobito in einen Kontext-Read-Model laden

- Titel: Lesbaren Layer-Bestand aus Hitobito in einen Kontext-Read-Model laden
- Typ: Feature
- Priorität: P0
- Status: in Arbeit
- Umsetzungsstand: Das Ziel-Read-Model und der Domain-Vertrag sind in `lib/domain/arbeitskontext/arbeitskontext_read_model.dart` und `lib/domain/arbeitskontext/arbeitskontext_read_model_repository.dart` angelegt und durch `test/arbeitskontext_read_model_test.dart` abgesichert. Mit `lib/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart` werden erreichbare Layer und lesbare Nicht-Layer-Gruppen bereits produktiv aus Hitobito in das Read-Model ueberfuehrt und lokal gespeichert. Noch offen sind der produktive Personenbestand des aktiven Layers, Pagination fuer Groups und People sowie die Nutzung dieses vollstaendigen Read-Models in der Mitgliederliste.
- Ziel: Den für den aktiven Arbeitskontext lesbaren Personen- und Gruppenbestand konsistent aus Hitobito abrufen und in der App nutzbar machen.
- Kurzbeschreibung: Für den aktiven Layer soll ein Read-Model geladen werden, das nur den aus Hitobito lesbar zurückgelieferten Bestand enthält. Die App führt im MVP kein eigenes Rechte-Modell ein und interpretiert fehlende Lesbarkeit nicht als Fehler im Fachmodell. Welche Layer überhaupt als Arbeitskontexte in Frage kommen, wird dabei bereits vorgelagert über die RelevantLayer-Logik entschieden. Damit wird die Grundlage für Listen, Filter, Suche und Statistik geschaffen.
- Akzeptanzkriterien:
  - Für den aktiven Layer werden Personen und relevante Nicht-Layer-Gruppen aus den lesbaren Hitobito-Daten aufgebaut.
  - Nicht lesbare Personen oder Gruppen erscheinen nicht im Read-Model.
  - Die App leitet aus unvollständiger Lesbarkeit keine zusätzlichen lokalen Rechte oder Verbote ab.
  - Das Read-Model ist als Quelle für Listen, Suche, Filter und Statistik verwendbar.
- Abhängigkeiten: Ticket 1, Ticket 2.
- Nicht Teil dieses Tickets: Darstellung in konkreten Screens, Offline-Speicherung.

### Ticket 3a: Personenbestand des aktiven Arbeitskontexts produktiv laden und an die Mitgliederliste anbinden

- Titel: Personenbestand des aktiven Arbeitskontexts produktiv laden und an die Mitgliederliste anbinden
- Typ: Feature
- Priorität: P0
- Status: offen
- Ziel: Den aktiven Arbeitskontext von einem reinen Layer-und-Gruppen-Modell zu einem voll nutzbaren Read-Model mit Personenbestand ausbauen und die Mitgliederliste auf diese Quelle umstellen.
- Kurzbeschreibung: Der Arbeitskontext soll fuer den aktiven Layer nicht nur erreichbare Layer und lesbare Nicht-Layer-Gruppen, sondern auch den lesbaren Personenbestand produktiv aus Hitobito laden. Dabei muessen die paginierten Responses von `GET /api/groups` und `GET /api/people` vollstaendig verarbeitet werden. Anschliessend soll die Mitgliederliste ihren Datenbestand aus dem aktiven Arbeitskontext statt aus dem bisherigen globalen Flat-People-Pfad beziehen.
- Akzeptanzkriterien:
  - Die paginierten Responses von `GET /api/groups` werden vollstaendig geladen.
  - Die paginierten Responses von `GET /api/people` werden vollstaendig geladen.
  - Das `ArbeitskontextReadModel` enthaelt fuer den aktiven Layer sowohl lesbare Personen als auch lesbare Nicht-Layer-Gruppen.
  - Der vollstaendige Arbeitskontext wird nach erfolgreichem Laden lokal gespeichert.
  - Die Mitgliederliste liest ihren Bestand aus dem aktiven Arbeitskontext und nicht mehr aus einem separaten globalen Flat-People-Repository.
- Abhängigkeiten: Ticket 3, Ticket 4b.
- Nicht Teil dieses Tickets: Gruppenfilter auf Rollenbasis, Kontextwechsel-UI, Stufenzuordnung.

### Ticket 4: Offline genau einen Arbeitskontext speichern und beim Wechsel ersetzen

- Titel: Offline genau einen Arbeitskontext speichern und beim Wechsel ersetzen
- Typ: Feature
- Priorität: P0
- Status: in Arbeit
- Umsetzungsstand: Die lokale Persistenz für genau einen Arbeitskontext ist über `lib/domain/arbeitskontext/arbeitskontext_local_repository.dart`, `lib/data/arbeitskontext/secure_arbeitskontext_local_repository.dart` und die Registrierung in `lib/services/sensitive_storage_service.dart` angelegt und durch `test/secure_arbeitskontext_local_repository_test.dart` abgesichert. Offen sind noch die produktive Nutzung beim App-Start, das Speichern nach erfolgreichem Laden oder Wechsel sowie der eigentliche Kontextwechsel-Flow.
- Ziel: Die MVP-Offlinestrategie technisch sauber verankern, damit lokal immer genau ein Arbeitskontext verfügbar ist.
- Kurzbeschreibung: Lokal wird im MVP genau ein Arbeitskontext mit seinem lesbaren Bestand vorgehalten. Beim bewussten Wechsel in einen anderen Layer wird der bisherige lokale Kontext ersetzt. Das Verhalten muss konsistent für Neustart, erneutes Laden und Kontextwechsel sein.
- Akzeptanzkriterien:
  - Lokal ist nie mehr als ein Arbeitskontext gleichzeitig gespeichert.
  - Ein Kontextwechsel ersetzt den bislang gespeicherten Arbeitskontext vollständig durch den neu geladenen Kontext.
  - Nach App-Neustart steht der zuletzt lokal gespeicherte Arbeitskontext wieder zur Verfügung.
  - Das System verhält sich deterministisch, wenn ein Wechsel abgebrochen wird oder das Laden fehlschlägt.
- Abhängigkeiten: Ticket 3.
- Nicht Teil dieses Tickets: Mehrere Offline-Kontexte, Hintergrund-Synchronisation mehrerer Layer.

### Ticket 4a: Arbeitskontext-App-State und Startinitialisierung produktiv verdrahten

- Titel: Arbeitskontext-App-State und Startinitialisierung produktiv verdrahten
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Der produktive Arbeitskontext-App-State ist in `lib/presentation/model/arbeitskontext_model.dart` umgesetzt und in `lib/main.dart` an den Auth-Lebenszyklus verdrahtet. `lib/presentation/screens/auth_gate_screen.dart` stellt explizite Lade- und Fehlerzustände dar, und `test/arbeitskontext_model_test.dart` sowie `test/auth_gate_screen_test.dart` sichern Initialisierung, Restore-Pfad und Fehlerfall ab.
- Ziel: Den Arbeitskontext im laufenden App-Betrieb zentral führen und beim Start belastbar initialisieren, damit Folgefunktionen auf einen konsistenten aktiven Kontext aufbauen.
- Kurzbeschreibung: Der aktive Arbeitskontext soll produktiv im App-State gehalten und beim Start aus dem zuletzt lokal gespeicherten Kontext oder über den vorhandenen Startkontext-Resolver initialisiert werden. Dazu gehören klare Lade- und Fehlerzustände für die Arbeitskontext-Initialisierung, damit der weitere App-Flow nicht auf impliziten Annahmen basiert. Die bestehende Offline-Persistenz und die fachliche Startlogik sollen dafür in den realen Startpfad der App verdrahtet werden.
- Akzeptanzkriterien:
  - Der aktive Arbeitskontext wird in einem produktiv genutzten App-State gehalten.
  - Beim App-Start wird der zuletzt lokal gespeicherte Arbeitskontext wiederhergestellt, sofern ein gültiger lokaler Kontext vorhanden ist.
  - Wenn kein lokaler Kontext wiederhergestellt werden kann, wird der vorhandene Startkontext-Resolver produktiv zur Initialisierung verwendet.
  - Für die Initialisierung des Arbeitskontexts gibt es explizite Lade- und Fehlerzustände.
  - Nach erfolgreicher Initialisierung steht der aktive Arbeitskontext zentral für weitere Features zur Verfügung.
- Abhängigkeiten: Ticket 2, Ticket 4.
- Nicht Teil dieses Tickets: Kontextwechsel-UI, Statistik, Mitgliederlisten-Filterdetails.

### Ticket 4b: Hitobito-Layer- und Gruppenquelle für den Arbeitskontext aufbauen

- Titel: Hitobito-Layer- und Gruppenquelle für den Arbeitskontext aufbauen
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Die produktive Hitobito-Gruppenquelle ist über `lib/services/hitobito_groups_service.dart` und `GET /api/groups` angebunden. `lib/domain/auth/auth_profile.dart` und `lib/services/hitobito_oauth_service.dart` führen `primary_group_id`, `lib/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart` mappt erreichbare Layer und lesbare Nicht-Layer-Gruppen in das Arbeitskontext-Read-Model, und `lib/presentation/model/arbeitskontext_model.dart` nutzt die Groups-Quelle produktiv für Startkontext und Refresh. Abgesichert ist das durch `test/hitobito_groups_service_test.dart`, `test/hitobito_arbeitskontext_read_model_repository_test.dart`, `test/hitobito_oauth_service_test.dart` sowie die angepassten Arbeitskontext-Model-Tests.
- Ziel: Die produktive Datengrundlage schaffen, um Layer und lesbare Gruppen für den Arbeitskontext konsistent aus Hitobito zu laden und in das Read-Model zu überführen.
- Kurzbeschreibung: Es soll eine Rohdatenquelle entstehen, die `primary_group` beziehungsweise den Primary Layer sowie weitere erreichbare Layer aus Hitobito ableitbar macht. Zusätzlich sollen die lesbaren Nicht-Layer-Gruppen des aktiven Layers geladen und in das bestehende Arbeitskontext-Read-Model gemappt werden. Damit werden die Integrationslücken zwischen fachlichem Modell und realer Hitobito-Anbindung vor dem eigentlichen Kontextwechsel geschlossen.
- Kurzbeschreibung: Es soll eine Rohdatenquelle entstehen, die `primary_group` beziehungsweise den Primary Layer sowie weitere technisch sichtbare Layer aus Hitobito ableitbar macht. Zusätzlich sollen die lesbaren Nicht-Layer-Gruppen des aktiven Layers geladen und in das bestehende Arbeitskontext-Read-Model gemappt werden. Damit werden die Integrationslücken zwischen fachlichem Modell und realer Hitobito-Anbindung vor der Ableitung relevanter Layer und dem eigentlichen Kontextwechsel geschlossen.
- Akzeptanzkriterien:
  - Es gibt eine produktiv nutzbare Rohdatenquelle für `primary_group` beziehungsweise den Primary Layer.
  - Technisch sichtbare Layer werden aus Hitobito-Daten belastbar abgeleitet.
  - Für den aktiven Layer werden lesbare Nicht-Layer-Gruppen aus Hitobito geladen.
  - Die geladenen Layer- und Gruppendaten werden in das ArbeitskontextReadModel gemappt.
  - Die Datenbasis ist so aufbereitet, dass der Startkontext und spätere Kontextwechsel darauf aufbauen können.
- Abhängigkeiten: Ticket 2, Ticket 3.
- Nicht Teil dieses Tickets: Kontextwechsel-UI, globale Suche, Rekursion über Unterlayer.

### Ticket 5: Bewussten Kontextwechsel zwischen relevanten Layern umsetzen

- Titel: Bewussten Kontextwechsel zwischen relevanten Layern umsetzen
- Typ: Feature
- Priorität: P0
- Status: offen
- Ziel: Nutzerinnen und Nutzer sollen gezielt zwischen erreichbaren Layern wechseln können, ohne den Arbeitskontext versehentlich zu verändern.
- Kurzbeschreibung: Die App benötigt einen klaren Flow, um den aktiven Arbeitskontext bewusst zu wechseln. Zur Auswahl stehen nur relevante Layer, nicht beliebige Gruppen und nicht bloß technisch sichtbare Layer. Der Wechsel aktualisiert den aktiven Kontext, stößt das Laden des neuen Bestands an und respektiert die Regel, dass Unterlayer nicht automatisch dazugehören.
- Akzeptanzkriterien:
  - Die Auswahl zeigt nur relevante Layer als Wechselziele.
  - Normale Gruppen werden dort nicht als gleichrangige Hauptkontexte angeboten.
  - Ein bestätigter Wechsel setzt den neuen Layer als aktiven Arbeitskontext.
  - Nach dem Wechsel basieren Listen, Suche, Statistik und Filter ausschließlich auf dem neuen Kontext.
  - Die Nutzerführung macht deutlich, dass ein Kontextwechsel ein Layer-Wechsel ist.
- Abhängigkeiten: Ticket 1, Ticket 2a, Ticket 3, Ticket 4.
- Nicht Teil dieses Tickets: Komfortfunktionen wie zuletzt genutzte Kontexte, Favoriten oder Mehrfachauswahl.

### Ticket 6: Mitgliederliste für den aktiven Arbeitskontext mit Gruppenfiltern umsetzen

- Titel: Mitgliederliste für den aktiven Arbeitskontext mit Gruppenfiltern umsetzen
- Typ: Feature
- Priorität: P0
- Status: offen
- Ziel: Die Mitgliederliste soll den gesamten lesbaren Bestand des aktiven Arbeitskontexts zeigen und über Gruppen sinnvoll einschränkbar sein.
- Kurzbeschreibung: Standardmäßig zeigt die Mitgliederliste alle Personen des aktiven Arbeitskontexts. Gruppen dienen nur als Filter innerhalb dieses Kontexts. Die Zuordnung von Personen zu Gruppen erfolgt über Rollen. Leere Gruppen ohne Personen werden in der Leseansicht nicht angezeigt, und sonstige Gruppen sind im MVP keine vordefinierten Hauptfilter.
- Akzeptanzkriterien:
  - Ohne aktiven Filter zeigt die Liste alle lesbaren Personen des aktiven Arbeitskontexts.
  - Gruppenfilter schränken die Liste ein, ohne den aktiven Arbeitskontext zu ändern.
  - Personen erscheinen in Gruppenfiltern auf Basis ihrer Rollen.
  - Personen mit Rollen in mehreren Gruppen können in mehreren Filtern erscheinen.
  - Leere Gruppen ohne Personen werden in der Leseansicht nicht angezeigt.
  - Sonstige Gruppen erscheinen nicht als vordefinierte Hauptfilter des MVP.
- Abhängigkeiten: Ticket 3.
- Nicht Teil dieses Tickets: Benutzerdefinierte Filter, Tags, "Meine Gruppe" als personalisierte Teilmenge.

### Ticket 7: Stufenzuordnung aus Hitobito-Gruppen global im Code ableiten

- Titel: Stufenzuordnung aus Hitobito-Gruppen global im Code ableiten
- Typ: Feature
- Priorität: P1
- Status: offen
- Ziel: Die bestehenden In-App-Stufen im MVP weiterhin nutzbar machen, obwohl Hitobito diese Domäne nicht direkt bereitstellt.
- Kurzbeschreibung: Für das MVP wird global im Code gepflegt, welche Hitobito-Gruppen genau einer In-App-Stufe entsprechen. Eine Hitobito-Gruppe darf dabei höchstens einer In-App-Stufe zugeordnet sein. Die Ableitung soll nachvollziehbar, testbar und später austauschbar bleiben.
- Akzeptanzkriterien:
  - Die Stufenzuordnung ist zentral und global im Code definiert.
  - Eine Hitobito-Gruppe kann im MVP höchstens einer In-App-Stufe zugeordnet werden.
  - Fehlt für eine Gruppe eine Zuordnung, führt das nicht zu einer falschen Stufe.
  - Die Zuordnung kann für Anzeigen und Filter des MVP verwendet werden.
- Abhängigkeiten: Ticket 3, Ticket 6.
- Nicht Teil dieses Tickets: Automatische Heuristiken aus Gruppenattributen, benutzerseitige Konfiguration der Zuordnung.

### Ticket 8: Suche und Statistik strikt an den aktiven Arbeitskontext binden

- Titel: Suche und Statistik strikt an den aktiven Arbeitskontext binden
- Typ: Feature
- Priorität: P1
- Status: offen
- Ziel: Suchen und Kennzahlen sollen fachlich konsistent bleiben und nie unbemerkt mehrere Layer vermischen.
- Kurzbeschreibung: Suche und Statistik arbeiten im MVP ausschließlich auf dem lesbaren Bestand des aktiven Arbeitskontexts. Rekursive Betrachtungen über Unterlayer hinweg sind ausdrücklich nicht Teil des MVP. Ein Kontextwechsel muss beide Bereiche sofort auf den neuen Layer umstellen.
- Akzeptanzkriterien:
  - Suche liefert nur Treffer aus dem aktiven Arbeitskontext.
  - Statistik berechnet Kennzahlen nur auf Basis des aktiven Arbeitskontexts.
  - Unterlayer fließen nicht automatisch in Suchergebnisse oder Kennzahlen ein.
  - Nach einem Kontextwechsel beziehen sich Suche und Statistik ausschließlich auf den neuen Kontext.
- Abhängigkeiten: Ticket 3, Ticket 5.
- Nicht Teil dieses Tickets: Globale Suche über mehrere Layer, rekursive Statistik über Unterlayer.

## Folge- und Klärungstickets

### Ticket 9: Schreib- und Bearbeitungslogik für teilweise sichtbare Layer fachlich klären

- Titel: Schreib- und Bearbeitungslogik für teilweise sichtbare Layer fachlich klären
- Typ: Klärung
- Priorität: P1
- Status: offen
- Ziel: Frühzeitig festlegen, wie spätere Bearbeitungsfunktionen mit teilweise lesbaren oder unsichtbaren Gruppen innerhalb eines Layers umgehen.
- Kurzbeschreibung: Der MVP fokussiert auf den lesbaren Bestand. Für spätere Schreib- oder Anlegeprozesse ist jedoch offen, ob zusätzliche Gruppen auswählbar sein müssen, die im Lesemodus nicht sichtbar sind. Diese fachliche Grenze soll vor Ausbau von Editierfunktionen separat entschieden werden.
- Akzeptanzkriterien:
  - Es gibt eine dokumentierte Entscheidung, ob Schreibkontexte strikt am Lesemodus hängen oder zusätzliche Gruppenquellen brauchen.
  - Risiken für Bearbeiten, Verschieben und Neuanlage von Personen sind beschrieben.
  - Offene API- oder Rechtefragen an Hitobito sind gesammelt.
- Abhängigkeiten: Ticket 3.
- Nicht Teil dieses Tickets: Umsetzung konkreter Bearbeitungs- oder Anlageflows.

### Ticket 10: Mehrere offline verfügbare Arbeitskontexte konzipieren

- Titel: Mehrere offline verfügbare Arbeitskontexte konzipieren
- Typ: Konzept
- Priorität: P2
- Status: offen
- Ziel: Einen späteren Ausbau auf mehrere lokale Kontexte vorbereiten, ohne das MVP unnötig zu verkomplizieren.
- Kurzbeschreibung: Nach dem MVP kann relevant werden, mehrere Layer gleichzeitig offline vorzuhalten. Dafür müssen Speicherstrategie, Synchronisation, Konfliktverhalten und UX für Auswahl und Aktualität sauber beschrieben werden. Das Ticket dient der Vorbereitung und bewussten Abgrenzung zum Ein-Kontext-MVP.
- Akzeptanzkriterien:
  - Es gibt ein Konzept für Datenhaltung, Aktualisierung und Auswahl mehrerer Offline-Kontexte.
  - Auswirkungen auf Speicherbedarf, Ladezeiten und Fehlerfälle sind beschrieben.
  - Es ist klar benannt, welche bestehenden MVP-Annahmen dafür aufgebrochen werden müssten.
- Abhängigkeiten: Ticket 4, Ticket 5.
- Nicht Teil dieses Tickets: Implementierung mehrerer Offline-Kontexte.

### Ticket 11: Rekursive Sichten über Unterlayer als eigener Produktentscheid vorbereiten

- Titel: Rekursive Sichten über Unterlayer als eigener Produktentscheid vorbereiten
- Typ: Klärung
- Priorität: P2
- Status: offen
- Ziel: Spätere Wünsche nach Bezirks- oder Diözesansichten über untergeordnete Layer fachlich sauber behandeln, statt sie implizit in den MVP zu ziehen.
- Kurzbeschreibung: Die aktuelle Regel lautet, dass Unterlayer nicht automatisch zum Arbeitskontext gehören. Falls später rekursive Sichten, Sammelstatistiken oder aggregierte Listen über Unterlayer gewünscht werden, braucht das eine eigene Produktentscheidung mit klarer UX und technischer Abgrenzung.
- Akzeptanzkriterien:
  - Es gibt eine dokumentierte Entscheidungsvorlage für rekursive Listen, Suche und Statistik über Unterlayer.
  - Unterschiede zwischen "aktueller Layer" und "Layer plus Unterlayer" sind fachlich beschrieben.
  - Risiken für Verständlichkeit, Performance und Offline-Verhalten sind benannt.
- Abhängigkeiten: Ticket 8.
- Nicht Teil dieses Tickets: Implementierung rekursiver Ansichten.

### Ticket 12: Persönliche Teilmengen, Tags und "Meine Gruppe" nach dem MVP definieren

- Titel: Persönliche Teilmengen, Tags und "Meine Gruppe" nach dem MVP definieren
- Typ: Konzept
- Priorität: P2
- Status: offen
- Ziel: Erweiterungen innerhalb eines Arbeitskontexts vorbereiten, ohne das grundlegende Kontextmodell zu verwässern.
- Kurzbeschreibung: Nach dem MVP können persönliche Teilmengen wie "Meine Gruppe", Tags oder gespeicherte Filter relevant werden. Diese Funktionen dürfen den Arbeitskontext nicht verändern, sondern nur Teilmengen innerhalb desselben Layers bilden. Das Ticket bündelt die nötige Fachklärung für einen späteren Ausbau.
- Akzeptanzkriterien:
  - Es gibt eine klare Abgrenzung zwischen Arbeitskontext und persönlicher Teilmenge.
  - Mögliche Quellen für persönliche Teilmengen wie Rollen, Gruppen, Tags oder gespeicherte Filter sind beschrieben.
  - Die Beziehung zu bestehenden Gruppenfiltern und Stufenfiltern ist geklärt.
- Abhängigkeiten: Ticket 6, Ticket 7.
- Nicht Teil dieses Tickets: Konkrete Umsetzung von Tags, Dashboards oder personalisierten Filtern.

## Empfohlene Startreihenfolge

1. Ticket 1: Arbeitskontext-Domainmodell und verfügbare Layer definieren
2. Ticket 2a: Relevante Layer aus Rollen und Berechtigungen ableiten
3. Ticket 2: Startkontext aus `primary_group` und relevanten Layern ableiten
4. Ticket 3: Lesbaren Layer-Bestand aus Hitobito in einen Kontext-Read-Model laden
5. Ticket 4: Offline genau einen Arbeitskontext speichern und beim Wechsel ersetzen
6. Ticket 4a: Arbeitskontext-App-State und Startinitialisierung produktiv verdrahten
7. Ticket 4b: Hitobito-Layer- und Gruppenquelle für den Arbeitskontext aufbauen
8. Ticket 3a: Personenbestand des aktiven Arbeitskontexts produktiv laden und an die Mitgliederliste anbinden
9. Ticket 5: Bewussten Kontextwechsel zwischen relevanten Layern umsetzen
10. Ticket 6: Mitgliederliste für den aktiven Arbeitskontext mit Gruppenfiltern umsetzen
11. Ticket 7: Stufenzuordnung aus Hitobito-Gruppen global im Code ableiten
12. Ticket 8: Suche und Statistik strikt an den aktiven Arbeitskontext binden

## Hinweis zur Nutzung in GitHub

Die Ticketabschnitte sind bewusst so formuliert, dass sie direkt als Grundlage für einzelne GitHub-Issues übernommen und bei Bedarf nur noch um technische Umsetzungshinweise, Labels oder Story-Points ergänzt werden können.
