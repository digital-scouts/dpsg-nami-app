# Notizen zur Hitobito-DPSG Implementierung

## Repositories

Pfadi-DE: <https://github.com/hitobito/hitobito_pfadi_de/tree/a09059123380c11e5bae71fd4d3681032cc63ab4>
Hitobito-DPSG und DPSG Organization Hierarchy: <https://github.com/hitobito/hitobito_dpsg/tree/8cab76b13ab4c01f70da269ba563e804f04205e8>

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

Name: NamiDevTest
Client ID: ***REMOVED***

Client secret: ***REMOVED***

Redirect URIs: de.jlange.nami.app:/oauth/callback

Scopes:

- Lesen deiner E-Mail Adresse (email)
- Lesen deiner E-Mail Adresse und Name (name)
- Lesen deines OIDC Identity Tokens (openid)
- Lesen aller Personen, Gruppen, Events, Abos und Rechnungen auf die du Zugriff hast, via die JSON-Schnittstellen (api)

Hosts mit API-Zugriff: <http://127.0.0.1>
Einwilligung überspringen: nein
Discovery Endpoint: <https://demo.hitobito.com/.well-known/openid-configuration>

Authorization Endpoint:

- <https://demo.hitobito.com/oauth/authorize>
- <https://tools.ietf.org/html/rfc6749#section-3.1>
- <https://tools.ietf.org/html/rfc6749#section-4.1.1>

Token Endpoint:

- <https://demo.hitobito.com/oauth/token>
- <https://tools.ietf.org/html/rfc6749#section-3.2>
- <https://tools.ietf.org/html/rfc6749#section-4.1.3>

Profile Endpoint: <https://demo.hitobito.com/de/oauth/profile>

Profile Informationen des Benutzers koennen ueber diesen Endpoint bezogen werden. Dabei muss das Access Token im Authorization Header uebergeben werden. Fuer die Profilansicht der App werden Rollen ueber den Header `X-Scope: with_roles` mitgeladen.

Beispiel:

`curl -H 'Authorization: Bearer ***REMOVED***' -H 'X-Scope: with_roles' https://demo.hitobito.com/oauth/profile`

Aktuell verwendet die App aus `/oauth/profile` insbesondere diese Felder:

- `id` als nami-id
- `email`
- `first_name`, `last_name`, `nickname` fuer die Anzeige des Profilnamens
- `language` fuer Sprachbadge und Sprachsynchronisierung der App nach dem Login
- `roles` fuer die Rollenliste im Profil
