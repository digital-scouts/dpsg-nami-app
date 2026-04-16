# Arbeitskontext-Konzept für die Hitobito-App

## Zweck

Dieses Dokument hält die fachliche App-Konzeption für Hitobito fest. Es dient als Grundlage für umgesetzte und weitere Tickets, Detailentscheidungen und UX-Abstimmungen.

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
- Technische Sichtbarkeit eines Layers in Hitobito ist nicht automatisch gleichbedeutend mit fachlicher Relevanz dieses Layers für die App.

## Begriffe

### Arbeitskontext

Ein Arbeitskontext ist der aktuell aktive Layer in der App.

Er umfasst:

- den für den aktuellen Nutzer aus Hitobito lesbar verfügbaren Personenbestand dieses Layers
- die für den aktuellen Nutzer aus Hitobito lesbar verfügbaren Nicht-Layer-Gruppen dieses Layers als Struktur- und Filterbasis

Er umfasst nicht automatisch:

- Unterlayer
- weitere Layer, auf die dieselbe Person ebenfalls Zugriff hat

### Teilmenge

Eine Teilmenge ist eine eingeschränkte Sicht innerhalb des aktuellen Arbeitskontexts, zum Beispiel:

- eine oder mehrere Gruppen
- später Tags
- später eine persönliche Auswahl für "Meine Gruppe"

Teilmengen ändern nie den Arbeitskontext selbst.

### Relevanter Layer

Ein relevanter Layer ist ein Layer, den die App dem Nutzer überhaupt als möglichen Arbeitskontext anbietet.

Relevante Layer werden nicht aus allen technisch sichtbaren Layern übernommen, sondern aus den eigenen Rollen und deren arbeitskontextrelevanten Rechten abgeleitet.

Zusatzrechte wie `contact_data` können die technische Sichtbarkeit anderer Personen oder Gruppen vergrößern, machen diese Layer aber nicht automatisch zu angebotenen Arbeitskontexten.

### Kontextwechsel

Ein Kontextwechsel ist der bewusste Wechsel von einem Layer in einen anderen relevanten Layer, den die App der Person anbietet.

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
- Sonstige Gruppen sind im MVP keine vordefinierten Hauptfilter, können aber in benutzerdefinierten Filtern genutzt werden.

### 2a. Rechte verkleinern die sichtbare Teilmenge

- Hitobito bleibt die Quelle der Wahrheit dafür, welche Personen und Gruppen ein Nutzer lesen darf.
- Der Arbeitskontext bleibt trotzdem derselbe Layer, auch wenn der sichtbare Bestand darin durch Rechte stark eingeschränkt ist.
- Die App modelliert im MVP kein eigenes zusätzliches Rechte-System, sondern arbeitet mit dem lesbar aus Hitobito geladenen Bestand.
- Für die App macht es daher fachlich keinen Unterschied, ob ein Layer von Haus aus klein ist oder durch Rechte nur als kleiner Ausschnitt sichtbar wird.

### 2b. Relevante Layer werden aus eigenen Rollen abgeleitet

- Die App unterscheidet zwischen technisch sichtbaren Layern und fachlich relevanten Layern.
- Fachlich relevant sind nur Layer, die sich aus eigenen Rollen des angemeldeten Nutzers mit arbeitskontextrelevanten Lese- oder Schreibrechten herleiten lassen.
- `layer_read` und `layer_full` machen genau den zugehörigen Layer relevant.
- `layer_and_below_read` und `layer_and_below_full` machen den zugehörigen Layer und alle darunterliegenden Layer relevant.
- Gruppenrechte wie `group_read`, `group_and_below_read` oder `group_and_below_full` machen den zugehörigen Layer relevant, vergrößern aber primär die sichtbare Teilmenge innerhalb dieses Layers und nicht automatisch die Menge angebotener Layer.
- `contact_data`, Finanz- oder Antragsrechte sind für sich allein keine Grundlage für einen angebotenen Arbeitskontext.
- Rollen mit `admin` oder `impersonation` werden für den normalen App-Fall zunächst nicht als eigener Produktpfad modelliert.
- Hat eine Person kein arbeitskontextrelevantes Layer- oder Gruppen-Lese- beziehungsweise Schreibrecht, ist die App fachlich nicht für diesen Nutzer vorgesehen.

### 3. Unterlayer sind eigene Arbeitskontexte

- Unterlayer gehören nicht automatisch zum aktuellen Arbeitskontext.
- Ein Bezirkskontext zeigt daher nicht automatisch alle Mitglieder der darunterliegenden Stämme.
- Ein Stamm unterhalb eines Bezirks ist ein eigener möglicher Arbeitskontext.
- Der Wechsel in einen Unterlayer erfolgt nur bewusst über Kontextwechsel.

### 4. Startkontext

- Der initiale Arbeitskontext wird aus `primary_group` beziehungsweise dem daraus ableitbaren Primary Layer bestimmt, sofern dieser zu den relevanten Layern der Person gehört.
- Falls dies ausnahmsweise nicht brauchbar bestimmbar ist, wird der erste relevante Layer aus einer stabil sortierten Liste verwendet.
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
- Sichtbarkeit und Filterung arbeiten dabei immer auf dem für den Nutzer lesbaren Teilbestand des aktiven Layers.

### 7. Meine Gruppe

- "Meine Gruppe" ist kein eigenes Strukturprinzip der App.
- "Meine Gruppe" ist ein Dashboard oder eine personalisierte Teilmenge innerhalb des aktiven Arbeitskontexts.
- Die genaue Herleitung dieser Teilmenge ist für die Arbeitskontext-Entscheidung nicht relevant und kann später separat definiert werden.

## Folgen für die Produktlogik

### Stufen und Gruppen

- Hitobito kennt die in der App genutzte Stufenlogik nicht als eigene fachliche Domäne.
- Für den MVP wird die In-App-Stufe deshalb global im Code über feste Regeln zu Hitobito-Gruppentypen abgeleitet.
- Eine einzelne Hitobito-Gruppe entspricht darüber höchstens einer In-App-Stufe.
- Die Ableitung ist zentral im Code hinterlegt und nutzt aktuell bekannte Gruppentypen wie `Group::Meute`, `Group::Sippe`, `Group::Runde` und `Group::Gilde`.
- Personen werden Gruppen in der App über ihre Rollen zugeordnet. Hat eine Person Rollen in mehreren Gruppen, erscheint sie in mehreren Filtern.
- Leere Gruppen ohne Personen werden in der Leseansicht nicht angezeigt.

### Stammleitung

- Für die meisten Nutzer ist der Arbeitskontext identisch mit dem eigenen Stamm.
- Die App wirkt dadurch weiterhin wie eine Stamm-App.
- Gruppen innerhalb des Stamms wie Wölflinge oder Jungpfadfinder sind nur Filter auf denselben Kontext.
- Auch bei eingeschränkten Rechten auf nur Teile des Stammes bleibt der Arbeitskontext fachlich der Stamm-Layer; sichtbar ist dann nur ein kleinerer Ausschnitt.
- Hat eine Person im Stamm nur gruppenbezogene Rechte, bleibt der Stamm-Layer trotzdem der relevante Arbeitskontext; kleiner wird dann die sichtbare Teilmenge innerhalb dieses Layers.

### Bezirks-, Diözesan- oder Bundesebene

- Ein Layer auf höherer Ebene ist ein vollwertiger Arbeitskontext.
- Er kann eigene Personen enthalten, die keinem darunterliegenden Stammkontext zugeordnet sind.
- Gleichzeitig kann dieser Kontext als Verteiler dienen, um bewusst in andere Layer zu wechseln.
- Die App zeigt in diesem Kontext aber weiterhin nur die Personen des aktiven Layers selbst.
- Werden weitere Layer nur über `contact_data` oder ähnliche Zusatzrechte technisch sichtbar, erscheinen sie nicht als angebotene Arbeitskontexte.

### Leere Layer

- Leere Layer bleiben mögliche Arbeitskontexte.
- Ein leerer Layer kann fachlich trotzdem relevant sein, etwa für den Aufbau einer neuen Gruppe oder das Anlegen des ersten Mitglieds.
- Die frühere Hilfsregel "Layer ohne Mitglieder sind nicht relevant" gilt daher nicht mehr.

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
- Erweiterung der Stufenzuordnung über die aktuelle zentrale Ableitung aus Hitobito-Gruppentypen hinaus

## Ableitbare Ticket-Schnitte

Aus diesem Dokument lassen sich später unter anderem folgende Ticketbereiche ableiten:

- Modellierung eines `WorkingContext` oder ähnlichen Domain-Konzepts
- Ableitung relevanter Layer aus Rollen und Rechten
- Ableitung des Startkontexts aus `primary_group` und relevanten Layern
- Persistenz und Austausch genau eines lokalen Arbeitskontexts
- Kontextwechsel-Flow zwischen relevanten Layern
- Mitgliedsliste für alle Personen des aktiven Arbeitskontexts
- Ableitung des lesbaren Teilbestands innerhalb eines Arbeitskontexts aus Hitobito-Rechten
- Gruppenfilter innerhalb des Arbeitskontexts
- zentrale Ableitung von In-App-Stufen aus Hitobito-Gruppentypen
- Kontextgebundene Suche
- Kontextgebundene Statistiken
- Grundlagen für einen späteren Ausbau auf mehrere Offline-Arbeitskontexte

## Kurzfassung

Die App ist kein generischer Hitobito-Baum-Browser. Sie ist ein mobiles Arbeitswerkzeug, das immer in genau einem aktiven Layer arbeitet. Rechte können den sichtbaren Bestand innerhalb dieses Layers verkleinern, ohne den Arbeitskontext zu ändern. Als Arbeitskontexte angeboten werden aber nur die aus eigenen Rollen und arbeitskontextrelevanten Rechten abgeleiteten relevanten Layer. Gruppen, Tags und spätere persönliche Auswahlen sind Teilmengen dieses Arbeitskontexts. Höhere Ebenen werden über bewussten Kontextwechsel unterstützt. Offline ist in der ersten Ausbaustufe genau ein Arbeitskontext verfügbar.
