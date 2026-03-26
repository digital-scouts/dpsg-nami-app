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
Client ID: 8pzUjB0d1gE7JjgpVffSSbMMkADzvFpybbkG99a1Dg4

Client secret: 7_34xf5oFKwxOQAsMe0_-7HFH5D0SPZ1hs1jmR8aomk

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

Profile Informationen des Benutzers können über diesen Endpoint bezogen werden. Dabei muss das Access Token im Authorization Header übergeben werden. Der gewünschte Scope kann als X-Scope Header übergeben werden.

`curl -H 'Authorization: Bearer 057b491f0ea151782f1ab3ed67dba91eaf0d59e621f312afec4d3bf81e08777a' -H 'X-Scope: email' https://demo.hitobito.com/de/oauth/profile`
