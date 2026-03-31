---
layout: page
title: Arbeitskontext-Modell
permalink: /arbeitskontext/
---

Die Hitobito-basierte App arbeitet fachlich immer in genau einem aktiven Arbeitskontext.

Ein Arbeitskontext ist immer genau ein Layer. Hitobito-Rechte können den darin sichtbaren Personen- und Gruppenbestand verkleinern, ohne dass dadurch ein anderer Arbeitskontext entsteht. Technisch sichtbare Layer aus Hitobito werden in der App nur dann als Arbeitskontexte angeboten, wenn sie sich aus eigenen Rollen mit arbeitskontextrelevanten Lese- oder Schreibrechten ableiten lassen. Gruppen werden in der App nicht als eigene Hauptkontexte behandelt, sondern primär als Filter oder Teilmengen innerhalb des aktiven Arbeitskontexts.

Der fachliche Fokus der App bleibt auf dem Stamm. Höhere Ebenen wie Bezirk, Diözese oder Bund werden durch bewussten Kontextwechsel zwischen mehreren relevanten Layern unterstützt. Rechte wie `layer_and_below_read` oder `layer_and_below_full` können dafür zusätzlich Unterlayer als eigene Wechselziele relevant machen. Zusatzrechte wie `contact_data` erweitern diese Layerliste nicht. Unterlayer gehören nicht automatisch zum aktiven Arbeitskontext, sondern werden nur durch einen expliziten Wechsel geöffnet.

Offline verfügbar ist in der ersten Ausbaustufe genau ein Arbeitskontext. Beim Wechsel des Arbeitskontexts wird der lokal gespeicherte Kontext ersetzt und neu geladen.

Mitgliedsliste, Suche, Statistik und persönliche Dashboards arbeiten jeweils nur innerhalb des aktiven Arbeitskontexts und nur auf dem aus Hitobito lesbar geladenen Bestand. Für den MVP wird die In-App-Stufe global im Code genau einer Hitobito-Gruppe zugeordnet. Leere Gruppen ohne Personen werden in der Leseansicht nicht angezeigt. Leere Layer bleiben dagegen als mögliche Arbeitskontexte zulässig. Ohne mindestens ein relevantes Layer- oder Gruppen-Lese- beziehungsweise Schreibrecht zeigt die App einen expliziten Nicht-berechtigt-Zustand mit Logout an.
