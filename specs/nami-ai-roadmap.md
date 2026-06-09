# NaMi AI Roadmap

Status: Entwurf für ersten Test und MVP
Datum: 2026-06-08
Kontext: NaMi App, Apple Foundation, iOS 27, Siri und App Intents

## 1) Ziel und Scope

### Zielbild
- NaMi AI bietet in der App und per Siri einen schnellen, sicheren und nachvollziehbaren Zugang zu Wissen und Funktionen rund um DPSG-Kontext, App-Bedienung, Mitgliedsdaten und Statistik.
- Die erste Ausbaustufe fokussiert auf hohe Nutzbarkeit bei klar begrenztem Risiko.

### Produktziele
- Weniger Zeit für wiederkehrende Fragen und einfache Datenabfragen.
- Bessere Selbsthilfe für Leitende und Vorstände.
- Sichere, protokollierte Ausführung von Aktionen mit Rollen- und Rechteprüfung.

### Scope in dieser Spec
- Technischer Zuschnitt für einen ersten Test.
- Roadmap bis MVP.
- MVP-Funktionskatalog mit Priorisierung Muss, Soll, Kann, Später.
- Gate-Regeln für kontrollierte Aktivierung.

### Out of Scope
- Vollständige Automatisierung aller Verwaltungsprozesse.
- Freie, unkontrollierte Tool-Ausführung ohne Benutzerkontext.
- Plattformübergreifende Implementierung außerhalb iOS in dieser Phase.

## 2) Systembereiche

### Überblick
Die Lösung wird in acht Systembereiche getrennt, um Verantwortlichkeiten sauber zu halten.

### 2.1 Chat UI
- In-App Chat mit Konversationsverlauf, Quellenhinweisen und klaren Handlungsbuttons.
- Sichtbare Zustände: arbeitet, Rückfrage nötig, Ergebnis, nicht zulässig.
- Antwortformatierung für kurze Entscheidungen und klare nächste Schritte.

### 2.2 Siri und App Intents
- Intent-Einstieg für häufige Aufgaben und Fragen.
- Übergabe von Nutzerkontext, Rollenhinweis und aktiver Organisationseinheit.
- Definierte Intent-Antworttypen: Info, Aktion bestätigt, Aktion blockiert.

### 2.3 Apple Foundation Schnittstelle
- Nutzung von Apple Foundation für Sprachverstehen, Zusammenfassung und Textgenerierung.
- Strikte Trennung zwischen Inhaltsgenerierung und fachlicher Ausführung.
- Wichtig: Apple Foundation kann Inhalte generieren, Dateierstellung und Export muss die App implementieren.

### 2.4 Document Pipeline
- Ingestion und Aufbereitung von DPSG-Dokumenten, Ordnung, Satzung, Hilfetexten.
- Versionierung und Gültigkeitsmarken für Quellen.
- Retrieval mit Zitierpflicht für normative Aussagen.

### 2.5 Orchestrator und Tools
- Orchestrator steuert Dialogfluss, Tool-Auswahl und Reihenfolge.
- Tools kapseln App-Funktionen und Server-Endpunkte mit festen Verträgen.
- Rückfragen bei Mehrdeutigkeit vor schreibenden Aktionen.

### 2.6 Gates
- Plattform-Gate: nur iOS aktiv.
- Geräte-Gate: nur unterstützte Apple-Geräte mit Apple Foundation Laufzeit.
- Versions-Gate: Mindestversion iOS 27.
- Env-Gate: Feature-Flag NAMI_AI_ENABLED standardmäßig false.
- Rollout-Gate: schrittweise Freigabe pro Nutzergruppe oder Verband.
- Monetarisierungs-Gate: optionale Paywall für Premium-Funktionen.

### 2.7 Safety und Audit
- Rollen- und Rechteprüfung vor jedem Datenzugriff und jeder Änderung.
- Policy-Prüfung für sensible Anfragen und potenziell unzulässige Auskünfte.
- Audit-Log für Prompt, Tool-Aufrufe, Ergebnisstatus und Begründungen.
- Nachvollziehbare Fehlermeldungen ohne Offenlegung sensibler Details.

### 2.8 Qualität und Betrieb
- Qualitätsmetriken: Antwortqualität, Erfolgsquote, Fehlerrate, Abbruchrate.
- Betrieb: Telemetrie, Alarmierung, Fallback-Verhalten bei Tool-Fehlern.
- Teststrategie: Intent-Tests, Integrations-Tests, Sicherheits- und Rollen-Tests.

## 3) Roadmap Erster Test

### Meilenstein T1: Architektur- und Gate-Basis
- Chat UI als interner Testscreen aktivierbar.
- App Intent für einen sicheren Lese-Use-Case.
- Gates umgesetzt: Plattform, Gerät, Mindest-iOS, Env-Flag default false.
- Minimales Audit-Logging für jede Anfrage.

### Meilenstein T2: Wissensfragen mit Quellen
- Document Pipeline für DPSG-Ordnung und Satzung in erster Version.
- Retrieval mit Quellennachweis und Datumsstand.
- Sicherheitsregel: keine schreibenden Aktionen im ersten Test.

### Meilenstein T3: Erste App- und Mitgliedsabfragen
- Lesender Zugriff auf Basis-Mitgliedsinfos mit Rechteprüfung.
- Einfache App-Fragen und Bedienhinweise über denselben Orchestrator.
- Definierte Fehlerbilder und Nutzerhinweise bei fehlenden Rechten.

### Meilenstein T4: Auswertung und Go oder No-Go
- Test mit begrenzter Pilotgruppe.
- Messung der Qualitätsziele und Auswertung von Audit-Logs.
- Entscheidung über Übergang in MVP-Umsetzung.

## 4) Roadmap MVP

### Meilenstein M1: Stabile Kernplattform
- Robuster Orchestrator mit standardisierten Tool-Verträgen.
- Erweiterte Siri und App Intents für häufige Leseaufgaben.
- Vollständige Gate- und Rollout-Steuerung pro Zielgruppe.

### Meilenstein M2: Fachwissen und App-Hilfe produktiv
- Abdeckung DPSG, Ordnung, Satzung und App-Hilfe mit Quellenpflicht.
- Qualitätskontrollen für Halluzinationsreduktion und Antwortkonsistenz.
- Redaktioneller Pflegeprozess für Dokumentaktualisierungen.

### Meilenstein M3: Sichere Basis-Aktionen
- Lesen und Bearbeiten von Basis-Mitgliedsinfos mit starker Rechteprüfung.
- Explizite Nutzerbestätigung vor schreibenden Änderungen.
- Auditierbare Änderungsprotokolle mit Vorher-Nachher-Bezug.

### Meilenstein M4: Statistik und komplexe Anfragen
- Basis-Statistikfragen mit belastbaren Zahlen und Filtertransparenz.
- Mehrschritt-Orchestrierung für komplexe Multi-Mitgliedsanfragen.
- Serverseitige Job-Ausführung für lange Berechnungen.

### Meilenstein M5: Export und Betriebsreife
- Exporterstellung in der App als eigener Export-Service.
- Klarer Hinweis im UX-Text: Generierte Inhalte sind nicht automatisch Dateien.
- Optionaler Paywall-Rollout für erweiterte Funktionen.

## 5) MVP-Funktionskatalog

### Prioritätslegende
- Muss: zwingend für MVP.
- Soll: hoher Nutzen, nach Kernfunktionen.
- Kann: sinnvoll, wenn Kapazität vorhanden ist.
- Später: nach MVP oder in Folgeversion.

| Funktion | Priorität | Kurzbeschreibung | Gates und Bedingungen |
|---|---|---|---|
| DPSG, Ordnung, Satzung Fragen | Muss | Verlässliche Antworten mit Quellen und Versionsstand | Nur lesend, Quellenpflicht, Audit aktiv |
| App-Fragen | Muss | Hilfe zu Navigation, Bedienung, Einstellungen | In-App und Siri, keine sensiblen Daten ohne Rechte |
| Rechte-Grundlagen | Muss | Erklärt, welche Rolle welche Aktion darf | Rollenmodell als harte Prüfgrundlage |
| Basis-Mitgliedsinfos lesen | Muss | Stammdaten lesend abrufen, kontextgebunden | Rechteprüfung je Feld, Protokollierung |
| Basis-Mitgliedsinfos bearbeiten | Soll | Kernfelder gezielt ändern mit Bestätigung | Doppelte Bestätigung, Audit Vorher und Nachher |
| Basis-Statistikfragen | Muss | Standardzahlen zu Mitgliedern und Strukturen | Transparente Filter und Stichtag |
| Komplexe Multi-Mitgliedsanfragen, z. B. 1 km | Soll | Kombinierte Filter über mehrere Mitglieder und Kontext | Asynchroner Job bei Laufzeitrisiko |
| Komplexe Statistikkombinationen ohne bestehende Schnittstelle | Kann | Orchestrierte Berechnung aus mehreren Quellen | Zusätzliche Validierung und Ergebniswarnung |
| Export erstellen | Soll | Erzeugt Datei-Ausgabe aus Ergebnissen in App-Exportservice | Apple Foundation generiert Inhalte, Datei und Export macht die App |
| Und mehr: kontextsensitive Rückfragen | Soll | KI stellt Rückfragen bei Unklarheit statt falscher Aktion | Pflicht bei Mehrdeutigkeit |
| Und mehr: Favoriten und Schnellaktionen | Kann | Wiederkehrende Anfragen als Vorlagen speichern | Optional je Rolle |
| Und mehr: Teamweite Vorlagen | Später | Freigabefähige Prompt und Intent Vorlagen | Governance und Freigabeprozess nötig |

### Nicht-funktionale MVP-Kriterien
- Antwortzeit für Standardfragen im Zielbereich produktiv nutzbar.
- Fehlerfälle führen zu sicheren, klaren und hilfreichen Rückmeldungen.
- Alle schreibenden Aktionen sind durch Rechte, Bestätigung und Audit abgesichert.

## 6) Offene Fragen und Entscheidungen

- Welche Mindestgeräteklassen gelten verbindlich für Apple Foundation im Feld?
- Welche Rollen dürfen schreibende Mitgliedsänderungen via KI auslösen?
- Welche Datenfelder sind für Basis-Mitgliedsinfos im MVP enthalten?
- Wie wird die optionale Paywall funktional und rechtlich abgegrenzt?
- Welche Exportformate sind Pflicht zum MVP, welche folgen später?
- Welche Schwellenwerte entscheiden Go oder No-Go nach dem ersten Test?
- Wie wird bei widersprüchlichen Quellen priorisiert und kommuniziert?

## Entscheidungsbedarf bis Start Umsetzung

- Produktentscheidung zu Pilotgruppe, Rollout-Reihenfolge und optionaler Paywall.
- Technikentscheidung zu Tool-Verträgen, Audit-Schema und Exportservice.
- Fachentscheidung zu zulässigen Schreibaktionen und Freigabeprozess.

## Kurzfazit

- Der erste Test validiert kontrolliert den Nutzen bei minimalem Risiko.
- Der MVP baut darauf auf und erweitert gezielt um sichere Aktionen, Statistik und Export.
- Gates bleiben durchgängig aktiv, mit Env-Flag default false als zentrale Sicherheitslinie.
