# JSON:API: Teilnehmende verwalten (Bewerbungsmarkt, Freigabe, Rollen, Antworten, Qualifizierung)

Entwurf, noch nicht eingereicht. Baut auf hitobito#4563 auf.

## Ausgangslage

Für Leitungen, Organisationsteams und Ebenenverantwortliche bietet die Weboberfläche viele Aktionen an bestehenden Events:
- Teilnehmendenliste
- Bewerbungsmarkt (Platz vergeben oder entziehen, Warteliste)
- Freigabe und Ablehnung von Bewerbungen
- Leitungs- und Helfendenrollen
- Antworten und Zusatzinfos bearbeiten
- Teilnehmende entfernen
- Qualifizieren
- Einladungen

In der JSON:API lassen sich Teilnahmen nur lesen, und nur aktive. Schreiben geht gar nicht.

User Story: Als Kursleitung sehe ich in einer App die Teilnehmenden mit Antworten, trage Helfende ein und qualifiziere nach dem Kurs. Als Ebenenverantwortliche vergebe ich im Bewerbungsmarkt Plätze und gebe Bewerbungen aus meiner Ebene frei.

## Anforderungen

Grundsatz: gleicher Funktionsumfang und gleiche Rechte wie im UI oder weniger, jeweils über die Ability und die Logik, die das UI nutzt.

1. **Teilnehmendenliste**
   - `GET /api/event_participations?filter[event_id]=…` wie die Liste im UI.
   - Recht: `index_participations`. Kontaktangaben nach `show_details` bzw. `show_full`. Antworten nach `Event::Question::VisibleList`.
   - Filter wie die Listen-Tabs (Leitungsteam, Teilnehmende, alle): `filter[role_type]` bzw. die Rollen-Kategorie.

2. **Bewerbungsmarkt** (Recht `application_market`: `layer_full` bzw. `layer_and_below_full`, wie `Event::ApplicationMarketController`)
   - Bewerbungen lesen wie die Marktansicht: inaktive Teilnahmen dieses Events und Bewerbungen anderer Kurse mit diesem Event als Priorität 2 oder 3, z. B. über `filter[priority_event_id]=…`.
   - Platz vergeben und entziehen über `Event::ParticipantAssigner#add_participant` bzw. `#remove_participant` (`put/delete participant`).
   - Warteliste setzen und entfernen mit `waiting_list_comment` (`put/delete waiting_list`).

3. **Freigabe** (Recht `approve` bzw. `reject` aus `Event::ApplicationAbility`, also `approve_applications` in der Ebene der bewerbenden Person)
   - Wie `Event::ApplicationsController#approve` und `#reject` (`toggle_approval`).

4. **Rollen im Event** (Rechte aus `Event::RoleAbility`)
   - Anlegen und ändern mit `participations_full` im Event oder mit Gruppen- bzw. Ebenenrechten.
   - Eine Person über ihre Rolle eintragen. Wie im `Event::RolesController` entsteht dabei die Teilnahme mit.
   - Löschen mit denselben Rechten, die eigene Leitungsrolle ausgenommen (`for_participations_full_events_except_self`). Ist es die letzte Rolle, verschwindet die Teilnahme, wie im UI.

5. **Teilnahme bearbeiten** (Recht `update` aus `Event::ParticipationAbility`: `participations_full` im Event, `layer_full` usw.)
   - `additional_information` und Antworten (Anmelde- und Admin-Fragen, so weit sichtbar), wie das Bearbeiten-Formular.

6. **Teilnahme entfernen** (Recht `destroy`: nur Gruppen- und Ebenenrechte, wie im UI)
   - Kursleitungen ohne diese Rechte entfernen Personen wie im UI über deren Rollen (Punkt 4).

7. **Qualifizieren** (Recht `qualify` aus `EventAbility`, wie `Event::QualificationsController#update`)
   - Teilnehmende als qualifiziert bzw. nicht qualifiziert markieren. `Event::Qualifier` vergibt bzw. verlängert die Qualifikationen.

8. **Einladungen** (Rechte aus `Event::InvitationAbility`: Gruppen- und Ebenenrechte)
   - Lesen, anlegen und löschen wie `Event::InvitationsController`.

Nicht gefordert: Mails und Nachrichten (`send_mails`, `messages`), Exporte, Druck, Tags und Anhänge.

## Vorgeschlagene Endpunkte

| Methode | Pfad | Zweck | Recht wie im UI |
|---|---|---|---|
| GET | `/api/event_participations?filter[event_id]=…&include=participant,roles,answers,application` | Teilnehmendenliste | `index_participations`, `show_details` |
| GET | `/api/event_participations?filter[event_id]=…&filter[active]=false`, `filter[priority_event_id]=…` | Bewerbungsmarkt lesen | `application_market` |
| POST | `/api/event_applications/:id/assignment` | Platz vergeben (`add_participant`) | `application_market` |
| DELETE | `/api/event_applications/:id/assignment` | Platz entziehen (`remove_participant`) | `application_market` |
| PATCH | `/api/event_applications/:id` (`waiting_list`, `waiting_list_comment`) | Warteliste | `application_market` |
| PATCH | `/api/event_applications/:id` (`approved` bzw. `rejected`) | Freigabe | `approve` / `reject` |
| POST, PATCH, DELETE | `/api/event_roles` (`participation_id` bzw. `person_id`, `type`, `label`) | Rollen, Personen eintragen | `Event::RoleAbility` |
| PATCH | `/api/event_participations/:id` (`additional_information`, Sidepost `answers`) | Teilnahme bearbeiten | `update` |
| DELETE | `/api/event_participations/:id` | Teilnahme entfernen | `destroy` (Gruppen- und Ebenenrechte) |
| PATCH | `/api/event_participations/:id` (`qualified`) | qualifizieren | `qualify` |
| GET, POST, DELETE | `/api/event_invitations` | Einladungen | `Event::InvitationAbility` |

Beispiel: Platz vergeben.

```http
POST /api/event_applications/3/assignment
Authorization: Bearer <OAuth-Token mit Scope api>
```

Antwort: 200 mit der aktualisierten Teilnahme (`active: true`, ggf. auf dieses Event umgehängt). 403 ohne `application_market`.

## Abgrenzungen

- Teilnehmenden-Sicht (lesen, an- und abmelden): hitobito#4563 und das Issue zum Anmelden.
- Events anlegen und bearbeiten folgt getrennt.
- Gäste (`Event::Guest`) zunächst nicht.

## Offene Fragen

- Bewerbungsmarkt als eigene Aktionen (`/assignment`, wie die Web-Routen `put/delete participant`) oder als Attribut-Änderung (`active`)? Für eigene Aktionen sprechen die Nebenwirkungen beim Umhängen auf Priorität 2/3 und bei den Zählern.
- Ist `filter[priority_event_id]` der richtige Weg für Bewerbungen aus anderen Kursen, oder besser eine eigene Ressource für den Markt?
- Qualifizieren als Attribut `qualified` an der Teilnahme, oder als Massenaktion wie `PUT …/qualifications`?

## Tech-Spec

- **Logik wiederverwenden:** Umsetzung im Core mit `Event::ParticipantAssigner`, `Event::Application#toggle_approval`, `Event::Qualifier` und dem Aufbau von Rolle und Teilnahme aus `Event::RolesController#build_entry`. Wo die Logik heute im Controller steckt, wandert sie in Services, die UI und API teilen.
- **Autorisierung:** ausschließlich über die bestehenden Abilities `EventAbility`, `Event::ParticipationAbility`, `Event::ApplicationAbility`, `Event::RoleAbility` und `Event::InvitationAbility`.
- **Scopes:** In `ApiScopeAbility` für `Event::Application`, `Event::Role`, `Event::Answer` und `Event::Invitation` ergänzen.
- **Zähler:** `refresh_participant_counts!` wie im UI.
- **Doku:** OpenAPI und `json_api.md` ergänzen.

## ToDo

- [ ] Readables für Liste und Bewerbungsmarkt nach `index_participations` bzw. `application_market`
- [ ] Services für Markt, Freigabe, Qualifizierung, Rollen; UI-Controller darauf umstellen
- [ ] Schreibpfade an `event_applications`, `event_roles`, `event_participations`, `event_invitations`
- [ ] Scopes in `ApiScopeAbility`
- [ ] Specs je Recht (Kursleitung mit `participations_full` und `qualify`, Ebene mit `layer_full`, `approve_applications`)
- [ ] Graphiti-Schema aktualisieren, Wagons durchtesten
- [ ] Mit angemessener Rolle "durchklicken" bzw. "durch-querien"
- [ ] DoD geprüft und erfüllt?
- [ ] CHANGELOG-Eintrag unter "unreleased"
