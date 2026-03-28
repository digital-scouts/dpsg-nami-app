---
layout: page
title: Arbeitskontext-Modell
permalink: /arbeitskontext/
---

Die Hitobito-basierte App arbeitet fachlich immer in genau einem aktiven Arbeitskontext.

Ein Arbeitskontext ist immer genau ein Layer. Er umfasst alle Mitglieder dieses Layers sowie die zugehörigen Nicht-Layer-Gruppen als Struktur- und Filterbasis. Gruppen werden in der App nicht als eigene Hauptkontexte behandelt, sondern primär als Filter oder Teilmengen innerhalb des aktiven Arbeitskontexts.

Der fachliche Fokus der App bleibt auf dem Stamm. Höhere Ebenen wie Bezirk, Diözese oder Bund werden durch bewussten Kontextwechsel zwischen mehreren verfügbaren Layern unterstützt. Unterlayer gehören nicht automatisch zum aktiven Arbeitskontext, sondern werden nur durch einen expliziten Wechsel geöffnet.

Offline verfügbar ist in der ersten Ausbaustufe genau ein Arbeitskontext. Beim Wechsel des Arbeitskontexts wird der lokal gespeicherte Kontext ersetzt und neu geladen.

Mitgliedsliste, Suche, Statistik und persönliche Dashboards arbeiten jeweils nur innerhalb des aktiven Arbeitskontexts. Der initiale Arbeitskontext wird aus dem Primary Layer der Person abgeleitet.
