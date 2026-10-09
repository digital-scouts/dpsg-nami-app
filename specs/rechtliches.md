# Lizenzen und Fremdmaterial

Stand: 2026-10-09. Die Abgrenzung für Außenstehende steht in `NOTICE`. Hier steht die Bewertung dahinter und was noch zu tun ist. Organisatorisches mit der DPSG läuft in #243.

## Projektlizenz

`LICENSE` ist CC BY-NC-SA 4.0 und bleibt unverändert, der Lizenztext darf nicht angepasst werden. Sie gilt nur für eigenes Material. Ausgenommen sind DPSG-Zeichen, Satzungstexte, Geodaten, Schriften und Abhängigkeiten (Liste in `NOTICE`).

## Abhängigkeiten

Die Lizenzen der pub-Pakete zeigt `showLicensePage` (`settings_rechtliches_page.dart`), die Schriften registriert `lib/presentation/theme/schrift_lizenzen.dart`. Auffällig sind zwei Pakete:

| Paket | Lizenz | Nutzung | Bewertung |
|---|---|---|---|
| `flutter_map_tile_caching` (FMTC) | GPL-3.0 | nur `lib/services/map_tile_cache_service.dart` (Offline-Kacheln) | GPL verlangt für die ausgelieferte App die Weitergabe unter GPL-Bedingungen. Das verträgt sich nicht mit dem NC-Zusatz der Projektlizenz und schlecht mit der Verteilung über die Stores. Empfehlung: durch einen eigenen Kachel-Cache ersetzen oder beim Autor eine kommerzielle Lizenz anfragen (A-62). |
| `syncfusion_flutter_core`, `syncfusion_flutter_sliders` | Syncfusion Community License | nur der Bereichsregler in `settings_stufenwechsel.dart` | Kostenlos nur unter den Bedingungen der Community License (Umsatz- und Personengrenzen). Mit den Supporter-Käufen ist das zu prüfen. Empfehlung: durch Materials `RangeSlider` ersetzen. |

`fl_chart` war ungenutzt und ist entfernt.

## Exportdeklaration (iOS)

`ios/Runner/Info.plist` setzt `ITSAppUsesNonExemptEncryption=false`. Die App nutzt HTTPS über das Betriebssystem und verschlüsselt die lokalen Hive-Boxen mit AES aus der Dart-Bibliothek (nicht vom Betriebssystem). Verschlüsselung nur zum Schutz eigener Daten auf dem Gerät gilt nach den Apple-Vorgaben in der Regel als ausgenommen. Die Einordnung ist in #243 zu bestätigen. Fällt sie anders aus, ist der Wert auf `true` zu setzen und die Exportangabe in App Store Connect zu ergänzen.

## Offen

- FMTC ersetzen oder lizenzieren (#245).
- Syncfusion-Regler ersetzen (#246, sichtbar, vorher `feedbackrunde`).
- DPSG-Zeichen, Satzungstexte, Stammessuche und Diözesangrenzen: Erlaubnis und Quelle (#243).
