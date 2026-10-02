import 'package:flutter/material.dart';
import 'package:nami/data/appearance/in_memory_appearance_settings_repository.dart';
import 'package:nami/demo/demo_services.dart';
import 'package:nami/domain/appearance/support_access.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/teildaten_stand.dart';
import 'package:nami/domain/qualifikation/qualifikations_einstellungen.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/model/qualifikations_einstellungen_model.dart';
import 'package:nami/presentation/screens/qualifikationen/qualifikation_einstellungen_page.dart';
import 'package:nami/presentation/screens/qualifikationen/qualifikation_personen_page.dart';
import 'package:nami/presentation/screens/qualifikationen/qualifikationen_auswahl_page.dart';
import 'package:nami/presentation/screens/settings_qualifikationen_page.dart';
import 'package:nami/services/app_icon_service.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import 'support/mitglied_edge_cases.dart';

enum _Zustand { geladen, gesperrt, ohneEfzRecht, nichtSynchronisiert, leer }

enum _Seite { uebersicht, personenEfz, personenPraevention, auswahl, efz }

Story settingsQualifikationenStory() => Story(
  name: 'Einstellungen/Qualifikationen/Uebersicht',
  builder: (context) {
    final zustand = context.knobs.options<_Zustand>(
      label: 'Zustand',
      initial: _Zustand.geladen,
      options: const [
        Option(label: 'Geladen', value: _Zustand.geladen),
        Option(label: 'Supporter gesperrt', value: _Zustand.gesperrt),
        Option(label: 'Ohne EFZ-Recht', value: _Zustand.ohneEfzRecht),
        Option(
          label: 'Nicht synchronisiert',
          value: _Zustand.nichtSynchronisiert,
        ),
        Option(label: 'Keine Hitobito-Qualifikation', value: _Zustand.leer),
      ],
    );
    final seite = context.knobs.options<_Seite>(
      label: 'Seite',
      initial: _Seite.uebersicht,
      options: const [
        Option(label: 'Übersicht', value: _Seite.uebersicht),
        Option(label: 'Personen EFZ', value: _Seite.personenEfz),
        Option(label: 'Personen Prävention', value: _Seite.personenPraevention),
        Option(label: 'Auswahl', value: _Seite.auswahl),
        Option(label: 'Einstellungen EFZ', value: _Seite.efz),
      ],
    );
    return _QualifikationenStoryHost(
      key: ValueKey<String>('${zustand.name}-${seite.name}'),
      zustand: zustand,
      seite: seite,
    );
  },
);

class _QualifikationenStoryHost extends StatefulWidget {
  const _QualifikationenStoryHost({
    super.key,
    required this.zustand,
    required this.seite,
  });

  final _Zustand zustand;
  final _Seite seite;

  @override
  State<_QualifikationenStoryHost> createState() =>
      _QualifikationenStoryHostState();
}

class _QualifikationenStoryHostState extends State<_QualifikationenStoryHost> {
  final _einstellungen = QualifikationsEinstellungenModel(
    InMemoryQualifikationsEinstellungenRepository(),
  );
  late final AppearanceModel _appearance = AppearanceModel(
    repository: InMemoryAppearanceSettingsRepository(),
    appIconService: FakeAppIconService(),
    access: SchalterSupportAccess(
      freigeschaltet: widget.zustand != _Zustand.gesperrt,
    ),
  );

  @override
  void dispose() {
    _einstellungen.dispose();
    _appearance.dispose();
    super.dispose();
  }

  ArbeitskontextReadModel get _readModel {
    final ohneDaten = widget.zustand == _Zustand.nichtSynchronisiert;
    return ArbeitskontextReadModel(
      arbeitskontext: Arbeitskontext(
        aktiverLayer: const ArbeitskontextLayer(
          id: 11,
          name: MitgliedEdgeCases.stamm,
        ),
        verfuegbareLayer: const <ArbeitskontextLayer>[],
      ),
      mitglieder: MitgliedEdgeCases.alle.values.toList(growable: false),
      efzStand: switch (widget.zustand) {
        _Zustand.ohneEfzRecht => TeildatenStand.keineBerechtigung,
        _Zustand.nichtSynchronisiert => TeildatenStand.unbekannt,
        _ => TeildatenStand.geladen,
      },
      efzEinsichtnahmen: ohneDaten
          ? const []
          : MitgliedEdgeCases.efzEinsichtnahmen,
      qualifikationenStand: ohneDaten
          ? TeildatenStand.unbekannt
          : TeildatenStand.geladen,
      qualifikationen: ohneDaten || widget.zustand == _Zustand.leer
          ? const []
          : MitgliedEdgeCases.qualifikationen,
    );
  }

  @override
  Widget build(BuildContext context) {
    final readModel = _readModel;
    DateTime heute() => MitgliedEdgeCases.heute;
    final seite = switch (widget.seite) {
      _Seite.uebersicht => SettingsQualifikationenPage(
        readModel: readModel,
        heuteProvider: heute,
      ),
      _Seite.personenEfz => QualifikationPersonenPage(
        schluessel: QualifikationsSchluessel.efz,
        readModel: readModel,
        heuteProvider: heute,
      ),
      _Seite.personenPraevention => QualifikationPersonenPage(
        schluessel: QualifikationsSchluessel.hitobito(14),
        readModel: readModel,
        heuteProvider: heute,
      ),
      _Seite.auswahl => QualifikationenAuswahlPage(
        readModel: readModel,
        heuteProvider: heute,
      ),
      _Seite.efz => QualifikationEinstellungenPage(
        schluessel: QualifikationsSchluessel.efz,
        readModel: readModel,
        heuteProvider: heute,
      ),
    };
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<QualifikationsEinstellungenModel>.value(
          value: _einstellungen,
        ),
        ChangeNotifierProvider<AppearanceModel>.value(value: _appearance),
      ],
      child: SizedBox.expand(child: seite),
    );
  }
}
