---
title: Wiredash und Tracking
parent: Technik
nav_order: 5
permalink: /technik/wiredash/
redirect_from:
  - /wiredash/
---

# Wiredash und Tracking
{: .no_toc }

## Überblick

Diese Seite listet die aktuell in der App vorhandenen Tracking-Ereignisse auf, die über Wiredash gesendet werden können.

Die Ereignisse werden nur gesendet, wenn die Nutzungsanalyse eingeschaltet ist. Die Vorgabe ist aus; einschalten lässt sie sich im Willkommensdialog nach dem ersten Login und in den Einstellungen. Das gilt auch im Demo-Modus. Unabhängig davon schreibt die App lokale Logs für denselben Ablauf.

Ebenfalls unabhängig vom Schalter sendet das Wiredash-SDK bei jedem Start, höchstens alle 30 Minuten, einen technischen Ping mit zufälliger Installationskennung, App-Version, Bundle-ID, Betriebssystem und Sprache. Er enthält keine Ereignisse und keine Inhalte.

## Alle Ereignisse

| Ereignis | Anlass | Eigenschaften (Auswahl) |
|---|---|---|
| `auth_flow` | Anmelden, Abmelden, Token-Erneuerung | `action`, `outcome` |
| `layer_switch` | Wechsel des Arbeitskontexts | `outcome`, Layer-IDs und -Namen |
| `settings_changed` | geänderte Einstellung (30 s entprellt) | `setting`, neuer Wert |
| `runtime_error` | unerwarteter Fehler | `source`, `error_type`, `exception`, `stack` (je auf 900 Zeichen gekürzt) |
| `member_edit` | Bearbeiten, Speichern, erneutes Senden | siehe unten |
| `member_resolution_*` | Problemlösungsfälle | siehe unten |
| `feedback_prompt`, `promoter_survey` | Feedback-Dialog und Umfrage | siehe unten |
| `feedback`, `debug_tools`, `debug_action` | Aktionen in Hilfe & Diagnose und den Entwickler-Werkzeugen | `action` |
| `demo_used` | Start des Demo-Modus | keine |

## Grundprinzip

Die App verwendet zwei fachliche Tracking-Bereiche:

- `member_edit` für allgemeine Bearbeiten-, Submit- und Retry-Abläufe
- eigene `member_resolution_*`-Ereignisse für Problemlösungsfälle

Für Problemlösungsfälle unterscheidet die App zusätzlich:

- `resolution_category`
  - `merge_conflict`
  - `non_merge_problem`
  - `mixed`
- `resolution_causes`
  - `overlapping_change`
  - `server_validation`
  - `address_validation`
  - `remote_deleted_local_edited`
  - `unknown`

Damit lässt sich später getrennt auswerten, wie oft echte Merge-Konflikte und wie oft andere nicht automatisch lösbare Fälle auftreten.

## Feedback-Dialog und Promoter Score

Neben dem Tracking nutzt die App Wiredash für Feedback und den Promoter Score. Beides ist unabhängig vom Analytics-Schalter, weil es sich um sichtbare, freiwillige Interaktionen handelt. Pro App-Start erscheint höchstens einer der beiden Dialoge, und nur wenn beim Start kein Welcome- oder Update-Dialog angezeigt wurde.

### Feedback-Dialog

- erscheint frühestens 7 Tage nach der ersten Nutzung (erster angemeldeter Start), einige Sekunden nach dem Start
- iOS: bietet nur „Feedback geben“ (öffnet Wiredash-Feedback) und „Später“; Apple erlaubt aktive Bewertungsaufforderungen nur über den Systemdialog
- Android: bietet gestapelt „App bewerten“ (öffnet das In-App-Review von Google Play, sonst den Store-Eintrag), „Feedback geben“ und „Später“; für die Bewertung gibt es kein Abzeichen
- „Später“ oder Schließen verschiebt den Dialog um 14 Tage; insgesamt erscheint er höchstens zweimal
- nach „Feedback geben“ oder „App bewerten“ erscheint er nicht mehr

### Bewertung auf iOS

- nach dem ersten manuellen Speichern einer Person fragt die App einmalig den Systemdialog an (`requestReview`), nicht im Demo-Modus und nicht im selben App-Start wie der Feedback-Dialog; ob er erscheint, entscheidet iOS
- auf der Erfolge-Seite öffnet das offene Abzeichen „App bewertet“ die Bewertungsseite im App Store; das Abzeichen gilt danach als erreicht
- „Mitgestalten“ ist auf beiden Plattformen antippbar und öffnet das Feedback
- der Zustand liegt in SharedPreferences unter `feedback_prompt.*` und wird beim App-Reset gelöscht
- in den Entwickler-Werkzeugen (nur Debug- und Profile-Builds) lässt sich der Dialog ohne Speicherung des Zustands erzwingen

### Promoter Score

- wird über `Wiredash.of(context).showPromoterSurvey()` angefragt, wenn der Feedback-Dialog nicht dran ist
- Wiredash entscheidet anhand von `PsOptions`: erstmals nach 21 Tagen und mindestens 3 App-Starts, danach alle 90 Tage
- die 21 Tage sind bewusst länger als die 7 Tage des Feedback-Dialogs, damit beide nicht in dieselbe Woche fallen

### feedback_prompt

Typische Eigenschaften:

- `action`: `shown`, `feedback`, `rate`, `later`
- `trigger`: `startup` oder `debug`

### promoter_survey

Typische Eigenschaften:

- `action`: `shown`
- `trigger`: `startup`

## Konvention für neue Ereignisse

Damit sich Ereignisse später zu Funnels verbinden lassen, gilt für neue Ereignisse:

- ein Ereignisname pro fachlichem Ablauf, z. B. `member_edit` oder `feedback_prompt`
- der Schritt steht in `action`, das Ergebnis in `outcome`
- Werte von `action`, `outcome` und `trigger` bleiben stabil und werden nicht umbenannt
- höchstens 10 Eigenschaften pro Ereignis; Werte sind primitive Typen und höchstens 1024 Zeichen lang, sonst verwirft Wiredash sie
- Ereignisnamen sind 3 bis 64 Zeichen lang, beginnen mit einem Buchstaben und nutzen `snake_case`

Wiredash wertet Ereignisse aggregiert aus. Für echte Funnels pro Nutzer wäre später ein anderes Ziel am zentralen Event-Hook im `LoggerService` nötig.

## Allgemeine Bearbeiten-Ereignisse

### member_edit

Dieses Ereignis wird für den allgemeinen Bearbeiten- und Submit-Ablauf verwendet.

Typische `action`-Werte sind:

- `prepare_started`
- `prepare_result`
- `prepare_notice`
- `submit_started`
- `submit_result`
- `retry_started`
- `retry_result`

Typische Eigenschaften:

- `action`
- `trigger`
- `outcome`
- `source`
- optional `batch_size`
- optional `success_count`
- optional `retained_count`
- optional `discarded_count`
- optional `needs_resolution_count`

Beispiele für `trigger`:

- `detail_edit`
- `manual_edit`
- `manual_resolution`
- `manual_retry`

## Problemlösungsfälle

### member_resolution_created

Dieses Ereignis entsteht, wenn ein gespeicherter Queue-Eintrag in einen Problemlösungsfall wechselt oder wenn ein Konflikt direkt beim manuellen Speichern erkannt wird.

Typische Eigenschaften:

- `trigger`
- `outcome`
- `resolution_source`
- `resolution_category`
- `resolution_causes`
- `item_count`
- `conflict_count`
- `validation_count`
- `non_merge_count`
- `address_validation_count`
- `server_validation_count`
- `target_types`

Typische `outcome`-Werte:

- `needs_resolution`
- `validation_needs_resolution`

### member_resolution_opened

Dieses Ereignis entsteht, wenn ein vorhandener Problemlösungsfall geöffnet wird.

Typische Eigenschaften:

- `entry_point`
- `resolution_source`
- `resolution_category`
- `resolution_causes`
- `item_count`
- `target_types`

Aktuelle `entry_point`-Werte:

- `detail`
- `settings`
- `submit_result`
- `unknown`

### member_resolution_choice

Dieses Ereignis entsteht bei einer expliziten Nutzerentscheidung innerhalb des Problemlösungs-Screens.

Typische Eigenschaften:

- `choice`
- `target_type`
- `item_cause`
- `item_problem_type`
- `resolution_source`
- `resolution_category`
- `resolution_causes`

Aktuelle `choice`-Werte:

- `keep_local`
- `use_server`
- `discard_local`

### member_resolution_hint_shown

Dieses Ereignis entsteht, wenn die App einen allgemeinen Hinweis auf offene Problemlösungsfälle zeigt.

Typische Eigenschaften:

- `entry_point`
- `open_resolution_count`

Aktuell wird dieses Ereignis für die Snackbar in der Mitgliederliste verwendet.

### member_resolution_resend_started

Dieses Ereignis entsteht, wenn ein bestehender Problemlösungsfall erneut gesendet wird.

Typische Eigenschaften:

- `trigger`
- `resolution_source`
- `resolution_category`
- `resolution_causes`
- `item_count`

### member_resolution_resend_result

Dieses Ereignis beschreibt das Ergebnis eines erneuten Sendeversuchs aus einem Problemlösungsfall heraus.

Typische Eigenschaften:

- `trigger`
- `outcome`
- `remaining_item_count`
- `resolution_source`
- `resolution_category`
- `resolution_causes`
- `item_count`

Aktuelle `outcome`-Werte:

- `success`
- `still_open`
- `validation_failed`
- `queued_network_blocked`
- `queued`

## Aktuelle fachliche Bedeutung

- `merge_conflict` steht für echte Überschneidungen auf derselben Änderungseinheit.
- `non_merge_problem` steht für nicht automatisch lösbare Fälle ohne Feldüberschneidung, aktuell vor allem Retry-Validierungsfehler.
- `mixed` steht für Fälle, in denen beide Arten gleichzeitig in einem Mitglied vorkommen.

Die wichtigste Auswertungsfrage für Produktverbesserungen ist in der Regel:

- Wie oft entsteht ein Problemlösungsfall mit `resolution_category = non_merge_problem`?

Das sind genau die Fälle, in denen nicht ein echter Merge-Konflikt die Ursache ist, sondern die App oder der Ablauf an anderer Stelle verbessert werden kann.

## Aktuelle Grenzen

- Die separate Adressvalidierung ist fachlich vorgesehen, aber noch nicht an den Problemlösungsablauf angeschlossen.
- Der Wert `remote_deleted_local_edited` wird vergeben, wenn ein lokal bearbeitetes Mitglied auf dem Server gelöscht wurde.
- Hinweise aus Einstellungen und Detailansicht öffnen den Fall, erzeugen aber keinen eigenen separaten Hint-Event; der explizite Hint-Event wird derzeit für die Mitgliederliste verwendet.
