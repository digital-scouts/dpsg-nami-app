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
- In-App-Stufen werden im MVP global im Code über zentrale Regeln zu Hitobito-Gruppentypen hergeleitet.
- Eine einzelne Hitobito-Gruppe wird darüber im MVP höchstens genau einer In-App-Stufe zugeordnet.
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
- Status: umgesetzt
- Umsetzungsstand: People und Groups werden produktiv für den aktiven Arbeitskontext geladen. Die Pagination der Hitobito-Services wird bereits vollständig über while(nextUri != null) verarbeitet, und das aufgebaute Arbeitskontext-Read-Model wird nach erfolgreichem Refresh lokal gespeichert.
- Ziel: Den für den aktiven Arbeitskontext lesbaren Personen- und Gruppenbestand konsistent aus Hitobito abrufen und in der App nutzbar machen.
- Kurzbeschreibung: Für den aktiven Layer soll ein Read-Model geladen werden, das nur den aus Hitobito lesbar zurückgelieferten Bestand enthält. Die App führt im MVP kein eigenes Rechte-Modell ein und interpretiert fehlende Lesbarkeit nicht als Fehler im Fachmodell. Welche Layer überhaupt als Arbeitskontexte in Frage kommen, wird dabei bereits vorgelagert über die RelevantLayer-Logik entschieden. Damit wird die Grundlage für Listen, Filter, Suche und Statistik geschaffen.
- Akzeptanzkriterien:
  - Für den aktiven Layer werden Personen und relevante Nicht-Layer-Gruppen aus den lesbaren Hitobito-Daten aufgebaut.
  - Nicht lesbare Personen oder Gruppen erscheinen nicht im Read-Model.
  - Die App leitet aus unvollständiger Lesbarkeit keine zusätzlichen lokalen Rechte oder Verbote ab.
  - Das Read-Model ist als Quelle für Listen, Suche, Filter und Statistik verwendbar.
- Abhängigkeiten: Ticket 1, Ticket 2.
- Nicht Teil dieses Tickets: Darstellung in konkreten Screens, fachliche Gruppenfilter auf Basis von Rollen- und Gruppenzuordnungen pro Person.

### Ticket 3a: Personenbestand des aktiven Arbeitskontexts produktiv laden und an die Mitgliederliste anbinden

- Titel: Personenbestand des aktiven Arbeitskontexts produktiv laden und an die Mitgliederliste anbinden
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Der Personenbestand des aktiven Arbeitskontexts wird produktiv geladen, und die Mitgliederliste nutzt bereits readModel.mitglieder als Datenquelle.
- Ziel: Den aktiven Arbeitskontext von einem reinen Layer-und-Gruppen-Modell zu einem voll nutzbaren Read-Model mit Personenbestand ausbauen und die Mitgliederliste auf diese Quelle umstellen.
- Kurzbeschreibung: Der Arbeitskontext soll für den aktiven Layer nicht nur erreichbare Layer und lesbare Nicht-Layer-Gruppen, sondern auch den lesbaren Personenbestand produktiv aus Hitobito laden. Dabei müssen die paginierten Responses von GET /api/groups und GET /api/people vollständig verarbeitet werden. Anschließend soll die Mitgliederliste ihren Datenbestand aus dem aktiven Arbeitskontext statt aus dem bisherigen globalen Flat-People-Pfad beziehen.
- Akzeptanzkriterien:
  - Die paginierten Responses von GET /api/groups werden vollständig geladen.
  - Die paginierten Responses von GET /api/people werden vollständig geladen.
  - Das ArbeitskontextReadModel enthält für den aktiven Layer sowohl lesbare Personen als auch lesbare Nicht-Layer-Gruppen.
  - Der vollständige Arbeitskontext wird nach erfolgreichem Laden lokal gespeichert.
  - Die Mitgliederliste liest ihren Bestand aus dem aktiven Arbeitskontext und nicht mehr aus einem separaten globalen Flat-People-Repository.
- Abhängigkeiten: Ticket 3, Ticket 4b.
- Nicht Teil dieses Tickets: Gruppenfilter auf Rollenbasis, Kontextwechsel-UI, Stufenzuordnung.

### Ticket 3b: Rollen- und Gruppenzuordnungen pro Person in das Arbeitskontext-Read-Model übernehmen

- Titel: Rollen- und Gruppenzuordnungen pro Person in das Arbeitskontext-Read-Model übernehmen
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Rollen- und Gruppenzuordnungen werden bereits aus dem People-Pfad extrahiert, in das Arbeitskontext-Read-Model übernommen, lokal mitgespeichert und produktiv für die Anzeige der primären Gruppen- und Rolleninformation genutzt.
- Ziel: Die fachliche Datengrundlage für gruppenbasierte Filter innerhalb des aktiven Arbeitskontexts schaffen.
- Kurzbeschreibung: Für gruppenbasierte Filter braucht das Arbeitskontext-Read-Model pro Person nicht nur Stammdaten, sondern auch Rollen- und Gruppenzuordnungen. Die People-Ressourcen kennen in den Demoantworten bereits Rollenbeziehungen, das aktuelle Mapping übernimmt diese Beziehungen pro Person jedoch noch nicht in das Read-Model. Dieses Ticket ergänzt die fehlende fachliche Datengrundlage für spätere Gruppenfilter und weitere aus Rollen abgeleitete Sichten.
- Akzeptanzkriterien:
  - Das Arbeitskontext-Read-Model enthält pro Person die für den aktiven Layer relevanten Rollen- und Gruppenzuordnungen.
  - Personen können mehreren Gruppen innerhalb desselben Arbeitskontexts zugeordnet sein.
  - Die übernommenen Zuordnungen basieren ausschließlich auf lesbaren Hitobito-Daten des aktiven Arbeitskontexts.
  - Die Datengrundlage reicht aus, um Gruppenfilter in der Mitgliederliste ohne zusätzliche API-Interpretation in der UI aufzubauen.
- Abhängigkeiten: Ticket 3, Ticket 3a.
- Nicht Teil dieses Tickets: Konkrete UI für Gruppenfilter, Stufenzuordnung, Suche oder Statistik.

### Ticket 3c: Personenmodell auf Hitobito-Kontaktobjekte umstellen und Legacy-Felder abbauen

- Titel: Personenmodell auf Hitobito-Kontaktobjekte umstellen und Legacy-Felder abbauen
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Das Mitgliedsmodell fuehrt strukturierte Sammlungen fuer E-Mails, Telefonnummern und Adressen sowie optionale Personenfelder. Operative Aufrufer wie Kontaktanzeige, Storybook, Suche, Demo-Fabriken und Serialisierung nutzen das neue Zielmodell; Legacy-Felder und Legacy-Kompatibilitaet sind aus dem Domainmodell entfernt.
- Ziel: Das lokale Personenmodell von alten NaMi-2.0-Kontaktslots lösen und an die Hitobito-Struktur angleichen.
- Kurzbeschreibung: Das aktuelle Mitgliedsmodell enthält noch feste Kontaktfelder wie `telefon1`, `telefon2`, `telefon3`, `email1` und `email2`. Für Hitobito soll das Modell stattdessen strukturierte Sammlungen für E-Mails, Telefonnummern und Adressen mit Label und Wert führen. Zusätzlich sollen die für den DPSG-Endpunkt relevanten optionalen Personenfelder wie `pronoun`, `entry_date`, `exit_date` und Bankdaten berücksichtigt werden. `country` bleibt Adressbestandteil und wird nicht als Nationalität interpretiert.
- Akzeptanzkriterien:
  - Das Personenmodell führt strukturierte Sammlungen für E-Mails, Telefonnummern und Adressen statt fester Legacy-Felder.
  - Adressen können mindestens `address_care_of`, `street`, `housenumber`, `postbox`, `zip_code`, `town` und `country` abbilden.
  - Optionale Personenfelder `pronoun`, `entry_date`, `exit_date`, `bank_account_owner`, `iban`, `bic`, `bank_name` und `payment_method` sind im Modell vorgesehen.
  - Legacy-Felder wie `telefon1` bis `telefon3` und `email1` bis `email2` werden nicht weiter als Zielmodell fortgeschrieben.
  - Fehlende optionale Felder in Demo- oder Produktantworten bleiben zulässig.
- Abhängigkeiten: Ticket 3a.
- Nicht Teil dieses Tickets: Historischer Rollenverlauf, Tags, Bearbeitungs-UI.

### Ticket 3d: Hitobito-People-Mapping auf erweitertes Personenmodell anheben

- Titel: Hitobito-People-Mapping auf erweitertes Personenmodell anheben
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Der produktive People-Pfad mappt neben Rollen und direkten Basisattributen jetzt auch zusaetzliche E-Mails, Telefonnummern und Zusatzadressen aus included-Beziehungen in das erweiterte Personenmodell. Fehlende optionale Felder und fehlende Kontakt-Includes bleiben tolerant behandelt.
- Ziel: Das produktive Arbeitskontext-Read-Model nicht nur mit Minimalstammdaten, sondern mit dem geplanten erweiterten Personenmodell befüllen.
- Kurzbeschreibung: Der produktive Pfad aus `GET /api/people` in das Arbeitskontext-Read-Model liefert derzeit nur einen reduzierten People-List-Schnitt. Dieses Ticket erweitert den Mapping-Pfad auf primäre und zusätzliche E-Mails, Telefonnummern, strukturierte Adressen sowie optionale Personenfelder wie `pronoun`, `entry_date`, `exit_date` und Bankdaten.
- Akzeptanzkriterien:
  - Das produktive People-Mapping übernimmt primäre und zusätzliche E-Mails in ein gemeinsames Kontaktmodell.
  - Telefonnummern und strukturierte Adressen werden aus Hitobito-Beziehungen beziehungsweise Attributen übernommen.
  - Optionale Felder wie `pronoun`, `entry_date`, `exit_date` und Bankdaten werden übernommen, wenn Hitobito sie liefert.
  - Das Arbeitskontext-Read-Model verwendet danach keinen bloßen Minimal-Schnitt mehr als einziges Produktivmodell.
  - Fehlende optionale Felder führen nicht zu fehlerhaftem Mapping.
- Abhängigkeiten: Ticket 3c.
- Nicht Teil dieses Tickets: Historische Rollen über den Roles-Endpoint, Tags, Schreiboperationen.

### Ticket 4: Offline genau einen Arbeitskontext speichern und beim Wechsel ersetzen

- Titel: Offline genau einen Arbeitskontext speichern und beim Wechsel ersetzen
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Genau ein Arbeitskontext wird lokal über loadLastCached und saveCached wiederhergestellt beziehungsweise ersetzt. Beim fehlgeschlagenen oder abgebrochenen Wechsel bleibt der bisherige aktive Kontext deterministisch erhalten.
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
- Umsetzungsstand: Der produktive Arbeitskontext-App-State ist umgesetzt und an den Auth-Lebenszyklus verdrahtet. Explizite Lade- und Fehlerzustände sind vorhanden, und der Startpfad ist zusätzlich gegen übernommene Sessions ohne restorable Profildaten gehärtet.
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
- Umsetzungsstand: Die produktive Hitobito-Gruppenquelle ist angebunden, primary_group_id wird geführt, erreichbare Layer und lesbare Nicht-Layer-Gruppen werden in das Arbeitskontext-Read-Model gemappt, und die Groups-Quelle wird produktiv für Startkontext und Refresh genutzt.
- Ziel: Die produktive Datengrundlage schaffen, um Layer und lesbare Gruppen für den Arbeitskontext konsistent aus Hitobito zu laden und in das Read-Model zu überführen.
- Kurzbeschreibung: Es soll eine Rohdatenquelle entstehen, die primary_group beziehungsweise den Primary Layer sowie weitere technisch sichtbare Layer aus Hitobito ableitbar macht. Zusätzlich sollen die lesbaren Nicht-Layer-Gruppen des aktiven Layers geladen und in das bestehende Arbeitskontext-Read-Model gemappt werden. Damit werden die Integrationslücken zwischen fachlichem Modell und realer Hitobito-Anbindung vor der Ableitung relevanter Layer und dem eigentlichen Kontextwechsel geschlossen.
- Akzeptanzkriterien:
  - Es gibt eine produktiv nutzbare Rohdatenquelle für primary_group beziehungsweise den Primary Layer.
  - Technisch sichtbare Layer werden aus Hitobito-Daten belastbar abgeleitet.
  - Für den aktiven Layer werden lesbare Nicht-Layer-Gruppen aus Hitobito geladen.
  - Die geladenen Layer- und Gruppendaten werden in das ArbeitskontextReadModel gemappt.
  - Die Datenbasis ist so aufbereitet, dass der Startkontext und spätere Kontextwechsel darauf aufbauen können.
- Abhängigkeiten: Ticket 2, Ticket 3.
- Nicht Teil dieses Tickets: Kontextwechsel-UI, globale Suche, Rekursion über Unterlayer.

### Ticket 4c: Cache und Kontextwechsel auf erweitertes Personenmodell anheben

- Titel: Cache und Kontextwechsel auf erweitertes Personenmodell anheben
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Der lokale Arbeitskontext-Cache persistiert das erweiterte Personenmodell bereits verlustfrei ueber lib/data/arbeitskontext/secure_arbeitskontext_local_repository.dart und den produktiven Refresh-Pfad in lib/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart. Gezielte Tests in test/secure_arbeitskontext_local_repository_test.dart, test/hitobito_arbeitskontext_read_model_repository_test.dart und test/arbeitskontext_model_test.dart sichern den Roundtrip fuer strukturierte Kontakte sowie Rollen- und Gruppenzuordnungen auch ueber den Kontextwechsel ab.
- Ziel: Den erweiterten Personenstand bei Offline-Nutzung und bewusstem Kontextwechsel verlustfrei erhalten.
- Kurzbeschreibung: Sobald das Personenmodell über die bisherige Minimalform hinausgeht, müssen lokaler Cache und Kontextwechsel dieselbe Struktur mittragen. Dieses Ticket hebt Persistenz und Wiederherstellung des Arbeitskontexts auf das neue Personenmodell an, damit E-Mails, Telefonnummern, Adressen und optionale Personenfelder nicht beim Speichern verloren gehen.
- Akzeptanzkriterien:
  - Der lokale Arbeitskontext-Cache speichert und lädt das erweiterte Personenmodell vollständig.
  - Ein Kontextwechsel ersetzt weiterhin genau einen lokalen Arbeitskontext, ohne neue Personenfelder zu verlieren.
  - Fehlende optionale Felder bleiben beim Speichern und Laden sauber optional.
  - Die Persistenz bleibt kompatibel mit dem Grundsatz, dass im MVP genau ein Arbeitskontext lokal verfügbar ist.
- Abhängigkeiten: Ticket 3c, Ticket 3d, Ticket 4.
- Nicht Teil dieses Tickets: Mehrere Offline-Kontexte, historische Rollenverläufe.

### Ticket 5: Bewussten Kontextwechsel zwischen relevanten Layern umsetzen

- Titel: Bewussten Kontextwechsel zwischen relevanten Layern umsetzen
- Typ: Feature
- Priorität: P0
- Status: umgesetzt
- Umsetzungsstand: Der bewusste Layerwechsel ist über ein Bottom Sheet auf der ProfilePage umgesetzt und delegiert den produktiven Wechsel an switchToLayer.
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
- Status: umgesetzt
- Umsetzungsstand: Die Mitgliederliste zeigt produktiv alle Mitglieder des aktiven Arbeitskontexts. Vordefinierte Stufenfilter sowie persistierte benutzerdefinierte Filtergruppen sind angebunden; die Auswertung basiert auf Rollen- und Gruppenzuordnungen aus Ticket 3b und ist unter anderem durch `test/ermittle_member_filter_treffer_usecase_test.dart` sowie `test/shared_prefs_member_filter_repository_test.dart` abgesichert.
- Ziel: Die Mitgliederliste soll den gesamten lesbaren Bestand des aktiven Arbeitskontexts zeigen und über Gruppen sinnvoll einschränkbar sein.
- Kurzbeschreibung: Die Mitgliederliste zeigt alle Personen des aktiven Arbeitskontexts. Gruppen- und Stufenfilter schränken diese Menge innerhalb desselben Kontexts ein. Zusätzlich können benutzerdefinierte Filtergruppen mehrere Regeln über Stufen sowie Gruppen- und Rollenzuordnungen kombinieren. Leere Gruppen ohne Personen werden in der Leseansicht nicht angezeigt, und sonstige Gruppen bleiben keine vordefinierten Hauptfilter.
- Akzeptanzkriterien:
  - Ohne aktiven Filter zeigt die Liste alle lesbaren Personen des aktiven Arbeitskontexts.
  - Gruppenfilter schränken die Liste ein, ohne den aktiven Arbeitskontext zu ändern.
  - Personen erscheinen in Gruppenfiltern auf Basis ihrer Rollen.
  - Personen mit Rollen in mehreren Gruppen können in mehreren Filtern erscheinen.
  - Leere Gruppen ohne Personen werden in der Leseansicht nicht angezeigt.
  - Sonstige Gruppen erscheinen nicht als vordefinierte Hauptfilter des MVP.
- Abhängigkeiten: Ticket 3, Ticket 3b.
- Nicht Teil dieses Tickets: Tags, "Meine Gruppe" als personalisierte Teilmenge.

### Ticket 7: Stufenzuordnung aus Hitobito-Gruppentypen global im Code ableiten

- Titel: Stufenzuordnung aus Hitobito-Gruppentypen global im Code ableiten
- Typ: Feature
- Priorität: P1
- Status: umgesetzt
- Umsetzungsstand: Die zentrale Stufenableitung ist in `lib/domain/stufe/arbeitskontext_stufen_mapping.dart` und `lib/domain/stufe/usecases/ermittle_stufen_im_arbeitskontext_usecase.dart` umgesetzt. `test/ermittle_stufen_im_arbeitskontext_usecase_test.dart` sichert die Ableitung über Gruppentypen, Mehrfachzuordnungen derselben Stufe und fehlende Regeln ab.
- Ziel: Die bestehenden In-App-Stufen im MVP weiterhin nutzbar machen, obwohl Hitobito diese Domäne nicht direkt bereitstellt.
- Kurzbeschreibung: Für das MVP wird global im Code gepflegt, welche Hitobito-Gruppentypen einer In-App-Stufe entsprechen. Eine einzelne Hitobito-Gruppe darf darüber höchstens einer In-App-Stufe zugeordnet sein. Die Ableitung soll nachvollziehbar, testbar und später austauschbar bleiben.
- Akzeptanzkriterien:
  - Die Stufenzuordnung ist zentral und global im Code definiert.
  - Eine einzelne Hitobito-Gruppe kann im MVP höchstens einer In-App-Stufe zugeordnet werden.
  - Fehlt für einen relevanten Gruppentyp eine Regel, führt das nicht zu einer falschen Stufe.
  - Die Zuordnung kann für Anzeigen und Filter des MVP verwendet werden.
- Abhängigkeiten: Ticket 3, Ticket 3b, Ticket 6.
- Nicht Teil dieses Tickets: Automatische Heuristiken aus Gruppenattributen, benutzerseitige Konfiguration der Zuordnung.

### Ticket 8: Suche und Statistik strikt an den aktiven Arbeitskontext binden

- Titel: Suche und Statistik strikt an den aktiven Arbeitskontext binden
- Typ: Feature
- Priorität: P1
- Status: umgesetzt
- Umsetzungsstand: Die Suche ist ueber Ticket 8a produktiv an den aktiven Arbeitskontext gebunden. Der Statistik-Tab zeigt produktiv bereits eine erste kontextgebundene Kennzahl als Mitgliederanzahl des aktiven Arbeitskontexts und aktualisiert sich nach einem Layerwechsel.
- Ziel: Suchen und Kennzahlen sollen fachlich konsistent bleiben und nie unbemerkt mehrere Layer vermischen.
- Kurzbeschreibung: Suche und Statistik arbeiten im MVP ausschließlich auf dem lesbaren Bestand des aktiven Arbeitskontexts. Rekursive Betrachtungen über Unterlayer hinweg sind ausdrücklich nicht Teil des MVP. Ein Kontextwechsel muss beide Bereiche sofort auf den neuen Layer umstellen.
- Akzeptanzkriterien:
  - Suche liefert nur Treffer aus dem aktiven Arbeitskontext.
  - Statistik berechnet Kennzahlen nur auf Basis des aktiven Arbeitskontexts.
  - Unterlayer fließen nicht automatisch in Suchergebnisse oder Kennzahlen ein.
  - Nach einem Kontextwechsel beziehen sich Suche und Statistik ausschließlich auf den neuen Kontext.
- Abhängigkeiten: Ticket 3, Ticket 5.
- Nicht Teil dieses Tickets: Globale Suche über mehrere Layer, rekursive Statistik über Unterlayer.

### Ticket 8a: Suche im Arbeitskontext auf Namen, ID und alle E-Mails erweitern

- Titel: Suche im Arbeitskontext auf Namen, ID und alle E-Mails erweitern
- Typ: Feature
- Priorität: P1
- Status: umgesetzt
- Umsetzungsstand: Die Suche der Mitgliederliste arbeitet im aktiven Arbeitskontext bereits ueber Vorname, Nachname, Nickname, Mitgliedsnummer und alle strukturierten E-Mail-Adressen. Der Such-Hint ist auf diesen Scope angepasst, und Tests sichern ab, dass Telefonnummern und Adressen diese erste Suchstufe weiterhin nicht beeinflussen.
- Ziel: Die erste Suchausbaustufe passend zum neuen Personenmodell liefern, ohne den Scope unnötig zu verbreitern.
- Kurzbeschreibung: Die Suche soll im aktiven Arbeitskontext weiterhin strikt kontextgebunden bleiben, aber statt der alten Legacy-Felder gezielt auf Vorname, Nachname, Nickname, ID und alle verfügbaren E-Mail-Adressen zugreifen. Telefonnummern und Adressen werden im Modell vorbereitet, sollen in dieser ersten Suchstufe jedoch bewusst noch nicht durchsucht werden.
- Akzeptanzkriterien:
  - Suche liefert nur Treffer aus dem aktiven Arbeitskontext.
  - Gesucht wird über Vorname, Nachname, Nickname, Mitglieds- oder Personen-ID sowie primäre und zusätzliche E-Mails.
  - Die Suche hängt nicht mehr an Legacy-Feldern wie `email1`, `email2`, `telefon1`, `telefon2` oder `telefon3`.
  - Telefonnummern und Adressen beeinflussen diese erste Suchstufe nicht.
- Abhängigkeiten: Ticket 3c, Ticket 3d, Ticket 8.
- Nicht Teil dieses Tickets: Telefon- oder Adresssuche, globale Suche, historische Rollenstatistiken.

### Ticket 8b: Vollständige und historische Roles direkt nach Kontextaufbau im Hintergrund nachladen

- Titel: Vollständige und historische Roles direkt nach Kontextaufbau im Hintergrund nachladen
- Typ: Feature
- Priorität: P1
- Status: umgesetzt
- Umsetzungsstand: Der initiale Arbeitskontext bleibt produktiv schlank und enthält weiterhin nur Personen, Gruppen und mitgliedsZuordnungen. Vollständige Roles werden über einen separaten Roles-Pfad in `lib/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart` nachgeladen, in `Mitglied.roles` persistiert und durch `rolesSindGeladen` im Read-Model sowie im lokalen Cache abgesichert. Die produktive Verdrahtung startet dieses Nachladen jetzt automatisch direkt nach Cache-Wiederherstellung, initialem Remote-Laden, Refresh und Layerwechsel im Hintergrund aus `lib/presentation/model/arbeitskontext_model.dart`; gezielte Absicherung besteht in `test/hitobito_arbeitskontext_read_model_repository_test.dart` und `test/arbeitskontext_model_test.dart`.
- Ziel: Eine belastbare Datengrundlage für spätere Statistiken und Verlaufssichten schaffen, ohne den Initial-Load des Arbeitskontexts unnötig aufzublähen.
- Kurzbeschreibung: Rollen werden fachlich nicht mehr als Tätigkeiten bezeichnet, sondern konsistent als Roles. Der initiale Load des Arbeitskontexts bleibt schlank und trennt das Laden des People-Bestands von den vollständigen, auch historischen Roles. Für Listen und Filter bleiben mitgliedsZuordnungen als kompakte Struktur im Arbeitskontext erhalten. Vollständige Roles werden über /api/roles getrennt vom People-Load nachgeladen und im Zielmodell Mitglied.roles geführt. Das Nachladen startet automatisch direkt nach erfolgreichem Kontextaufbau im Hintergrund und nicht erst irgendwann später durch einen separaten Bedarfs-Trigger.
- Ausbau-Schritte:
  - Fachbegriffe, Modellnamen und Dokumentation von Tätigkeiten auf Roles umstellen.
  - Den initialen People-Load so begrenzen, dass nur der schlanke Arbeitskontext einschließlich mitgliedsZuordnungen aufgebaut wird.
  - Einen separaten Ladepfad für vollständige Roles über /api/roles einführen, der aktive und historische Roles nachladen kann.
  - Das Zielmodell Mitglied.roles produktiv anbinden und so persistieren, dass bestehende Listen- und Filterpfade weiter auf mitgliedsZuordnungen basieren.
  - Das Nachladen der vollständigen Roles nach erfolgreichem Kontextaufbau automatisch im Hintergrund starten, ohne den initialen People-Load aufzublähen.
- Akzeptanzkriterien:
  - Rollen werden im Fachkontext und in der Benennung nicht mehr als Tätigkeiten, sondern als Roles geführt.
  - Der initiale Load des Arbeitskontexts lädt keine vollständigen historischen Roles mit.
  - Vollständige Roles werden getrennt vom People-Load über /api/roles nachgeladen.
  - Das Nachladen vollständiger Roles startet automatisch direkt nach erfolgreichem Aufbau oder Wiederherstellung des Arbeitskontexts im Hintergrund.
  - Mitglied.roles ist das Zielmodell für vollständige, auch historische Roles.
  - mitgliedsZuordnungen bleiben als kompakte Struktur für Listen und Filter bestehen.
  - Die Datengrundlage ist für spätere Mitgliedschafts- und Rollenstatistiken nutzbar, ohne den MVP-Initial-Load zu verschlechtern.
- Abhängigkeiten: Ticket 3b, Ticket 3d, Ticket 8.
- Nicht Teil dieses Tickets: Konkrete Statistik-UI, rekursive Auswertungen über Unterlayer.

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

### Ticket 9a: Offene Personenfelder und nicht exponierte API-Felder fachlich klären

- Titel: Offene Personenfelder und nicht exponierte API-Felder fachlich klären
- Typ: Klärung
- Priorität: P1
- Status: offen
- Ziel: Transparent festhalten, welche gewünschten Felder fachlich relevant sind, aber aktuell nicht belastbar aus der JSON:API ableitbar sind.
- Kurzbeschreibung: Für einzelne Personenfelder bestehen weiterhin Lücken zwischen UI, Rails-Modell und dokumentierter JSON:API. Insbesondere `created_at` für Personen ist in der DPSG-OpenAPI nicht als lesbares People-Feld bestätigt. Tags bleiben ebenfalls außerhalb des Zielmodells, solange dafür kein belastbarer JSON:API-Pfad oder eine fachlich bestätigte Person-Tag-Ressource vorliegt.
- Akzeptanzkriterien:
  - Es gibt eine dokumentierte Entscheidung zum Umgang mit nicht exponierten Feldern wie Person-`created_at`.
  - Es ist festgehalten, dass `country` nicht als Nationalität interpretiert wird.
  - Es ist festgehalten, dass Tags vorerst bewusst außerhalb des Zielmodells bleiben.
  - Offene API-Fragen sind so dokumentiert, dass sie in spätere Folgearbeiten überführt werden können.
- Abhängigkeiten: Ticket 3c, Ticket 3d.
- Nicht Teil dieses Tickets: Implementierung neuer API-Clients oder UI für Tags.

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
  - Die Beziehung zu bestehenden Gruppenfiltern, Stufenfiltern und benutzerdefinierten Filtergruppen ist geklärt.
- Abhängigkeiten: Ticket 6, Ticket 7.
- Nicht Teil dieses Tickets: Konkrete Umsetzung von Tags, Dashboards oder personalisierten Filtern.

## Empfohlene weitere Reihenfolge ab aktuellem Stand

1. Ticket 8b: Historischen Rollenverlauf für spätere Statistiken und Verlaufssichten laden
2. Ticket 9: Schreib- und Bearbeitungslogik für teilweise sichtbare Layer fachlich klären
3. Ticket 9a: Offene Personenfelder und nicht exponierte API-Felder fachlich klären
4. Ticket 10: Mehrere offline verfügbare Arbeitskontexte konzipieren
5. Ticket 11: Rekursive Sichten über Unterlayer als eigener Produktentscheid vorbereiten
6. Ticket 12: Persönliche Teilmengen, Tags und "Meine Gruppe" nach dem MVP definieren

## Hinweis zur Nutzung in GitHub

Die Ticketabschnitte sind bewusst so formuliert, dass sie direkt als Grundlage für einzelne GitHub-Issues übernommen und bei Bedarf nur noch um technische Umsetzungshinweise, Labels oder Story-Points ergänzt werden können.
  