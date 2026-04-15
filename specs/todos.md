# Todos

Liste an problemen, die noch behoben werden müssen.

## Fehler

### Prüfen: 1 Netzwerkzugriff blockiert fehler

Im offline modus über debug tools den Hitobito Sync triggern, wirft fehler. Fehler sollte abgefangen sein und in der UI als Hinweis auftauchen, dass Hitobito nur über WLAN erreichbar ist. In den Logs taucht zusätzlich eine Warnung zum blockierten Netzwerkzugriff auf.

flutter: [2026-04-15 00:37:54] [info] [network] Netzwerkzugriff blockiert: trigger=debug_tools_profile_session feature=Hitobito reason=noMobileDataEnabled connection=mobile
flutter: [2026-04-15 00:37:54] [info] [hitobito_sync] Hitobito-Sync fehlgeschlagen (debug_tools): Keine Mobilen Daten ist aktiviert. Hitobito ist nur ueber WLAN verfuegbar.

 0      NetworkAccessPolicy.ensureNetworkAllowed (package:nami/services/network_access_policy.dart:123:5)
 1      AuthSessionModel._prepareSessionForRemoteAccess (package:nami/presentation/model/auth_session_model.dart:471:5)
 2      AuthSessionModel.executeRemoteAccess (package:nami/presentation/model/auth_session_model.dart:533:32)
 3      AuthSessionModel.syncHitobitoData (package:nami/presentation/model/auth_session_model.dart:748:7)
 4      DebugToolsPageState.build.anonymous closure (package:nami/presentation/screens/settings_debug_tools_page.dart:617:33)

### Prüfen: 2 Mitglied bearbeitung - offline nicht möglich

Im Offline Modus wird versucht zuerst das mitgleid zu laden um es zu bearbeiten. Das laden vorm Bearbeiten öffnen ist optinal, wenn online. Ablauf für Offline

1. Mitglied bearbeiten öffnen
2. Änderungen vornehmen
3. Änderungen speichern
4. Mitglied wird lokal gespeichert
5. Änderungen syncronisieren sobald wieder online
6. Bei Abweichenden  Daten Merge dialog öffnen

### Offen: 3 Merge Dialog vergessen

Merge-Dialog Variante 1

Werden Daten geändert, während ich sie in der app bearbeite oder habe ich daten offline geändert, dann soll ein Merge-Dialog auftauchen, wenn ich die Änderungen speichern möchte. In diesem Dialog werden die Datenfelder aufgelistet, die sich zwischen meinem lokalen Stand und dem Remote-Stand unterscheiden. Für jedes Feld kann ich auswählen, ob ich meine lokale Änderung behalten oder die Remote-Änderung übernehmen möchte.
Bei komplexen Feldern, die nicht zusammengeführt werden können, wird angezeigt, dass die lokale Änderung verworfen wird und ich muss dies explizit bestätigen.

- Neuer eigener Dialog oder Screen
- Eingaben:
  - Basisstand
  - lokaler Stand
  - aktueller Remote-Stand
- Nur einfache Felder listen
- Für jedes einfache Konfliktfeld Auswahl lokal oder online
- Komplexe Felder eigener Abschnitt:
  - nicht automatisch mergebar
  - lokale Änderung wird verworfen
  - explizit im Dialog anzeigen
- Nach Bestätigung:
  - gemergten Zielstand erzeugen
  - nicht mergebare lokale Teiländerungen entfernen
  - Upload erneut ausführen

Konfliktlogik im Write-Flow erweitern

- Heute führt Konflikt nur zu MemberWriteConflictException
- Künftig sollte der Application-/Presentation-Pfad daraus einen Merge-Fall machen
- Repository bleibt eher bei:
  - Daten laden
  - updatedAt vergleichen
  - Konflikt melden
- Merge-Erzeugung gehört in Model oder UseCase, nicht in den API-Client

### Solved: 4 Hinzufügen von additional_field

Die Aktuellen Requests wenn additional_emails oder additional_phone_numbers hinzugefügt werden, führen zu einem 404 Fehler, da die Datenbank diese Felder noch nicht kennt. Außerdem sind änderungen mit additional Fields mehrere PUT Requests.

Behebe den fehler und sende alle Änderungen in einem Request.

So Funktioniert update:

```json
{
  "data": {
    "type": "people",
    "id": "123",
    "attributes": {
            "first_name": "Mio",
            "last_name": "Wollmann"
        },
    "relationships": {
      "phone_numbers": {
        "data": [
          {
            "type": "phone_numbers",
            "id": "456",
            "method": "update"
          }
        ]
      }
    }
  },
  "included": [
    {
      "type": "phone_numbers",
      "id": "456",
      "attributes": {
        "number": "+41791111111"
      }
    }
  ]
}
```

So Funktioniert create:

```json

{
  "data": {
    "type": "people",
    "id": "123",
    "relationships": {
      "phone_numbers": {
        "data": [
          {
            "type": "phone_numbers",
            "temp-id": "new-phone-1",
            "method": "create"
          }
        ]
      }
    }
  },
  "included": [
    {
      "type": "phone_numbers",
      "temp-id": "new-phone-1",
      "attributes": {
        "label": "Mobil",
        "number": "+41790000000",
        "public": true
      }
    }
  ]
}

```

So Funktioniert delete:

```json

{
  "data": {
    "type": "people",
    "id": "123",
    "relationships": {
      "phone_numbers": {
        "data": [
          {
            "type": "phone_numbers",
            "id": "456",
            "method": "destroy"
          }
        ]
      }
    }
  }
}

```

## Änderungswünsche

## Weitere Funktionen

- Adresse Automatisch vervollständigen mit Geocoding API
  - Nutze bestehenden Dienst GEOAPIFY
  - Dazu müssen nicht mehr alle Felder zur Adresse angezeigt werden, die Eingabe und Auswahl kann in einem einzelnen Feld erfolgen. Bezeichnung und c/o sind weiterhin eigene Felder.
  - Feld Postfach kann entfallen.
  - Feld Land als Dropdown, nur Deutschland (default) und Nachbarländer.
  - Aktuelle Ansicht bleibt Fallback, wenn Bearbeitung offline oder Geocoding API nicht verfügbar ist.
- Adresse validieren (erst mit merge dialog umsetzten)
  - Nur relevant bei Offline bearbeitung und späterem Sync. Sollte dann ebenfalls über den Merge Dialog laufen. (Adresse nicht gefunden, eingaben prüfen)

## Manuelle Tests

- [ ] Mitglied offline bearbeiten: Änderungen lokal speichern, später synchronisieren, Merge-Dialog bei Konflikten
- [ ] Merge-Dialog: Bei gleichzeitigen Änderungen an einem Mitglied, Merge-Dialog öffnen, Auswahlmöglichkeiten prüfen, Ergebnis validieren.
- [ ] Verschiedene Online Funktionen im Offline-Modus testen
- [ ] Update, Delete und Create von additional_fields testen.
