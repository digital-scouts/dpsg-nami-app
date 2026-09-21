---
layout: page
title: Wiredash und Tracking
permalink: /wiredash/
---

## Überblick

Diese Seite listet die aktuell in der App vorhandenen Tracking-Ereignisse auf, die über Wiredash gesendet werden können.

Die Ereignisse werden nur weitergegeben, wenn Analytics in der App aktiviert sind. Unabhängig davon schreibt die App lokale Logs für denselben Ablauf.

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
- Der Wert `remote_deleted_local_edited` ist bereits als Tracking-Ursache vorbereitet, aber aktuell noch nicht im Produktionsablauf belegt.
- Hinweise aus Einstellungen und Detailansicht öffnen den Fall, erzeugen aber keinen eigenen separaten Hint-Event; der explizite Hint-Event wird derzeit für die Mitgliederliste verwendet.
