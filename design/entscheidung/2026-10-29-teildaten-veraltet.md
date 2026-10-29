# Veralteter EFZ- und Qualifikationsstand

- **Datum:** 2026-10-29
- **Runden:** 1
- **Anlass:** Scheitert der EFZ- oder Qualifikationsabruf, zeigt die App den letzten erfolgreichen Stand weiter. Dieser Stand ist auf sichtbare Personen gefiltert und höchstens 60 Tage alt (#194, A-132). Er muss als veraltet erkennbar sein.
- **Umsetzung:** Branch `fix/teildaten-altbestand`; `member_qualifikationen_tab.dart`, `arbeitskontext_model.dart`, `navigation_home.page.dart`, `settings_qualifikationen_page.dart`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Mitgliedsdetails | D3: Pille am Abschnittskopf | Rechts am Kopf des betroffenen Abschnitts („Führungszeugnis“ oder „Qualifikationen“) steht eine kleine Pille „Stand 12.10.“ in Warnfarbe, ohne Erklärsatz. Die Daten darunter erscheinen wie bei aktuellem Stand. |
| Ladeanzeige | L2: Warnsymbol | Der Schritt „Qualifikationen“ zeigt ein oranges Ausrufezeichen statt Haken oder Kreis, rechts „veraltet · 12.10.“ in Warnfarbe. |
| Qualifikationen-Übersicht | U2: Box unter der Karte | Unter der Qualifikationskarte steht die graue Hinweisbox, die die Seite schon für „keine Qualifikationen“ nutzt: „Stand vom 12.10.2026. Der letzte Abruf ist fehlgeschlagen, neuere Änderungen fehlen.“ Ist nur das EFZ veraltet, beginnt der Text mit „Führungszeugnis:“. |

Zusätzliche Vorgaben aus den Kommentaren:

- keine

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Mitgliedsdetails | Ist, D1 (Hinweiszeile am Ende), D2 (Hinweiszeile oben) | Ist wirkt aktuell, obwohl der Abruf fehlschlug; D1 und D2 nicht gewählt |
| Ladeanzeige | Ist („nicht geladen“), L1 (Kreis mit Datum) | Ist ist falsch, weil Daten vorhanden sind; L1 nicht gewählt |
| Qualifikationen-Übersicht | Ist, U1 (Zeile über der Karte), U3 (Zeile im Kopf) | nicht gewählt |

## Offen

- Ohne bekanntes Datum (alter Cache vor dieser Änderung) zeigen Pille und Ladeanzeige nur „veraltet“, die Box nennt kein Datum.
