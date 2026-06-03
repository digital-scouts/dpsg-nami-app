# DPSG Organization Hierarchy

Hinweis für die App-Ableitung: Für die Mitgliederliste werden die Stufen derzeit über die Stamm-Gruppentypen `Group::StammGruppeBiber`, `Group::StammGruppeWoelflinge`, `Group::StammGruppeJungpfadfinder`, `Group::StammGruppePfadfinder` und `Group::StammGruppeRover` abgeleitet. Die globalen Mitgliedschaften unter "Mitglieder" dienen aktuell nur als reine Anzeige der Beitragsart.

Struktur vorhandener Gruppen und Rollen. Diese Datei ist eher eine Notiz und fachlich nicht 100% so vorhanden.

* Bundesebene
  * Bundesebene
    * MV-Administrator*in: 2FA [:layer_and_below_full, :admin, :finance, :impersonation, :assign_restricted_fee_kinds]
    * Erfasser*in Führungszeugnis: 2FA [:layer_and_below_read, :group_and_below_efz]
    * Kassenprüfer*in: []
    * Bundesmitarbeiter*in: []
  * Bundesvorstand
    * Bundesvorsitzende*r: 2FA [:layer_and_below_full, :contact_data, :assign_restricted_fee_kinds]
    * Stv. Bundesvorsitzende*r: 2FA [:layer_and_below_full, :contact_data, :assign_restricted_fee_kinds]
    * Bundesschatzmeister*in: 2FA [:layer_and_below_full, :contact_data, :finance, :assign_restricted_fee_kinds]
    * Stv. Bundesschatzmeister*in: 2FA [:layer_and_below_full, :contact_data, :finance, :assign_restricted_fee_kinds]
    * Empfänger*in Aufnahmeantrag Über18: []
  * Bundesgeschäftsstelle
    * Bundesgeschäftsführer*in: 2FA [:layer_and_below_full, :admin, :contact_data, :finance, :assign_restricted_fee_kinds]
    * Mitgliederverwalter*in Bund: 2FA [:layer_and_below_full, :admin, :contact_data, :finance, :assign_restricted_fee_kinds]
    * Hauptamtliche Sachbearbeiter*in: 2FA [:layer_and_below_full, :contact_data, :assign_restricted_fee_kinds]
    * Hauptamtliche Referent*in: 2FA [:layer_and_below_read, :contact_data, :assign_restricted_fee_kinds]
    * Hauptamtliche*r: 2FA [:contact_data, :assign_restricted_fee_kinds]
  * Ombudsrat
    * Mitglied: []
  * Betrieb
    * Geschäftsführer*in: []
  * Versammlung
    * Versammlungsleitung: []
    * Protokollführung: []
    * Technik: []
  * Projekte
  * Projekt
    * Lagerleiter*in: [:group_read, :contact_data]
    * Stv. Lagerleiter*in: [:group_read, :contact_data]
    * Mitarbeiter*in: []
    * Beauftragte*r: []
    * Mitgliederverwalter*in Großprojekt: 2FA [:group_full]
    * Zugriffsberechtige*r Mitgliederverwaltung Großprojekt: 2FA [:layer_and_below_read]
  * Bereich
    * Bereichsleitung: [:group_read, :contact_data]
    * Mitarbeiter*in: []
  * Arbeitsbereiche
  * Stufen
  * Biber
  * Jungpfadfinder*innenstufe
  * Wölflingsstufe
  * Pfadfinder*innenstufe
  * Ranger/Rover-Stufe
  * Erwachsenenarbeit
  * Ausbildung
  * Internationales
  * intakt
  * intakt - Prävention und Intervention
  * intakt - psychische Gesundheit
  * intakt - Macht und Miteinander
  * Öffentlichkeitsarbeit/Medien
  * Politische Bildung/Politik und Gesellschaft
  * IT
  * Findungskommission
  * Rainbow
  * Inklusion
  * Wachstum und Stämme
  * Sonstiger Arbeitsbereich
* Diözesanverband < Bundesebene
  * Diözesanverband
    * Diözesansmitgliederverwalter*in: 2FA [:layer_and_below_full, :contact_data, :assign_restricted_fee_kinds]
    * Erfasser*in Führungszeugnis: 2FA [:layer_and_below_read, :group_and_below_efz]
    * Kassenprüfer*in: []
    * Stammeskompass-Moderator*in: []
    * Diözesansmitarbeiter*in: []
    * Juleica-Inhaber*in: []
    * Materialwart*in: []
    * Bundesdelegierte*r: []
    * Ersatz-Bundesdelegierte*r: []
    * Bundeslager Unterlagerleiter*in: []
    * Bundeslager Unterlagerbereichsleiter*in: []
    * Bundeslager Mitarbeiter*in Unterlager: []
    * Diözesanswahlobmensch: []
    * Zuschussbeauftrage*r: []
  * Diözesansvorstand
    * Diözesansvorsitzende*r: 2FA [:layer_and_below_read, :contact_data]
    * Stv. Diözesansvorsitzende*r: 2FA [:layer_and_below_read, :contact_data]
    * Diözesansschatzmeister*in: 2FA [:layer_and_below_read, :contact_data, :finance, :assign_restricted_fee_kinds]
    * Stv. Diözesansschatzmeister*in: 2FA [:layer_and_below_read, :contact_data, :finance, :assign_restricted_fee_kinds]
    * Empfänger*in Aufnahmeantrag LV Unter18: []
    * Empfänger*in Aufnahmeantrag LV Über18: []
  * Diözesansgeschäftsstelle
    * Diözesansgeschäftsführer*in: 2FA [:layer_and_below_full, :contact_data, :finance]
    * Hauptamtliche Sachbearbeiter*in: 2FA [:layer_and_below_read, :contact_data]
    * Hauptamtliche Referent*in: 2FA [:layer_and_below_read, :contact_data]
    * Hauptamtliche*r: 2FA [:contact_data]
  * Diözesansversammlung
    * Versammlungsleiter*in: []
    * Protokollführer*in: []
    * Techniker*in: []
  * Arbeitsbereiche
  * Stufen
  * Biber
  * Jungpfadfinder*innenstufe
  * Wölflingsstufe
  * Pfadfinder*innenstufe
  * Ranger/Rover-Stufe
  * Erwachsenenarbeit
  * Ausbildung
  * Internationales
  * intakt
  * intakt - Prävention und Intervention
  * intakt - psychische Gesundheit
  * intakt - Macht und Miteinander
  * Öffentlichkeitsarbeit/Medien
  * Politische Bildung/Politik und Gesellschaft
  * IT
  * Findungskommission
  * Rainbow
  * Inklusion
  * Wachstum und Stämme
  * Sonstiger Arbeitsbereich
* Bezirk < Diözesanverband
  * Bezirk
    * Bezirkssprecher*in: 2FA [:layer_and_below_read, :contact_data]
    * Stv. Bezirkssprecher*in: 2FA [:layer_and_below_read, :contact_data]
    * Bezirksschatzmeister*in: 2FA [:layer_and_below_read, :contact_data]
    * Stv. Bezirksschatzmeister*in: 2FA [:layer_and_below_read, :contact_data]
    * Bezirksbeautragte*r: []
    * Erfasser*in Führungszeugnis: 2FA [:group_and_below_efz]
    * Kassenprüfer*in: []
  * Bezirksgeschäftsstelle
    * Hauptamtliche*r: 2FA [:group_read]
  * Bezirksversammlung
    * Versammlungsleiter*in: []
    * Protokollführer*in: []
    * Techniker*in: []
  * Arbeitsbereiche
  * Stufen
  * Biber
  * Jungpfadfinder*innenstufe
  * Wölflingsstufe
  * Pfadfinder*innenstufe
  * Ranger/Rover-Stufe
  * Erwachsenenarbeit
  * Ausbildung
  * Internationales
  * intakt
  * intakt - Prävention und Intervention
  * intakt - psychische Gesundheit
  * intakt - Macht und Miteinander
  * Öffentlichkeitsarbeit/Medien
  * Politische Bildung/Politik und Gesellschaft
  * IT
  * Findungskommission
  * Rainbow
  * Inklusion
  * Wachstum und Stämme
  * Sonstiger Arbeitsbereich
* Stamm < Bezirk, Diözesanverband
  * Stamm
    * Stammesführer*in: [:layer_and_below_read]
    * Stv. Stammesführer*in: [:layer_and_below_read]
    * Stammesschatzmeister*in: [:layer_and_below_read, :finance]
    * Stv. Stammesschatzmeister*in: [:layer_and_below_read, :finance]
    * Empfänger*in Aufnahmeantrag in Stammesführung: []
    * Stammesmitgliederverwalter*in: 2FA [:layer_and_below_full]
    * Erfasser*in Führungszeugnis: 2FA [:layer_and_below_read, :group_and_below_efz]
    * Kassenprüfer*in: []
    * Zuschussbeauftrage*r: []
    * Ansprechperson Bundeslager: []
    * Stammeskämmerer*in: []
    * Materialwart*in: []
    * Ansprechperson Heimvermietung: []
    * Heimwart*in: []
    * Juleica-Inhaber*in: []
    * Stammesbeauftragte*r: []
    * Diözesansdelegierte*r: []
    * Ersatz-Diözesansdelegierte*r: []
    * Bezirksdelegierte*r: []
    * Stammesgeschäftsstelle: []
  * Arbeitsbereiche
    * Stufen
    * Jungpfadfinder*innenstufe
    * Wölflingsstufe
    * Pfadfinder*innenstufe
    * Ranger/Rover-Stufe
    * Erwachsenenarbeit
    * Ausbildung
    * Internationales
    * intakt
    * intakt - Prävention und Intervention
    * intakt - psychische Gesundheit
    * intakt - Macht und Miteinander
    * Öffentlichkeitsarbeit/Medien
    * Politische Bildung/Politik und Gesellschaft
    * IT
    * Findungskommission
    * Rainbow
    * Inklusion
    * Wachstum und Stämme
    * Sonstiger Arbeitsbereich
  * Gruppen
    * Biber
      * Leiter*in: [:group_read]
      * Hilfsleiter*in: [:group_read]
      * Mitglied: []
    * Jungpfadfinder*innen
      * Leiter*in: [:group_read]
      * Hilfsleiter*in: [:group_read]
      * Mitglied: []
    * Wölflinge
      * Leiter*in: [:group_read]
      * Hilfsleiter*in: [:group_read]
      * Mitglied: []
    * Pfadfinder*innen
      * Leiter*in: [:group_read]
      * Hilfsleiter*in: [:group_read]
      * Mitglied: []
    * Rover
      * Leiter*in: [:group_read]
      * Hilfsleiter*in: [:group_read]
      * Mitglied: []
* Global
  * Mitglieder
    * Ordentliche Mitgliedschaft: []
    * Fördermitgliedschaft: []
    * Zweitmitgliedschaft: []
  * Heim/Zeltplatz/Liegenschaft
    * Ansprechperson Vermietung: []
    * Heim-/Hauswart: []
    * Vorstandsmitglied Hausverein: []
  * Gruppierungsspezifisches Gremium
    * Leiter*in: [:group_and_below_full]
    * Mitglied: [:group_read]
  * Förderverein
    * Vorsitzende*r: []
    * Stv. Vorsitzende*r: []
    * Schatzmeister*in: []
    * Geschäftsstelle: []
  * Kontakte
    * Adressverwaltung: [:group_and_below_full]
    * Kontakt: []
  * Global
    * Bezirksbeauftragte*r: [:layer_and_below_read]
    * AK Leiter*in: [:group_and_below_read]
    * AK Mitarbeiter*in: [:group_and_below_read]
    * AK Freie*r Mitarbeiter*in: []
    * Stammesbeauftragte*r: [:layer_and_below_read]
    * AK Leiter*in: [:group_and_below_read]
    * AK Mitarbeiter*in: [:group_and_below_read]
    * AK Freie*r Mitarbeiter*in: []
    * Diözesansbeauftragte*r: [:layer_and_below_read, :contact_data]
    * AK Leiter*in: [:group_and_below_read, :contact_data]
    * AK Mitarbeiter*in: [:group_and_below_read]
    * AK Freie*r Mitarbeiter*in: []
    * Bundesbeauftragte*r: [:layer_and_below_read, :contact_data]
    * AK Leiter*in: [:group_and_below_read, :contact_data]
    * AK Mitarbeiter*in: [:group_and_below_read]
    * AK Freie*r Mitarbeiter*in: []
