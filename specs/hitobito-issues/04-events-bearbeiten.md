# JSON:API: Events und Kurse anlegen, bearbeiten und löschen

Entwurf, noch nicht eingereicht. Baut auf hitobito#4563 auf (`event_questions`).

## Ausgangslage

`/api/events` lässt sich nur lesen. Wer Events außerhalb der Weboberfläche plant, muss sie in hitobito von Hand anlegen: Apps, Jahresplanungs-Tools, Importe aus anderen Systemen. Die Weboberfläche kann Events anlegen, bearbeiten und löschen, mit Terminen sowie Anmelde- und Admin-Fragen im selben Formular (`EventsController`, `accepts_nested_attributes_for :dates, :application_questions, :admin_questions`).

User Story: Als Stammes- oder Bezirksleitung lege ich in einer App eine Veranstaltung mit Terminen, Ort, Kosten und Anmeldefenster an. Ich bearbeite sie später und lösche sie bei Bedarf wieder. Als Bildungsreferent lege ich Kurse einer Kursart an.

## Anforderungen

Grundsatz: gleicher Funktionsumfang und gleiche Rechte wie im UI oder weniger, über dieselben Validierungen und Callbacks.

1. **Anlegen** mit `POST /api/events`
   - Rechte wie im UI: `create` aus `EventAbility` in der Gruppe (Gruppen- bzw. Ebenenrechte).
   - Erlaubte Typen wie im UI: nur `event_types` der Gruppe (`assert_type_is_allowed_for_groups`).
   - Fragen-Vorlagen wie beim Formular (`Event#init_questions`).
2. **Bearbeiten** mit `PATCH /api/events/:id`
   - Rechte wie im UI: `update`, also `event_full` im Event (`for_leaded_events`) sowie Gruppen- bzw. Ebenenrechte.
3. **Löschen** mit `DELETE /api/events/:id`
   - Rechte wie im UI: `destroy` (Gruppen- bzw. Ebenenrechte).
4. **Felder:** nur die Felder des Formulars für den jeweiligen Typ, also `used_attributes` und die Rückgabe von `EventsController.permitted_attrs`. Was das Formular nicht anbietet, bleibt nicht schreibbar.
5. **Termine** und **Fragen** wie im Formular als Sideposts: `dates` (`label`, `location`, `start_at`, `finish_at`) sowie `application_questions` und `admin_questions` (`question`, `choices`, `multiple_choices`, `required`).

Nicht gefordert: Tags, Anhänge, Kursarten und Kategorien verwalten, Absagegründe sowie Wagon-Zustände (`state`). Die Zustände können Wagons ergänzen.

## Vorgeschlagene Endpunkte

| Methode | Pfad | Zweck | Recht wie im UI |
|---|---|---|---|
| POST | `/api/events` (Sideposts `dates`, `application_questions`, `admin_questions`) | anlegen | `create` in der Gruppe |
| PATCH | `/api/events/:id` | bearbeiten, Termine und Fragen per Sidepost | `update` |
| DELETE | `/api/events/:id` | löschen | `destroy` |

Beispiel:

```http
POST /api/events
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "events",
    "attributes": {
      "type": "Event::Course",
      "group_ids": [11],
      "kind_id": 1,
      "name": "Gruppenleitungskurs Herbst",
      "location": "Jugendhaus",
      "maximum_participants": 12,
      "application_opening_at": "2026-09-01",
      "application_closing_at": "2026-10-15",
      "applications_cancelable": true
    },
    "relationships": {
      "dates": { "data": [ { "type": "event_dates", "temp-id": "d1", "method": "create" } ] }
    }
  },
  "included": [
    { "type": "event_dates", "temp-id": "d1",
      "attributes": { "label": "Wochenende", "start_at": "2026-11-14T18:00:00+01:00", "finish_at": "2026-11-16T14:00:00+01:00" } }
  ]
}
```

Antworten:
- **201** bzw. **200:** mit Event und Terminen.
- **422:** mit den Validierungsfehlern des Models, z. B. kein Termin, Anmeldeschluss vor Beginn, Typ für die Gruppe nicht erlaubt.
- **403:** ohne Recht.

## Abgrenzungen

- Teilnehmende und Leitungen verwalten ist ein eigenes Issue (Rollen, Bewerbungsmarkt).
- Siehe „Nicht gefordert“ oben.

## Offene Fragen

- Termine und Fragen nur als Sideposts, oder zusätzlich als eigene Ressourcen?
- Wie ergänzen Wagons ihre eigenen Event-Felder: über die Resource, wie bei anderen Ressourcen üblich?
- Welcher Scope gilt: `events` mit Schreibrecht oder ein eigener?

## Tech-Spec

- **Ressource:** Umsetzung im Core. `EventResource` bzw. `Event::CourseResource` mit `primary_endpoint` `:create`, `:update`, `:destroy`.
- **Schreibbare Attribute:** wie `EventsController.permitted_attrs` und `used_attributes` des Typs.
- **Autorisierung:** über `EventAbility`. `authorize_create` prüft die Gruppen aus `group_ids` analog `RoleResource#authorize_create`.
- **Sideposts:** `Event::DateResource` und `Event::QuestionResource` (aus hitobito#4563) schreibbar.
- **Model:** Validierungen und Callbacks bleiben maßgeblich, z. B. `validates :dates`, `assert_application_closing_is_after_opening`, `prefill_shared_access_token`.
- **Doku:** OpenAPI und `json_api.md` ergänzen.

## ToDo

- [ ] Schreibpfade für `events` mit Typprüfung und den Feldern des Formulars
- [ ] Termine und Fragen schreibbar (Sideposts), Fragen-Vorlagen beim Anlegen
- [ ] Autorisierung, Scopes
- [ ] Specs (Event, Kurs, Wagon-Typen, Rechte, Validierungsfehler)
- [ ] Graphiti-Schema aktualisieren, Wagons durchtesten
- [ ] Mit angemessener Rolle "durchklicken" bzw. "durch-querien"
- [ ] DoD geprüft und erfüllt?
- [ ] CHANGELOG-Eintrag unter "unreleased"
- [ ] https://hitobito.readthedocs.io anpassen
