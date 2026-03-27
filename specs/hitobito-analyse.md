# Notizen zur Hitobito-DPSG Implementierung

## Repositories

Hitobito: <https://github.com/hitobito/hitobito>
Pfadi-DE: <https://github.com/hitobito/hitobito_pfadi_de>
Hitobito-DPSG und DPSG Organization Hierarchy: <https://github.com/hitobito/hitobito_dpsg>

## Datenmodell

Das finale Datenmodel setzt sich aus Hitobito + Pfadi-DE + DPSG zusammen.
Neben den drei Ressource-Typen Group, People und Role gibt es weitere Ressourcen wie PhoneNumber, SocialAccount, AdditionalEmail, AdditionalAddress, MailingList, Event, Subscription, Invoice etc. die teilweise auch in der App relevant sein koennen.

### Group

#### Hitobito Group

##### Hitobito Group Attribute

| Attribut | Typ | Hinweise |
| --- | --- | --- |
| `name` | `string` | Gruppenname |
| `short_name` | `string` | Kurzname |
| `display_name` | `string` | berechneter Anzeigename |
| `description` | `string` | Beschreibung |
| `layer` | `boolean` | Kennzeichnet Ebenengruppe |
| `parent_id` | `integer` | ID der uebergeordneten Gruppe |
| `layer_group_id` | `integer` | ID der zugeordneten Ebenengruppe |
| `type` | `string` | technischer Gruppentyp |
| `email` | `string` | Kontakt-E-Mail |
| `address` | `string` | Adresse |
| `zip_code` | `integer` | Postleitzahl |
| `town` | `string` | Ort |
| `country` | `string` | Land |
| `require_person_add_requests` | `boolean` | Personen muessen Aufnahme anfragen |
| `self_registration_url` | `string` | URL fuer Selbstregistrierung |
| `self_registration_require_adult_consent` | `boolean` | Selbstregistrierung verlangt Einwilligung Erwachsener |
| `archived_at` | `datetime` | Archivierungszeitpunkt |
| `created_at` | `datetime` | Erstellungszeitpunkt |
| `updated_at` | `datetime` | Aenderungszeitpunkt |
| `deleted_at` | `datetime` | Loeschzeitpunkt |
| `logo` | `string` | extra attribute, Logoreferenz |
| `language` | `string` | extra attribute, Standardsprache der Gruppe |
| `privacy_policies` | `array` | extra attribute, Datenschutzrichtlinien |

##### Hitobito Group Beziehungen

| Beziehung | Typ | Hinweise |
| --- | --- | --- |
| `contact` | `belongs_to PersonResource` | read-only, `foreign_key: contact_id` |
| `creator` | `belongs_to PersonResource` | read-only, `foreign_key: creator_id` |
| `updater` | `belongs_to PersonResource` | read-only, `foreign_key: updater_id` |
| `deleter` | `belongs_to PersonResource` | read-only, `foreign_key: deleter_id` |
| `parent` | `belongs_to GroupResource` | read-only, `foreign_key: parent_id` |
| `layer_group` | `belongs_to GroupResource` | read-only, `foreign_key: layer_group_id` |
| `phone_numbers` | `polymorphic_has_many` | `as: contactable` |
| `social_accounts` | `polymorphic_has_many` | `as: contactable` |
| `additional_emails` | `polymorphic_has_many` | `as: contactable` |
| `additional_addresses` | `polymorphic_has_many` | `as: contactable` |
| `mailing_lists` | `has_many` | read-only |

#### Pfadi-DE Group

##### Pfadi-DE Group Attribute

| Attribut | Typ | Hinweise |
| --- | --- | --- |
| `bank_account_owner` | `string` | Kontoinhaber |
| `iban` | `string` | IBAN |
| `bic` | `string` | BIC |
| `bank_name` | `string` | Bankname |

### People

#### Hitobito People

##### Hitobito People Attribute

| Attribut | Typ | Hinweise |
| --- | --- | --- |
| `first_name` | `string` | Vorname |
| `last_name` | `string` | Nachname |
| `nickname` | `string` | Spitzname |
| `company_name` | `string` | Firmenname |
| `company` | `boolean` | Kennzeichnet Firmenkontakt |
| `email` | `string` | Primaere E-Mail |
| `address` | `string` | read-only |
| `address_care_of` | `string` | c/o |
| `street` | `string` | Strasse |
| `housenumber` | `string` | Hausnummer |
| `postbox` | `string` | Postfach |
| `zip_code` | `string` | Postleitzahl |
| `town` | `string` | Ort |
| `country` | `string` | Land |
| `household_key` | `string` | read-only |
| `primary_group_id` | `integer` | read-only |
| `gender` | `string` | lesbar ueber `show_details?`, schreibbar ueber `write_details?` |
| `birthday` | `date` | lesbar ueber `show_details?`, schreibbar ueber `write_details?` |
| `language` | `string` | bevorzugte Sprache |
| `picture` | `string` | Bildreferenz |
| `updated_at` | `datetime` | Zeitpunkt der letzten Aenderung |
| `additional_information` | `string` | Zusatzinformationen |

##### Hitobito People Beziehungen

| Beziehung | Typ | Hinweise |
| --- | --- | --- |
| `primary_group` | `belongs_to GroupResource` | read-only |
| `layer_group` | `has_one GroupResource` | read-only |
| `roles` | `has_many` | read-only |
| `phone_numbers` | `polymorphic_has_many` | `as: contactable` |
| `social_accounts` | `polymorphic_has_many` | `as: contactable` |
| `additional_emails` | `polymorphic_has_many` | `as: contactable` |
| `additional_addresses` | `polymorphic_has_many` | `as: contactable` |

#### Pfadi-DE People

##### Pfadi-DE People Attribute

| Attribut | Typ | Hinweise |
| --- | --- | --- |
| `pronoun` | `string` | Anrede/Pronomen |
| `entry_date` | `date` | read-only |
| `exit_date` | `date` | Austrittsdatum |
| `bank_account_owner` | `string` | Kontoinhaber |
| `iban` | `string` | IBAN |
| `bic` | `string` | BIC |
| `bank_name` | `string` | Bankname |
| `payment_method` | `string` | Zahlart |
| `consent_data_retention` | `boolean` | Einwilligung zur Datenhaltung |

### Role

#### Hitobito Role

##### Hitobito Role Attribute

| Attribut | Typ | Hinweise |
| --- | --- | --- |
| `created_at` | `datetime` | Erstellungszeitpunkt |
| `updated_at` | `datetime` | Aenderungszeitpunkt |
| `start_on` | `date` | Startdatum |
| `end_on` | `date` | Enddatum |
| `name` | `string` | Rollenname |
| `person_id` | `integer` | Personenreferenz |
| `group_id` | `integer` | Gruppenreferenz |
| `type` | `string` | technischer Typ |
| `label` | `string` | Anzeigename/Label |

#### Hitobito Role Beziehungen

| Beziehung | Typ | Hinweise |
| --- | --- | --- |
| `person` | `belongs_to` | read-only |
| `group` | `belongs_to` | read-only |
| `layer_group` | `has_one GroupResource` | read-only |

## API

<https://github.com/hitobito/hitobito/blob/master/doc/developer/common/api/json_api.md>

### OAuth2

OAuth Flow (empfohlen)
👉 So ist es gedacht:
App → öffnet Hitobito Login (Browser/WebView)
User loggt sich ein
→ App bekommt Token
→ nutzt API

<https://github.com/hitobito/hitobito/blob/master/doc/developer/people/oauth.md>

#### Testzugang (nur für Entwicklung)

Der Testzugang ist über die Hitobito Demo-Instanz möglich: <https://demo.hitobito.com>. Hier stehen nur die Hitobito-eigenen Ressourcen zur Verfügung, aber keine Pfadi-DE oder DPSG-spezifischen Erweiterungen. Für die Entwicklung und das Testen der API-Integration und Grundfunktionen ist dies jedoch ausreichend.

Name: NamiDevTest
Client ID: 8pzUjB0d1gE7JjgpVffSSbMMkADzvFpybbkG99a1Dg4

Client secret: 7_34xf5oFKwxOQAsMe0_-7HFH5D0SPZ1hs1jmR8aomk

Redirect URIs: de.jlange.nami.app:/oauth/callback

Hosts mit API-Zugriff: <http://127.0.0.1>
Einwilligung überspringen: nein

Aktuelle App-Konfiguration fuer Entwicklung:

- `HITOBITO_BASE_URL=https://demo.hitobito.com`
- `HITOBITO_OAUTH_CLIENT_ID=...`
- `HITOBITO_OAUTH_CLIENT_SECRET=...`
- `HITOBITO_OAUTH_REDIRECT_URI=de.jlange.nami.app:/oauth/callback`

Die App leitet daraus aktuell diese Endpunkte ab:

- Discovery Endpoint: <https://demo.hitobito.com/.well-known/openid-configuration>
- Authorization Endpoint: <https://demo.hitobito.com/oauth/authorize>
- Token Endpoint: <https://demo.hitobito.com/oauth/token>
- Profile Endpoint: <https://demo.hitobito.com/de/oauth/profile>
- People Endpoint: <https://demo.hitobito.com/api/people>

Die App fordert beim OAuth-Login aktuell standardmaessig die Scopes `openid name email api with_roles` an.

Profile Informationen des Benutzers koennen ueber den aktuell in der App verwendeten Endpoint `/de/oauth/profile` bezogen werden. Dabei muss das Access Token im Authorization Header uebergeben werden. Fuer die Profilansicht der App werden Rollen ueber den Header `X-Scope: with_roles` mitgeladen. Zusaetzlich ist `with_roles` aktuell auch Teil der beim Login angeforderten OAuth-Scopes.
