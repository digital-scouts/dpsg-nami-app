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

enum QualifikationenStoryZustand {
  geladen,
  gesperrt,
  ohneEfzRecht,
  nichtSynchronisiert,
  leer,
}

enum QualifikationenStorySeite {
  uebersicht,
  personenEfz,
  personenPraevention,
  auswahl,
  efz,
}

Story settingsQualifikationenStory() => Story(
  name: 'Einstellungen/Qualifikationen/Uebersicht',
  builder: (context) {
    final zustand = context.knobs.options<QualifikationenStoryZustand>(
      label: 'Zustand',
      initial: QualifikationenStoryZustand.geladen,
      options: const [
        Option(label: 'Geladen', value: QualifikationenStoryZustand.geladen),
        Option(
          label: 'Supporter gesperrt',
          value: QualifikationenStoryZustand.gesperrt,
        ),
        Option(
          label: 'Ohne EFZ-Recht',
          value: QualifikationenStoryZustand.ohneEfzRecht,
        ),
        Option(
          label: 'Nicht synchronisiert',
          value: QualifikationenStoryZustand.nichtSynchronisiert,
        ),
        Option(
          label: 'Keine Hitobito-Qualifikation',
          value: QualifikationenStoryZustand.leer,
        ),
      ],
    );
    final seite = context.knobs.options<QualifikationenStorySeite>(
      label: 'Seite',
      initial: QualifikationenStorySeite.uebersicht,
      options: const [
        Option(label: 'Übersicht', value: QualifikationenStorySeite.uebersicht),
        Option(
          label: 'Personen EFZ',
          value: QualifikationenStorySeite.personenEfz,
        ),
        Option(
          label: 'Personen Prävention',
          value: QualifikationenStorySeite.personenPraevention,
        ),
        Option(label: 'Auswahl', value: QualifikationenStorySeite.auswahl),
        Option(
          label: 'Einstellungen EFZ',
          value: QualifikationenStorySeite.efz,
        ),
      ],
    );
    return QualifikationenStoryHost(
      key: ValueKey<String>('${zustand.name}-${seite.name}'),
      zustand: zustand,
      seite: seite,
    );
  },
);

class QualifikationenStoryHost extends StatefulWidget {
  const QualifikationenStoryHost({
    super.key,
    required this.zustand,
    required this.seite,
  });

  final QualifikationenStoryZustand zustand;
  final QualifikationenStorySeite seite;

  @override
  State<QualifikationenStoryHost> createState() =>
      _QualifikationenStoryHostState();
}

class _QualifikationenStoryHostState extends State<QualifikationenStoryHost> {
  final _einstellungen = QualifikationsEinstellungenModel(
    InMemoryQualifikationsEinstellungenRepository(),
  );
  late final AppearanceModel _appearance = AppearanceModel(
    repository: InMemoryAppearanceSettingsRepository(),
    appIconService: FakeAppIconService(),
    access: SchalterSupportAccess(
      widget.zustand == QualifikationenStoryZustand.gesperrt
          ? SupporterTestZugang.keiner
          : SupporterTestZugang.foerderer,
    ),
  );

  @override
  void dispose() {
    _einstellungen.dispose();
    _appearance.dispose();
    super.dispose();
  }

  ArbeitskontextReadModel get _readModel {
    final ohneDaten =
        widget.zustand == QualifikationenStoryZustand.nichtSynchronisiert;
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
        QualifikationenStoryZustand.ohneEfzRecht =>
          TeildatenStand.keineBerechtigung,
        QualifikationenStoryZustand.nichtSynchronisiert =>
          TeildatenStand.unbekannt,
        _ => TeildatenStand.geladen,
      },
      efzEinsichtnahmen: ohneDaten
          ? const []
          : MitgliedEdgeCases.efzEinsichtnahmen,
      qualifikationenStand: ohneDaten
          ? TeildatenStand.unbekannt
          : TeildatenStand.geladen,
      qualifikationen:
          ohneDaten || widget.zustand == QualifikationenStoryZustand.leer
          ? const []
          : MitgliedEdgeCases.qualifikationen,
    );
  }

  @override
  Widget build(BuildContext context) {
    final readModel = _readModel;
    DateTime heute() => MitgliedEdgeCases.heute;
    final seite = switch (widget.seite) {
      QualifikationenStorySeite.uebersicht => SettingsQualifikationenPage(
        readModel: readModel,
        heuteProvider: heute,
      ),
      QualifikationenStorySeite.personenEfz => QualifikationPersonenPage(
        schluessel: QualifikationsSchluessel.efz,
        readModel: readModel,
        heuteProvider: heute,
      ),
      QualifikationenStorySeite.personenPraevention =>
        QualifikationPersonenPage(
          schluessel: QualifikationsSchluessel.hitobito(14),
          readModel: readModel,
          heuteProvider: heute,
        ),
      QualifikationenStorySeite.auswahl => QualifikationenAuswahlPage(
        readModel: readModel,
        heuteProvider: heute,
      ),
      QualifikationenStorySeite.efz => QualifikationEinstellungenPage(
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
