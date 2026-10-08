---
name: feedbackrunde
description: Visuelle Änderungen (UI, Layout, Icons, Grafiken, Doku-Seiten) vor der Umsetzung als HTML-Feedbackrunde mit Varianten klären, bis der Nutzer zufrieden ist, und das Ergebnis als Entscheidung unter design/entscheidung/ ablegen. Verwenden, bevor sichtbare Änderungen umgesetzt werden, oder wenn der Nutzer eine Feedbackrunde, Entwürfe oder Varianten zum Vergleichen möchte.
---

# Feedbackrunde

Sichtbare Änderungen werden vor dem Code in HTML-Runden entschieden: Varianten zeigen, Rückmeldung holen, nächste Runde, bis der Nutzer zufrieden ist. Im Repo landet nur die Entscheidung, nicht die Rohdaten.

## 0. Ist eine Runde nötig?

- **Direkt eine Runde:** neue Oberfläche, Layout mit Alternativen, mehrere offene Gestaltungsfragen, neue Grafiken oder Icons.
- **Kleine sichtbare Änderung** (ein Text, ein Abstand, eine Farbe nach bestehendem Muster, eine eindeutige Vorgabe des Nutzers): per AskUserQuestion fragen, ob eine Feedbackrunde gewünscht ist oder ein anderer Weg reicht, etwa Umsetzen und Vorher/Nachher-Screenshot oder eine Textauswahl.
- **Im Zweifel:** nachfragen.

## 1. Vorab klären

Inhaltliche Fragen (Umfang, Daten, Metriken, Rechte) per AskUserQuestion klären. Alles, was man sehen muss, gehört in die HTML-Runde. ASCII-Skizzen reichen dem Nutzer nicht.

## 2. Runde bauen

- **Ordner:** `design/.runden/<thema>/` (git-ignoriert). Dorthin `vorlage/runde.css` und `vorlage/runde.js` kopieren und `vorlage/beispiel.html` als `runde-N.html` als Ausgangspunkt nehmen.
- **`Runde.start({...})`** konfiguriert die Seite (Felder siehe Kopf von `runde.js`):
  - `nr` und `thema` ergeben den Tab-Titel `#N Thema`.
  - `geraete`: App-Entwicklung meist nur `['iphone']`; für `docs/` und Webseiten `['web', 'ipad', 'iphone']`, wenn das Layout je Gerät abweicht.
  - `theme`: Startwert `hell`, `dunkel` oder `beide`. Hell/Dunkel immer dann zeigen, wenn Farben, Bilder oder Kontraste Teil der Frage sind.
  - `steuerung`: Wahlen in der Kopfzeile, die auf alle Screens wirken (Person, Datensatz, Tab, Zustand). Mit `frage: '<id>'` folgt die Steuerung der Auswahl dieser Frage, damit Folgescreens die gewählte Variante zeigen.
  - `fragen`: eine je offener Entscheidung, `mehrfach: true` falls mehrere Varianten zusammen gewählt werden dürfen.
  - `festgelegt`: ab Runde 2 die bereits entschiedenen Punkte als kurze Liste.
  - `render(z)`: füllt die `[data-slot]`-Container mit `Runde.geraet(z, html, { titel, shot, fest, url })`.
- **Gerätehöhe:**
  - Jeder Rahmen ist mindestens einen Bildschirm hoch: iPhone 844, iPad 1180, Web 800.
  - Längere Inhalte laufen weiter, eine gestrichelte Linie „Ende 1. Bildschirm“ zeigt, was ohne Scrollen sichtbar ist.
  - Elemente mit `class="unten"` (Tabbar, Aktionsleiste) sitzen am unteren Rand.
  - `fest: true` schneidet auf genau einen Bildschirm ab.
- **Seiteninhalt:**
  - Je Frage eine `<section class="frage" data-frage="…">` mit 2–3 `<div class="variante" data-variante="…" data-titel="K1: Kurzname">`.
  - In Runde 1 zusätzlich „Ist“ als Variante, wenn es einen bestehenden Stand gibt.
  - Folgescreens ohne Frage kommen in `<section class="folge">`.
  - Ab Runde 2 nur noch offene Fragen zeigen.
- **Gestaltung:**
  - Synthetische, realistische Daten, auch Grenzfälle (lange Namen, leere Listen, viele Einträge).
  - Schriftgrößen nur über `--t-caption … --t-large`, Farben nur über die Tokens (`--bg`, `--surface`, `--fg`, `--fg2`, `--primary`, …). Nur dann greifen Theme und Schriftgröße 1,3/1,4 aus der Kopfzeile.
  - Echte App-Farben stehen in `lib/presentation/theme/theme.dart` bzw. `design/supporter/palettes.json`. Abweichende Paletten über `farben: { hell, dunkel }` setzen.
  - Projektregeln beachten, z. B. Abstand statt Trennlinie und mobil Text vor Gerät (siehe Memory).

Die Laufzeit ergänzt automatisch:
- an jeder Variante „Wählen“ und ein Kommentarfeld,
- je Frage „Keine passt“ und einen Fragekommentar,
- am Ende „Sonst noch“.

Die Auswahl bleibt im `localStorage`, ein Neuladen ist also unschädlich. „Entscheidungen kopieren“ in der Kopfzeile legt einen Markdown-Block direkt in die Zwischenablage.

## 3. Selbst prüfen, dann öffnen

```sh
node .claude/skills/feedbackrunde/vorlage/render.mjs design/.runden/<thema>/runde-N.html [theme=beide ts=1.4 geraet=ipad <steuerung>=<wert>]
```

- Schreibt `seite.png` und alle `[data-shot]` nach `design/.runden/<thema>/out/runde-N/`. Die Bilder selbst ansehen (Read) und Fehler beheben: Überlappungen, abgeschnittene Texte, falsche Farben in Dunkel, Umbruch bei 1,4.
- `--js '<ausdruck>'` wertet nach dem Laden JavaScript aus, z. B. um Klicks und `Runde.markdown()` zu prüfen.
- Erst danach `open design/.runden/<thema>/runde-N.html`.

Im Chat kurz nennen, was zu entscheiden ist, wofür jede Variante steht und was schon festgelegt ist.

## 4. Rückmeldung auswerten

- Der Nutzer fügt den kopierten Block ein: `## Rückmeldung #N Thema` mit Wahl und Kommentaren je Frage.
- Unklare oder widersprüchliche Punkte per AskUserQuestion klären, nicht raten.
- Ist alles entschieden und ohne Änderungswunsch, folgt der Abschluss. Sonst Runde N+1 mit `festgelegt` und nur den offenen Fragen. Neue Details, etwa eine Position oder Größe, wieder als Varianten zeigen.

## 5. Abschluss

1. `design/entscheidung/JJJJ-MM-TT-<thema>.md` nach `vorlage/entscheidung.md` anlegen. Inhalt:
   - worüber entschieden wurde,
   - das Ergebnis je Frage, so beschrieben, dass man es ohne Bild versteht,
   - Zusatzvorgaben aus Kommentaren,
   - abgelehnte Varianten mit Grund,
   - Offenes.
2. `design/.runden/<thema>/` löschen. Keine Rundendateien, Screenshots oder Entwurfs-Generatoren versionieren.
3. Umsetzen. Wiederverwendbare Quellen, die die App oder Assets wirklich brauchen, gehören in den passenden Ordner unter `design/<bereich>/`, ohne `entwurf` im Namen. Beispiel: die Generatoren in `design/supporter/`.
4. Die Entscheidungsdatei kommt in denselben PR wie die Umsetzung.
