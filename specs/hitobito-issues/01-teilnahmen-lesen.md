# JSON:API: Teilnahmen aus Sicht der Teilnehmenden lesen (Bewerbungsstand, Antworten, Anmelde- und Abmeldemöglichkeit)

Eingereicht als [hitobito#4563](https://github.com/hitobito/hitobito/issues/4563) am 2026-10-10. Der Text unten entspricht dem eingereichten Stand.

## Ausgangslage

Eine App für Mitglieder soll Kurse und Veranstaltungen anzeigen. Sie soll auch zeigen, wo man angemeldet ist und in welchem Stand die Anmeldung ist. Die Weboberfläche zeigt das alles bereits, die JSON:API noch nicht:

- **Offene Bewerbungen fehlen.** `Event::ParticipationResource#base_scope` filtert `.active`. Offene Kursbewerbungen (`active: false`) fehlen deshalb auch für die Person selbst. Im UI stehen sie auf der eigenen Personenseite unter „Anmeldungen“ (`Person::EventQueries#pending_applications`). Die eigene Teilnahme-Seite zeigt sie ebenfalls.
- **Der Stand der Bewerbung fehlt.** Die eigene Teilnahme-Seite zeigt Prioritäten, Warteliste mit Kommentar und den Freigabestatus (`_priorities`, `_approvals`, Rechte `show_priorities` und `show_approval` in `Event::ApplicationAbility`). In der API steht nur `application_id`.
- **Antworten und Fragen fehlen.** Das UI zeigt der Person ihre Antworten auf die Anmeldefragen (`_answers`, `Event::Question::VisibleList`). Vor der Anmeldung zeigt das Anmeldeformular die Fragen.
- **Angaben der Eventseite fehlen.** Die Eventseite zeigt für alle Event-Typen `booking_info` (Anmeldungen und Maximum, `EventDecorator#booking_info`). In der API gibt es `applicant_count` nur für Kurse. Bei Kursen zeigt die Seite außerdem, welche Qualifikationen die Kursart vergibt, verlängert und voraussetzt (`events/_attrs_application`). Die API liefert davon nichts.
- **Ob man sich an- oder abmelden kann, fehlt.** Das UI zeigt „Anmelden“, wenn `event.application_possible?` und `can?(:new, participation)` (`EventsHelper#event_user_application_possible?`). „Abmelden“ zeigt es, wenn `can?(:destroy, participation)` (`Event::ParticipationBanner`). Ein API-Client müsste diese Regeln aus Einstellungen nachbauen, die die API nicht liefert und die er nicht kennen soll.

User Story: Als Mitglied sehe ich in einer App meine Anmeldungen mit ihrem Stand (beworben, Warteliste, Platz erhalten, Freigabe ausstehend oder abgelehnt). Auf einem Event sehe ich, ob ich mich anmelden oder abmelden kann, welche Fragen gestellt werden und welche Qualifikation ein Kurs bringt. Eltern sehen dasselbe für betreute Kinder.

## Anforderungen

Grundsatz: Die API zeigt dieselben Daten wie die Weboberfläche oder weniger, mit denselben Abilities. Es gibt keine neuen Rechte und keine Daten, die das UI der Person nicht zeigt. Alles ist nur lesend.

1. **Eigene offene Bewerbungen**
   - `GET /api/event_participations?filter[participant_id]=<id>` liefert für die eigene Person und für betreute Personen auch inaktive Teilnahmen, wie `pending_applications` und die Teilnahme-Seite.
   - Für alle anderen bleibt es bei aktiven Teilnahmen. Die Sicht der Veranstaltenden ist nicht Teil dieses Issues.
   - Neuer Filter `filter[active]`.

2. **Stand der Bewerbung**
   - Neue lesbare Ressource `event_applications` mit der Relation `application` an `event_participations`.
   - Lesbar nach `Event::ApplicationAbility`:
     - mit `show_priorities`: `priority_1_id`, `priority_2_id`, `priority_3_id`, `waiting_list`, `waiting_list_comment`
     - mit `show_approval` und nur bei `requires_approval`: `approved`, `rejected`
   - Gleiche Bedingungen wie `show_application_priorities?` und `show_application_approval?`.

3. **Eigene Antworten**
   - Neue lesbare Ressource `event_answers` mit `question_id`, `answer`, `participation_id`. Relation `answers` an `event_participations`.
   - Sichtbar nur, wenn das UI sie zeigt: `can?(:show_details, participation)` und Auswahl über `Event::Question::VisibleList`. Die eigene Person sieht ihre Antworten auf die Anmeldefragen, Admin-Fragen nur nach Sichtbarkeit.

4. **Anmeldefragen vor der Anmeldung**
   - Neue lesbare Ressource `event_questions` mit `question`, `choices`, `multiple_choices`, `required`. Relation `application_questions` an `events`.
   - Nur die Fragen des Anmeldeformulars (`admin: false`), und nur für Personen, die das Formular öffnen dürfen (`event_user_application_possible?`) oder schon teilnehmen. Admin-Fragen nur nach `Event::Question::VisibleList`.

5. **Angaben der Eventseite**
   - `applicant_count` für alle Event-Typen, nicht nur für Kurse (entspricht `booking_info`).
   - Wie auf der Eventseite, falls benutzt: `minimum_participants`, `signature`, `signature_confirmation`.
   - An `event_kinds` die Relation `kind_qualification_kinds` mit `category` (`qualification`, `prolongation`, `precondition`), `grouping` und `qualification_kind`. Nur Einträge mit `role: participant`, wie auf der Eventseite.

6. **Was die Person tun kann**
   - An `events` ein berechnetes, nur lesbares Attribut `application_possible`. Es entspricht `event_user_application_possible?` für die angemeldete Person, also genau dem Anmelde-Knopf.
   - An `event_participations` ein berechnetes, nur lesbares Attribut `cancelable` = `can?(:destroy, participation)`, also genau dem Abmelde-Knopf.

Ausdrücklich nicht gefordert, weil das UI es der Person nicht zeigt: die Einstellungen `globally_visible`, `participations_visible`, `requires_approval` und `waiting_list` als Rohwerte, außerdem `participant_count` für einfache Events.

## Vorgeschlagene Endpunkte

| Methode | Pfad | Änderung | Recht wie im UI |
|---|---|---|---|
| GET | `/api/event_participations?filter[participant_id]=…&filter[active]=false` | eigene und betreute auch inaktiv, neuer Filter | `show` her_own_or_manager |
| GET | `/api/event_participations?include=application,answers` | neue Relationen, neues Attribut `cancelable` | `show_priorities`, `show_approval`, `show_details` |
| GET | `/api/event_applications`, `/api/event_applications/:id` | neue Ressource, nur lesen | `show_priorities` / `show_approval` |
| GET | `/api/event_answers`, `/api/event_answers/:id` | neue Ressource, nur lesen | `show_details` + `Event::Question::VisibleList` |
| GET | `/api/events/:id?include=application_questions` | neue Relation, neues Attribut `application_possible` | Anmeldeformular bzw. Teilnahme |
| GET | `/api/event_questions`, `/api/event_questions/:id` | neue Ressource, nur lesen | wie oben |
| GET | `/api/events` | `applicant_count` für alle Typen, Felder der Eventseite | `show` am Event |
| GET | `/api/event_kinds?include=kind_qualification_kinds.qualification_kind` | neue Relation | `list_available` wie heute |

Beispiel: eigene Anmeldungen mit Stand.

```http
GET /api/event_participations?filter[participant_id]=42&include=event,application,answers
Authorization: Bearer <OAuth-Token mit Scope api>
```

```json
{
  "data": [{
    "id": "7", "type": "event_participations",
    "attributes": { "event_id": 5, "active": false, "cancelable": true },
    "relationships": { "application": { "data": { "type": "event_applications", "id": "3" } } }
  }],
  "included": [{
    "id": "3", "type": "event_applications",
    "attributes": { "priority_1_id": 5, "priority_2_id": 8, "waiting_list": false, "approved": false, "rejected": false }
  }]
}
```

## Abgrenzungen

- Nur lesen. Anmelden und abmelden über die API, Aktionen der Veranstaltenden (Bewerbungsmarkt, Freigabe, Rollen, Qualifizieren) sowie Events anlegen und bearbeiten folgen getrennt.
- Keine Kontaktdaten anderer Teilnehmender. Die bestehenden Regeln (#4404) bleiben unverändert.
- Gäste (`Event::Guest`), Einladungen und Wagon-Zustände (`state`) gehören nicht dazu.

## Offene Fragen

- Sind `application_possible` und `cancelable` als berechnete Attribute in Ordnung, oder passen sie besser in `meta` je Datensatz?
- Welcher Scope gilt für `event_applications`, `event_answers` und `event_questions`: `event_participations`, `events` oder beide?
- Soll `filter[active]` für alle gelten (mit derselben Ability-Einschränkung) oder nur für eigene und betreute Teilnahmen?

## Tech-Spec

- **Basis:** Umsetzung im Core, aufbauend auf #4523 (Readables, Autorisierung im `JsonApiController`).
- **Teilnahmen:** `JsonApi::EventParticipationReadables` liefert eigene und betreute Teilnahmen auch inaktiv. `Event::ParticipationResource#base_scope` filtert `.active` nur noch für die übrigen.
- **Neue Ressourcen:**
  - `Event::ApplicationResource` mit Readables nach `Event::ApplicationAbility`. Attribute je nach `show_priorities` bzw. `show_approval` (Graphiti `readable:`).
  - `Event::AnswerResource` und `Event::QuestionResource`. Die Auswahl übernimmt `Event::Question::VisibleList`, damit API und UI dieselbe Logik nutzen.
- **Event-Ressourcen:** `applicant_count` von `Event::CourseResource` nach `EventResource` verschieben. `application_possible` als `extra_attribute` über die Logik von `event_user_application_possible?`, ggf. als Domain-Methode herausgelöst, damit Helper und Resource sie teilen.
- **Teilnahme-Ressource:** `cancelable` = `current_ability.can?(:destroy, model)`.
- **Kursart:** `Event::KindQualificationKindResource` (nur lesen, `role: participant`) mit `belongs_to :qualification_kind`.
- **Scopes:** In `ApiScopeAbility::REQUIRED_SCOPES` die neuen Modelle eintragen.
- **Nebenbefund:** In `Event::KindResource#base_scope` fehlt bei den beiden `Event::Kind.none unless …`-Zeilen das `return`, sie wirken also nicht.
- **Doku:** OpenAPI-Schema neu erzeugen, `doc/developer/common/api/json_api.md` ergänzen.
- **Bezug:** #3789, #3726, #4404, #4357, #2726

## ToDo

- [ ] Readables/`base_scope` für eigene und betreute inaktive Teilnahmen, `filter[active]`
- [ ] `Event::ApplicationResource` mit Attributschutz nach `show_priorities` / `show_approval`
- [ ] `Event::AnswerResource`, `Event::QuestionResource` über `Event::Question::VisibleList`
- [ ] Relationen `application`, `answers`, `application_questions`, `kind_qualification_kinds`
- [ ] Attribute `applicant_count` (alle Typen), `application_possible`, `cancelable`, Felder der Eventseite
- [ ] Scopes in `ApiScopeAbility`
- [ ] Specs (Resources, Readables, Requests mit OAuth und Service Token; eigene, betreute und fremde Teilnahmen)
- [ ] Graphiti-Schema aktualisieren, Wagons durchtesten
- [ ] Mit angemessener Rolle "durchklicken" bzw. "durch-querien"
- [ ] [DoD](https://github.com/hitobito/hitobito/blob/master/doc/developer/process/definition_of_done.md) geprüft und erfüllt?
- [ ] CHANGELOG-Eintrag unter "unreleased"
