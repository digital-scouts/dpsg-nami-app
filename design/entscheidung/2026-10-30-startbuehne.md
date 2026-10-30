# Startbühne

- **Datum:** 2026-10-30
- **Runden:** 5 (Runde 1 am 2026-10-29), dazwischen die Marke in #285
- **Anlass:** Der Kaltstart war eine Folge von Brüchen: festes weißes iOS-Startbild, dann ein Schild mit Spinner in der Shell, dann ein harter Schnitt zum Inhalt; auch der Demo-/Live-Wechsel blitzte weiß (#279).
- **Umsetzung:** #279; `lib/presentation/widgets/app_startbuehne.dart`, natives Startbild iOS und Android, Ebenen aus `design/marke/`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Bewegung | B1 Halstuch knoten | Die Animation läuft nur, wenn das Laden länger als 300 ms dauert, und nur einmal; danach steht die Person still. Nach etwa 1,5 s erscheint dezent der Status. Ist alles schneller bereit, läuft nur der Abgang. |
| Motiv | Einzelperson wie im Logo | Eine Person als weiße Linie (P1) mit grauem Halstuch und Lederring, 160 pt, mittig auf der Fläche. Nicht das App-Icon. |
| Knoten | K1, zügig | Etwa 0,6 s. Erst legt sich das Tuch um die Schultern (Fade, Scale 0,96 → 1, 220 ms), die Zipfel liegen unten zusammen. Ab 120 ms schiebt sich der Ring von unten darüber (Feder 320 ms, Bounce 0,15). Bei 40 % des Rings gehen die Zipfel in ihre Endlage auf (260 ms, Kurve `AppBewegung.bewegung`: langsam, schnell, sanft auslaufend). |
| Tuch unter dem Ring | W2 sanft | Die Bänder ziehen sich kaum ein und gehen fließend in die etwas schmaler ansetzenden Zipfel über. Ohne Ring bleibt keine Lücke und kein Block. |
| Natives Startbild | N1 Verlauf | Verlauf in der Primärfarbe wie bei der App-Sperre, die Person ohne Halstuch mittig. Flutter übernimmt pixelgleich. |
| Paket | immer Standard | Die Bühne zeigt immer die Standardfläche, auch mit Supporter-Paket. Es gibt keine Überblendung zur Palette, weil das native Bild unter iOS beim Build festliegt. |
| Abgang | A1 Gleiten | Die Fläche hebt sich um 40 pt und blendet aus (300 ms, `AppBewegung.blatt`); der Inhalt kommt mit Scale 0,98 → 1 und Fade. |
| Checkliste bei der Erstanmeldung | L1 auf der Fläche | Nach dem Login kommt die Fläche zurück; unter der Person steht die bestehende Checkliste auf Glas. Haken erscheinen mit Scale 0,8 → 1 und Fade (200 ms). Danach folgt der Abgang. |
| Kaltstart mit App-Sperre | E1 erst Glas | Die Sperre ist dieselbe Fläche, beim Kaltstart in Standard. Nach dem Entsperren blenden Glas und Knopf in 150 ms aus, dann geht die Fläche wie beim Start. |

Zusätzliche Vorgaben aus den Kommentaren:

- Bei Rückkehr aus dem Hintergrund spielt nichts ab. Sperre und Sichtschutz erscheinen sofort und zeigen dort weiter das Paket.
- Bei „Bewegung reduzieren“ gibt es nur eine Überblendung von 200 ms.
- Der Demo-/Live-Wechsel zeigt die Startfläche statt Weiß.
- Keine Schleife und kein Pulsieren während des Wartens.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Bewegung | B2 Tücher nacheinander, B3 nur ruhiger Abgang | nicht gewählt |
| Natives Startbild | N2 App-Hintergrund | nicht gewählt |
| Abgang | A2 Vorhang nach oben, A3 nur überblenden | nicht gewählt |
| Checkliste | L2 in der Shell | nicht gewählt |
| Entsperren | E2 alles zusammen | nicht gewählt |
| Paket | Überblendung vom Standard zum Paket | Der harte Wechsel gefiel nicht |
| Motiv | App-Icon in 92, 128 oder 160 pt | Eine Einzelperson wie im Logo wirkt groß besser |
| Knoten | K2 Knoten binden, K3 Zeile für Zeile | nicht gewählt |
| Farbe | P2 Hellblau | nicht gewählt |
| Tempo | T2 deutlich, etwa 0,9 s | nicht gewählt |
| Tuch unter dem Ring | W1 gerafft | nicht gewählt |
| Zipfel | Start bei 50 % des Rings, Ease-in mit hartem Halt | zu spät bzw. nicht gewählt |

## Android-12-Splash

- Ab Android 12 zeigt der System-Splash die Person ohne Halstuch auf der mittleren Verlaufsfarbe (`windowSplashScreenAnimatedIcon`, `windowSplashScreenBackground`). Das Icon ist fest gesetzt, ein aktiver Icon-Alias scheint deshalb nicht durch.
