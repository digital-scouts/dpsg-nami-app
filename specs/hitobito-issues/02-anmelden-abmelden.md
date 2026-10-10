# JSON:API: An Events und Kursen anmelden und abmelden

Entwurf, noch nicht eingereicht. Baut auf hitobito#4563 auf.

## Ausgangslage

Die JSON:API bietet für Teilnahmen nur `index` und `show`. Ein API-Client kann eine Person weder anmelden noch abmelden. Die alte JSON-API kann es auch nicht, und Schreiben über die Web-Controller scheitert am CSRF-Schutz. Apps müssen für jede Anmeldung in den Browser wechseln, wo sich die Person erneut einloggen muss.

Die Weboberfläche hat den ganzen Ablauf bereits:
1. Kontaktdaten prüfen und Datenschutzerklärung bestätigen (`Event::ParticipationContactDatasController`).
2. Formular mit Anmeldefragen, Zusatzinfos und Prioritäten (`Event::ParticipationsController#new` und `#create`).
3. Bestätigungsmail.

Abmelden geht über `Event::ParticipationsController#destroy`, eine Einladung ablehnen über `Event::Invitations::DeclineController`. Rechte und Abläufe sind also geklärt.

User Story: Als Mitglied melde ich mich in einer App an einem Kurs an. Ich beantworte die Anmeldefragen, wähle wie im Web optional Ausweichkurse und erhalte dieselbe Bestätigungsmail. Ist Abmelden erlaubt, melde ich mich in der App wieder ab. Eltern melden betreute Kinder an und ab.

## Anforderungen

Grundsatz: gleicher Funktionsumfang und gleiche Rechte wie im UI oder weniger, über dieselbe Logik.

1. **Anmelden** mit `POST /api/event_participations`, für sich selbst oder eine betreute Person
   - Rechte wie im UI: `her_own_if_application_possible` mit `for_self_or_manageds` in `Event::ParticipationAbility`.
   - Felder wie im Formular:
     - `additional_information`
     - Antworten auf die Anmeldefragen; Pflichtfragen sind Pflicht wie bei `enforce_required_answers`
     - Prioritäten 2 und 3, nur wenn das Event `priorization` nutzt und nur aus der Auswahl von `load_priorities`
     - die Rolle, nur aus den Typen, die `Dropdown::Event::ParticipantAdd` der Person anbietet (Teilnehmenden-Typen bzw. der Typ der Einladung)
   - Wirkung wie im Web:
     - einfaches Event: sofort aktiv
     - Kurs: Bewerbung (`active: false`), bei `automatic_assignment` und freien Plätzen direkt ein Platz
     - ausgebucht mit Warteliste: direkt auf die Warteliste
     - `Event::ParticipationConfirmationJob` und `Event::ParticipationNotificationJob`
   - Kontaktdaten-Schritt:
     - Fehlen Pflichtangaben aus `required_contact_attrs`, kommt 422 mit der Liste der Felder. Die Person ergänzt sie über das bestehende `PATCH /api/people/:id` (eigene Daten) und meldet sich dann an.
     - Die Zustimmung zur Datenschutzerklärung kommt wie im Web-Schritt als `privacy_policy_accepted: true` mit (vgl. Self-Registration #3440).
   - Hinweise des `PreconditionChecker` (Mindestalter, Qualifikationen) kommen wie im Web als Warnung in `meta`, nicht als Sperre.

2. **Abmelden** mit `DELETE /api/event_participations/:id`
   - Rechte wie im UI: `her_own_if_application_cancelable` mit `for_self_or_manageds`. Das ist derselbe Wert wie `cancelable` aus #4563.
   - Wirkung wie im Web: Teilnahme und Bewerbung werden gelöscht, `Event::CancelApplicationJob` läuft.

3. **Einladung ablehnen**
   - Die eigene offene Einladung zu einem Event lesen, wie das Banner auf der Eventseite: `GET /api/event_invitations?filter[event_id]=…` liefert für Teilnehmende nur eigene und betreute Einladungen.
   - Ablehnen mit `PATCH /api/event_invitations/:id`, Attribut `declined: true`. Rechte wie im UI: `decline` / `own_invitation`, auch für betreute Personen.
   - Angenommen wird eine Einladung wie im UI über die Anmeldung mit der eingeladenen Rolle (Punkt 1).

Nicht gefordert, weil das UI es Teilnehmenden nicht erlaubt: die eigene Anmeldung nachträglich bearbeiten. `update` haben nur `participations_full` und Gruppen- oder Ebenenrechte.

## Vorgeschlagene Endpunkte

| Methode | Pfad | Zweck | Recht wie im UI |
|---|---|---|---|
| POST | `/api/event_participations` (Sideposts `answers`, `application`) | anmelden | `create`: `her_own_if_application_possible`, `for_self_or_manageds` |
| DELETE | `/api/event_participations/:id` | abmelden | `destroy`: `her_own_if_application_cancelable`, `for_self_or_manageds` |
| GET | `/api/event_invitations?filter[event_id]=…` | eigene Einladung | Banner auf der Eventseite |
| PATCH | `/api/event_invitations/:id` (`declined: true`) | Einladung ablehnen | `decline`: `own_invitation` |

Beispiel: Anmeldung an einem Kurs.

```http
POST /api/event_participations
Content-Type: application/vnd.api+json
Authorization: Bearer <OAuth-Token mit Scope api oder event_participations>

{
  "data": {
    "type": "event_participations",
    "attributes": {
      "event_id": 5,
      "participant_id": 42,
      "participant_type": "Person",
      "additional_information": "Vegetarisch",
      "privacy_policy_accepted": true
    },
    "relationships": {
      "application": { "data": { "type": "event_applications", "temp-id": "a1", "method": "create" } },
      "answers": { "data": [ { "type": "event_answers", "temp-id": "q1", "method": "create" } ] }
    }
  },
  "included": [
    { "type": "event_applications", "temp-id": "a1", "attributes": { "priority_2_id": 8 } },
    { "type": "event_answers", "temp-id": "q1", "attributes": { "question_id": 31, "answer": "Ja" } }
  ]
}
```

Antworten:
- **201:** mit `active`, `application` (inklusive `waiting_list`) und `meta.warnings` für fehlende Voraussetzungen.
- **422:**
  - Pflichtfrage fehlt
  - Pflichtangaben fehlen (mit Feldliste)
  - Datenschutzerklärung nicht bestätigt
  - Anmeldung nicht möglich
  - bereits angemeldet
  - Unterschrift verlangt (siehe Abgrenzungen)
- **403:** keine Berechtigung für diese Person oder dieses Event.

## Abgrenzungen

- Lesende Ergänzungen sind hitobito#4563 und Voraussetzung.
- Aktionen der Veranstaltenden (Platz vergeben, freigeben, Rollen) und Events bearbeiten folgen getrennt.
- Externe Anmeldung ohne Konto (`Event::RegisterController`) und Gäste (`Event::Guest`) gehören nicht dazu.
- Unterschrift (`signature`, `signature_confirmation`): zunächst nicht unterstützt. Solche Events lehnen die Anmeldung per API mit 422 und Hinweis ab. Das ist bewusst weniger als im UI.

## Offene Fragen

- Darf `participant_id` fehlen, sodass die angemeldete Person gemeint ist?
- Ist der Kontaktdaten-Schritt als 422 mit Feldliste richtig? Oder sollen die Pflichtangaben gleich mitgeschickt werden können, wie im Web-Formular (`PeopleController.permitted_attrs`)?
- Gehört das Ablehnen von Einladungen in dieses Issue oder in ein eigenes?

## Tech-Spec

- **Domain-Service:** Umsetzung im Core. Die Logik aus `Event::ParticipationsController#create` wandert in einen Domain-Service (z. B. `Event::ParticipationCreator`), den Web und API gemeinsam nutzen. Der Service umfasst:
  - `init_answers`, `init_application`, `enforce_required_answers`, `set_active`
  - `ParticipantAssigner` bei `automatic_assignment`
  - beide Jobs
- **Abmelden:** analog über einen gemeinsamen Service mit `Event::CancelApplicationJob`.
- **Ressource:**
  - `Event::ParticipationResource`: `primary_endpoint` um `:create` und `:destroy` erweitern.
  - Schreibbar beim Anlegen: `event_id`, `participant_id`, `participant_type`, `additional_information`.
  - Sideposts `application` (`priority_2_id`, `priority_3_id`) und `answers` (`question_id`, `answer`). Weitere Attribute bleiben nicht schreibbar: `active`, `qualified`, `waiting_list`, `approved`.
- **Rollenwahl:** über dieselbe Auswahl wie `Dropdown::Event::ParticipantAdd.for_user`.
- **Autorisierung:**
  - über `Event::ParticipationAbility` bzw. `Event::InvitationAbility`
  - `authorize_create` analog `RoleResource#authorize_create`
- **Sicherheit:** Über Sideposts dürfen sich keine Status oder Rollen setzen lassen, die nur Veranstaltende vergeben (vgl. #3440).
- **Doku:** OpenAPI und `json_api.md` ergänzen.

## ToDo

- [ ] Domain-Service für Anmelden und Abmelden, Web-Controller darauf umstellen
- [ ] Resource-Schreibpfade inklusive Sideposts und Rollenwahl
- [ ] `Event::InvitationResource` (eigene lesen, `declined` setzen)
- [ ] Autorisierung und Scopes
- [ ] Fehlermeldungen (422) und `meta.warnings`
- [ ] Specs (OAuth, betreute Personen, Mails, Warteliste, `automatic_assignment`, Abmeldefrist, Einladung)
- [ ] Graphiti-Schema aktualisieren, Wagons durchtesten
- [ ] Mit angemessener Rolle "durchklicken" bzw. "durch-querien"
- [ ] DoD geprüft und erfüllt?
- [ ] CHANGELOG-Eintrag unter "unreleased"
- [ ] https://hitobito.readthedocs.io anpassen
