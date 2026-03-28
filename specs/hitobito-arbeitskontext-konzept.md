# Arbeitskontext-Konzept für die Hitobito-App

## Zweck

Dieses Dokument hält die fachliche App-Konzeption für Hitobito vor der Implementierung fest. Es soll als Grundlage für spätere Tickets, Detailentscheidungen und UX-Abstimmungen dienen.

## Ausgangslage

- Die App richtet sich weiterhin primär an Leitende im Stammesalltag.
- Der Kernnutzen bleibt mobiler Zugriff auf Mitgliedsdaten, möglichst auch offline.
- Mit Hitobito können Nutzer jedoch auf mehrere Layer zugreifen, zum Beispiel Stamm, Bezirk, Diözese oder Bund.
- Die App soll diesen Mehrfachzugriff unterstützen, ohne sich in einen generischen Organisationsbaum-Browser zu verwandeln.

## Technische Grundlage aus Hitobito

- Technisch sind Layer und normale Gruppen beide Ressourcen vom Typ `Group`.
- Einige Gruppen sind zusätzlich als Layer markiert.
- Rollen hängen immer an genau einer Gruppe.
- Eine Person kann mehrere Rollen in mehreren Gruppen haben.
- `primary_group` ist die vorhandene primäre Gruppenzuordnung der Person und dient in der App als Default für den Startkontext.
- Ein Layer kann Nicht-Layer-Gruppen wie Vorstände, Arbeitskreise oder Stufen-Gruppen enthalten.
- Unterlayer sind eigenständige Layer im Baum und nicht automatisch Teil desselben mobilen Arbeitsraums.

## Begriffe

### Arbeitskontext

Ein Arbeitskontext ist der aktuell aktive Layer in der App.

Er umfasst:

- alle Mitglieder dieses Layers
- alle zu diesem Layer gehörenden Nicht-Layer-Gruppen als Struktur- und Filterbasis

Er umfasst nicht automatisch:

- Unterlayer
- weitere Layer, auf die dieselbe Person ebenfalls Zugriff hat

### Teilmenge

Eine Teilmenge ist eine eingeschränkte Sicht innerhalb des aktuellen Arbeitskontexts, zum Beispiel:

- eine oder mehrere Gruppen
- später Tags
- später eine persönliche Auswahl für "Meine Gruppe"

Teilmengen ändern nie den Arbeitskontext selbst.

### Kontextwechsel

Ein Kontextwechsel ist der bewusste Wechsel von einem Layer in einen anderen Layer, auf den die Person ebenfalls Zugriff hat.

## Zielbild

Die App arbeitet immer in genau einem aktiven Arbeitskontext. Alle Seiten der App sind Ansichten auf denselben Arbeitskontext. Der Stamm bleibt der Normalfall und fachliche Fokus der App. Höhere Ebenen werden nicht über eine gleichzeitige Mehr-Layer-Sicht abgebildet, sondern über einen expliziten Wechsel zwischen Arbeitskontexten.

## Verbindliche Entscheidungen

### 1. Ein aktiver Arbeitskontext

- Die App besitzt immer genau einen aktiven Arbeitskontext.
- Ein Arbeitskontext ist immer genau ein Layer.
- Alle Kernseiten der App arbeiten ausschließlich auf diesem einen Arbeitskontext.

### 2. Gruppen sind Filter innerhalb des Arbeitskontexts

- Gruppen werden in der App nicht als gleichrangige Hauptkontexte behandelt.
- Nicht-Layer-Gruppen dienen primär als Filter, Teilmengen oder spätere Vorlagen für persönliche Dashboards.
- Die Mitgliedsliste zeigt ohne Filter alle Mitglieder des aktiven Arbeitskontexts.
- Gruppenfilter schränken diese Menge nur ein.

### 3. Unterlayer sind eigene Arbeitskontexte

- Unterlayer gehören nicht automatisch zum aktuellen Arbeitskontext.
- Ein Bezirkskontext zeigt daher nicht automatisch alle Mitglieder der darunterliegenden Stämme.
- Ein Stamm unterhalb eines Bezirks ist ein eigener möglicher Arbeitskontext.
- Der Wechsel in einen Unterlayer erfolgt nur bewusst über Kontextwechsel.

### 4. Startkontext

- Der initiale Arbeitskontext wird aus `primary_group` beziehungsweise dem daraus ableitbaren Primary Layer bestimmt.
- Falls dies ausnahmsweise nicht brauchbar bestimmbar ist, wird der erste verfügbare Layer aus einer stabil sortierten Liste verwendet.
- Ein komplexerer Default wie "zuletzt genutzter Kontext" ist vorerst nicht Teil der Konzeption.

### 5. Offline-Strategie für die erste Ausbaustufe

- Offline verfügbar ist zunächst genau ein Arbeitskontext.
- Beim Wechsel des Arbeitskontexts wird der bisher lokal gespeicherte Kontext verworfen und der neue Kontext geladen.
- Damit ist lokal immer genau ein Layer mit seinen Daten verankert.
- Diese Entscheidung dient Einfachheit, begrenzter Datenmenge und einer klaren Erwartungshaltung für Nutzer.

### 6. Suche, Listen und Statistik

- Suche arbeitet nur innerhalb des aktiven Arbeitskontexts.
- Mitgliedslisten zeigen nur Personen des aktiven Arbeitskontexts.
- Statistiken beziehen sich zunächst nur auf den aktiven Arbeitskontext.
- Rekursive Statistiken über Unterlayer sind vorerst ausgeschlossen.

### 7. Meine Gruppe

- "Meine Gruppe" ist kein eigenes Strukturprinzip der App.
- "Meine Gruppe" ist ein Dashboard oder eine personalisierte Teilmenge innerhalb des aktiven Arbeitskontexts.
- Die genaue Herleitung dieser Teilmenge ist für die Arbeitskontext-Entscheidung nicht relevant und kann später separat definiert werden.

## Folgen für die Produktlogik

### Stammleitung

- Für die meisten Nutzer ist der Arbeitskontext identisch mit dem eigenen Stamm.
- Die App wirkt dadurch weiterhin wie eine Stamm-App.
- Gruppen innerhalb des Stamms wie Wölflinge oder Jungpfadfinder sind nur Filter auf denselben Kontext.

### Bezirks-, Diözesan- oder Bundesebene

- Ein Layer auf höherer Ebene ist ein vollwertiger Arbeitskontext.
- Er kann eigene Personen enthalten, die keinem darunterliegenden Stammkontext zugeordnet sind.
- Gleichzeitig kann dieser Kontext als Verteiler dienen, um bewusst in andere Layer zu wechseln.
- Die App zeigt in diesem Kontext aber weiterhin nur die Personen des aktiven Layers selbst.

## Abgrenzungen

Nicht Teil der App beziehungsweise dieses Konzepts sind:

- das Anlegen neuer Layer oder Gruppenstrukturen
- seltene oder administrative Systemkonfigurationen wie Etikettenformate, Hilfetexte oder Kursarten
- eine globale Suche über mehrere Layer gleichzeitig
- eine parallele Offline-Haltung aller verfügbaren Layer in der ersten Ausbaustufe
- eine rekursive Gesamtstatistik über Unterlayer in der ersten Ausbaustufe

## Warum dieses Modell gewählt wurde

- Es hält den Fokus der App auf dem Stamm und dem mobilen Arbeitsalltag.
- Es vermeidet, dass die App zu einer schwer bedienbaren Baum-Navigation wird.
- Es begrenzt Datenmenge, Speicherbedarf und Synchronisationsaufwand.
- Es bleibt offen für spätere Erweiterungen, ohne den Einstieg für 95 Prozent der Nutzer zu verkomplizieren.
- Es passt zu der Annahme, dass die meisten Nutzer nur einen relevanten Layer haben und nie aktiv wechseln müssen.

## Offene Ausbaupunkte

Diese Punkte sind bewusst noch offen und sollen später separat entschieden werden:

- Unterstützung mehrerer offline verfügbarer Arbeitskontexte
- Statistikoptionen für einen Layer plus Unterlayer
- Rolle von Tags als zusätzliche Teilmengen innerhalb des Arbeitskontexts
- Rolle persönlicher Auswahlen für "Meine Gruppe"

## Ableitbare Ticket-Schnitte

Aus diesem Dokument lassen sich später unter anderem folgende Ticketbereiche ableiten:

- Modellierung eines `WorkingContext` oder ähnlichen Domain-Konzepts
- Ableitung des Startkontexts aus `primary_group` und verfügbaren Layern
- Persistenz und Austausch genau eines lokalen Arbeitskontexts
- Kontextwechsel-Flow zwischen verfügbaren Layern
- Mitgliedsliste für alle Personen des aktiven Arbeitskontexts
- Gruppenfilter innerhalb des Arbeitskontexts
- Kontextgebundene Suche
- Kontextgebundene Statistiken
- Grundlagen für einen späteren Ausbau auf mehrere Offline-Arbeitskontexte

## Kurzfassung

Die App ist kein generischer Hitobito-Baum-Browser. Sie ist ein mobiles Arbeitswerkzeug, das immer in genau einem aktiven Layer arbeitet. Gruppen, Tags und spätere persönliche Auswahlen sind Teilmengen dieses Arbeitskontexts. Höhere Ebenen werden über bewussten Kontextwechsel unterstützt. Offline ist in der ersten Ausbaustufe genau ein Arbeitskontext verfügbar.
