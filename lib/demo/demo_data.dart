import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/teildaten_stand.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/qualifikation/qualifikation.dart';
import 'package:nami/services/app_mode_controller.dart';

import 'demo_staemme.dart';

/// Daten, die Hitobito fuer den gewaehlten [zugang] liefern wuerde.
///
/// Die Rechte der Demo-Profile entsprechen den Rollen in Hitobito. Welche
/// Layer auswaehlbar sind und wo die App startet, leitet die App daraus wie
/// im Echtbetrieb ab. Welche Personen sichtbar sind, bildet [readModel] so
/// nach, wie Hitobito sie fuer diese Rechte zurueckgibt.
class DemoData {
  DemoData(this.zugang, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DemoZugang zugang;
  final DateTime Function() _now;

  AuthProfile get profile => switch (zugang) {
    DemoZugang.stammesvorstand => const AuthProfile(
      namiId: 1061,
      primaryGroupId: DemoBezirk.silberfelsId,
      email: 'johanna.becker@example.org',
      firstName: 'Johanna',
      lastName: 'Becker',
      language: 'de',
      roles: <AuthProfileRole>[
        AuthProfileRole(
          groupId: DemoBezirk.silberfelsId,
          groupName: 'Stamm Silberfels',
          roleName: 'Stammesführer*in',
          roleClass: 'Group::Stamm::Stammesfuehrung',
          permissions: <String>['layer_and_below_read'],
        ),
      ],
    ),
    DemoZugang.leitung => const AuthProfile(
      namiId: 1052,
      primaryGroupId: DemoBezirk.truppKompassId,
      email: 'david.neumann@example.org',
      firstName: 'David',
      lastName: 'Neumann',
      language: 'de',
      roles: <AuthProfileRole>[
        AuthProfileRole(
          groupId: DemoBezirk.truppKompassId,
          groupName: 'Trupp Kompass',
          roleName: 'Leiter*in',
          roleClass: 'Group::StammGruppeJungpfadfinder::Leitung',
          permissions: <String>['group_read'],
        ),
      ],
    ),
    DemoZugang.bezirksvorstand => const AuthProfile(
      namiId: 3001,
      primaryGroupId: DemoBezirk.bezirkId,
      email: 'martin.krause@example.org',
      firstName: 'Martin',
      lastName: 'Krause',
      language: 'de',
      roles: <AuthProfileRole>[
        AuthProfileRole(
          groupId: DemoBezirk.bezirkId,
          groupName: 'Bezirk Silbertal',
          roleName: 'Bezirkssprecher*in',
          roleClass: 'Group::Bezirk::Vorstand',
          permissions: <String>['layer_and_below_read', 'contact_data'],
        ),
      ],
    ),
  };

  AuthSession session() {
    final receivedAt = _now();
    final profil = profile;
    return AuthSession(
      accessToken: 'demo',
      receivedAt: receivedAt,
      expiresAt: receivedAt.add(const Duration(days: 3650)),
      principal: 'demo-${zugang.name}',
      email: profil.email,
      displayName: '${profil.firstName} ${profil.lastName}',
    );
  }

  /// Hitobito liefert alle Gruppen, unabhaengig von den Rechten. Welche Layer
  /// davon relevant sind, entscheidet die App.
  List<HitobitoGroupResource> hitobitoGruppen() {
    return <HitobitoGroupResource>[
      const HitobitoGroupResource(
        id: DemoBezirk.dioezeseId,
        name: DemoBezirk.dioezeseName,
        isLayer: true,
        layerGroupId: DemoBezirk.dioezeseId,
        groupType: 'Group::Dioezese',
      ),
      for (final layer in DemoBezirk.layer) ...[
        HitobitoGroupResource(
          id: layer.id,
          name: layer.name,
          isLayer: true,
          parentId: layer.parentId,
          layerGroupId: layer.id,
          groupType: layer.typ,
        ),
        for (final gruppe in layer.gruppen)
          HitobitoGroupResource(
            id: gruppe.id,
            name: gruppe.name,
            isLayer: false,
            parentId: layer.id,
            layerGroupId: layer.id,
            groupType: gruppe.gruppenTyp,
          ),
      ],
    ];
  }

  ArbeitskontextReadModel readModel({required Arbeitskontext arbeitskontext}) {
    final layer = DemoBezirk.findeLayer(arbeitskontext.aktiverLayer.id);
    if (layer == null) {
      return ArbeitskontextReadModel(
        arbeitskontext: arbeitskontext,
        rolesSindGeladen: true,
      );
    }
    final today = _now();
    final personen = _sichtbarePersonen(layer);
    final personIds = {for (final person in personen) person.personId};
    return ArbeitskontextReadModel(
      arbeitskontext: arbeitskontext,
      rolesSindGeladen: true,
      efzStand: TeildatenStand.geladen,
      efzEinsichtnahmen: efzEinsichtnahmen().where(
        (eintrag) => personIds.contains(eintrag.personId),
      ),
      qualifikationenStand: TeildatenStand.geladen,
      qualifikationen: qualifikationen().where(
        (eintrag) => personIds.contains(eintrag.personId),
      ),
      mitglieder: <Mitglied>[
        for (final person in personen) person.toMitglied(today, layer),
      ],
      gruppen: layer.gruppen,
      mitgliedsZuordnungen: <ArbeitskontextMitgliedsZuordnung>[
        for (final person in personen)
          if (layer.enthaeltGruppe(person.gruppenId))
            ArbeitskontextMitgliedsZuordnung(
              mitgliedsnummer: person.mitgliedsnummer,
              gruppenId: person.gruppenId,
              rollenLabel: person.rollenLabel,
            ),
      ],
    );
  }

  /// Sichtbare Mitglieder eines Layers, z. B. fuer Tests.
  List<Mitglied> mitglieder(int layerId) {
    final layer = DemoBezirk.findeLayer(layerId);
    if (layer == null) {
      return const <Mitglied>[];
    }
    final today = _now();
    return <Mitglied>[
      for (final person in _sichtbarePersonen(layer))
        person.toMitglied(today, layer),
    ];
  }

  /// Fuehrungszeugnisse aller Personen, die der Zugang sehen darf.
  List<EfzEinsichtnahme> efzEinsichtnahmen() {
    final today = _now();
    var id = 1;
    return <EfzEinsichtnahme>[
      for (final layer in DemoBezirk.layer)
        for (final person in _sichtbarePersonen(layer))
          if (DemoBezirk.efzAlterMonate[person.mitgliedsnummer]
              case final alterMonate?)
            EfzEinsichtnahme(
              id: id++,
              personId: person.personId,
              issuedOn: DateTime(
                today.year,
                today.month - alterMonate,
                today.day,
              ),
              einsichtOn: DateTime(
                today.year,
                today.month - alterMonate + 1,
                today.day,
              ),
            ),
    ];
  }

  /// Qualifikationen aller Personen, die der Zugang sehen darf.
  List<Qualifikation> qualifikationen() {
    final today = _now();
    var id = 1;
    return <Qualifikation>[
      for (final layer in DemoBezirk.layer)
        for (final person in _sichtbarePersonen(layer))
          for (final quali
              in DemoBezirk.qualifikationen[person.mitgliedsnummer] ??
                  const <DemoQualifikation>[])
            Qualifikation(
              id: id++,
              personId: person.personId,
              label: quali.label,
              qualifiedAt: DateTime(
                today.year,
                today.month - quali.vorMonaten,
                today.day,
              ),
              finishAt: quali.gueltigJahre == null
                  ? null
                  : DateTime(
                      today.year + quali.gueltigJahre!,
                      today.month - quali.vorMonaten,
                      today.day,
                    ),
              reaktivierbar: quali.reaktivierbar,
            ),
    ];
  }

  /// Bildet die Lesesicht von Hitobito fuer die Rechte des Profils nach:
  /// `layer_read` zeigt den Layer der Rolle, `layer_and_below_read`
  /// zusaetzlich alle Layer darunter, `group_read` nur die Personen der
  /// eigenen Gruppe.
  List<DemoPerson> _sichtbarePersonen(DemoLayer layer) {
    final lesbareGruppen = <int>{};
    for (final rolle in profile.roles) {
      final rollenLayer = _layerIdFuerGruppe(rolle.groupId);
      if (rolle.permissions.contains('layer_read') && rollenLayer == layer.id) {
        return layer.personen;
      }
      if (rolle.permissions.contains('layer_and_below_read') &&
          _istGleichOderDarunter(layer.id, rollenLayer)) {
        return layer.personen;
      }
      if (rolle.permissions.contains('group_read')) {
        lesbareGruppen.add(rolle.groupId);
      }
    }
    return layer.personen
        .where((person) => lesbareGruppen.contains(person.gruppenId))
        .toList(growable: false);
  }

  static int? _layerIdFuerGruppe(int gruppenId) {
    if (gruppenId == DemoBezirk.dioezeseId) {
      return gruppenId;
    }
    for (final layer in DemoBezirk.layer) {
      if (layer.id == gruppenId || layer.enthaeltGruppe(gruppenId)) {
        return layer.id;
      }
    }
    return null;
  }

  static bool _istGleichOderDarunter(int layerId, int? obererLayerId) {
    int? aktuell = layerId;
    while (aktuell != null) {
      if (aktuell == obererLayerId) {
        return true;
      }
      aktuell = DemoBezirk.findeLayer(aktuell)?.parentId;
    }
    return false;
  }
}
