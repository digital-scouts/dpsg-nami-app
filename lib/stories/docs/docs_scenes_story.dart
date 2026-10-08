import 'package:flutter/material.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/demo/demo_services.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/model/bundesstatistik_model.dart';
import 'package:nami/presentation/model/qualifikations_einstellungen_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/notifications/welcome_dialog.dart';
import 'package:nami/presentation/screens/bundesvergleich_page.dart';
import 'package:nami/presentation/screens/hilfe_diagnose_page.dart';
import 'package:nami/presentation/screens/member_edit_page.dart';
import 'package:nami/presentation/screens/profile_page.dart';
import 'package:nami/presentation/screens/settings_app_page.dart';
import 'package:nami/presentation/screens/settings_notification_page.dart';
import 'package:nami/presentation/screens/settings_rechtliches_page.dart';
import 'package:nami/presentation/screens/settings_stamm_page.dart';
import 'package:nami/presentation/screens/statistics_group_detail_page.dart';
import 'package:nami/presentation/statistics/eigene_kachel_editor.dart';
import 'package:nami/presentation/statistics/kachel_katalog_sheet.dart';
import 'package:nami/presentation/statistics/statistik_stamm_ansicht.dart';
import 'package:nami/presentation/widgets/bundesstatistik_einwilligung_dialog.dart';
import 'package:nami/presentation/widgets/demo_zugang_sheet.dart';
import 'package:nami/presentation/widgets/member_detail/member_rollen_tab.dart';
import 'package:nami/presentation/widgets/problem_melden_sheet.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../bundesstatistik_story.dart';
import '../member_edit_resolution_story.dart';
import '../profile_page_story.dart';
import '../settings_qualifikationen_story.dart';
import '../statistics_page_story.dart';
import '../statistik/statistik_kachel_beispiele.dart';
import '../statistik_bearbeiten_story.dart';
import '../store/store_scenes_story.dart';
import '../store/store_showcase_data.dart';

/// Vollbild-Szenen fuer die Screenshots im Nutzerhandbuch (GitHub Pages).
///
/// Wie bei den Store-Szenen sind die Namen stabil:
/// `integration_test/store_screenshots_test.dart` leitet daraus die
/// Dateinamen ab (`Docs/Statistik/Katalog` -> `statistik_katalog.png`).
/// Die Szenen nutzen keine Knobs, damit der Test sie direkt bauen kann.
List<Story> docsSceneStories() => <Story>[
  // Erste Schritte
  _scene('Willkommen', (_) => const _WillkommenScene()),
  _scene('Demo-Zugang', (_) => const _SheetScene(child: DemoZugangSheet())),
  // Arbeitskontext
  _scene('Profil', (_) => const _ProfilScene()),
  // Stufenwechsel
  _scene('Stufenwechsel/Altersgrenzen', (_) => const _AltersgrenzenScene()),
  _scene('Stufenwechsel/Rollen', (_) => const _RollenScene()),
  // Statistik
  _scene(
    'Statistik/Entwicklung',
    (_) => StatisticsPageStoryScene(
      background: storeShowcaseAppearance.background,
      simulateTopInset: false,
      thema: StatistikThema.entwicklung,
    ),
  ),
  _scene(
    'Statistik/Gruppe',
    (_) => StoreSceneApp(
      home: StatisticsGroupDetailPage(
        groupId: '${StoreShowcaseData.gruppen[1].id}',
        debugReadModel: StoreShowcaseData.readModel(),
      ),
    ),
  ),
  _scene(
    'Statistik/Bearbeiten',
    (_) => const StatistikBearbeitenSzene(
      datensatz: StatistikBeispielDatensatz.silberfels,
      bearbeiten: true,
      ruhig: true,
      dark: false,
      textScale: 1,
    ),
  ),
  _scene('Statistik/Katalog', (_) => const _KatalogScene()),
  _scene('Statistik/Eigene Kachel', (_) => const _EigeneKachelScene()),
  _scene(
    'Statistik/Zielwerte',
    (_) => const StoreSceneApp(
      home: StatistikZielwerteSzene(
        datensatz: StatistikBeispielDatensatz.silberfels,
      ),
    ),
  ),
  // Bundesvergleich
  _scene('Bundesvergleich/Einladung', (_) => const _BundesEinladungScene()),
  _scene(
    'Bundesvergleich/Einwilligung',
    (_) => const StoreSceneApp(
      home: Scaffold(
        body: Center(
          child: BundesstatistikEinwilligungDialog(
            stammName: StoreShowcaseData.stammName,
          ),
        ),
      ),
    ),
  ),
  // Qualifikationen
  _scene(
    'Qualifikationen/Uebersicht',
    (_) => const _QualiScene(seite: QualifikationenStorySeite.uebersicht),
  ),
  _scene(
    'Qualifikationen/Personen',
    (_) => const _QualiScene(seite: QualifikationenStorySeite.personenEfz),
  ),
  _scene(
    'Qualifikationen/Einstellungen',
    (_) => const _QualiScene(seite: QualifikationenStorySeite.efz),
  ),
  _scene(
    'Qualifikationen/Gesperrt',
    (_) => const _QualiScene(
      seite: QualifikationenStorySeite.uebersicht,
      zustand: QualifikationenStoryZustand.gesperrt,
    ),
  ),
  _scene('Benachrichtigungen', (_) => const _BenachrichtigungenScene()),
  // Aenderungen
  _scene('Aenderungen/Bearbeiten', (_) => const _BearbeitenScene()),
  _scene(
    'Aenderungen/Problemloesung',
    (context) => memberEditResolutionServerConflictStory().builder(context),
  ),
  // Probleme melden
  _scene(
    'Hilfe',
    (_) => const StorySignedInScope(
      profile: _profil,
      child: StoreSceneApp(
        home: HilfeDiagnosePage(entwicklerFunktionen: false),
      ),
    ),
  ),
  _scene(
    'Problem melden',
    (_) => const _SheetScene(child: ProblemMeldenSheet()),
  ),
  // Datenschutz
  _scene('Datenschutz/App', (_) => const _AppEinstellungenScene()),
  _scene(
    'Datenschutz/Rechtliches',
    (_) => StoreSceneApp(
      home: SettingsRechtlichesPage(
        installationsId: 'q3ZkAbCdEfGh9fA2',
        onOpenUrl: (_) async {},
      ),
    ),
  ),
];

Story _scene(String name, WidgetBuilder builder) =>
    Story(name: 'Docs/$name', builder: builder);

const AuthProfile _profil = AuthProfile(
  namiId: 1022,
  email: 'hanna.albrecht@example.org',
  firstName: 'Hanna',
  lastName: 'Albrecht',
  language: 'de',
  roles: <AuthProfileRole>[
    AuthProfileRole(
      groupId: 11,
      groupName: 'Stamm Musterdorf',
      roleName: 'Vorsitzende*r',
      roleClass: 'Group::Stamm::Vorstand',
      permissions: <String>['layer_and_below_read'],
    ),
    AuthProfileRole(
      groupId: 20,
      groupName: 'Bezirk Rhein',
      roleName: 'Mitglied Bezirksleitung',
      roleClass: 'Group::Bezirk::Leitung',
      permissions: <String>['layer_read'],
    ),
  ],
);

class _WillkommenScene extends StatelessWidget {
  const _WillkommenScene();

  @override
  Widget build(BuildContext context) {
    return StoreSceneApp(
      home: WillkommenStepper(
        startSchritt: 0,
        optionen: WillkommenOptionen(
          biometrieVerfuegbar: true,
          biometrieAktiv: false,
          benachrichtigungenErlaubt: null,
          analyseAktiv: false,
          keineMobilenDaten: false,
          themeMode: ThemeMode.system,
          onBiometrieAktivieren: () async => true,
          onBenachrichtigungenAktivieren: () async => true,
          onAnalyseAendern: (_) async {},
          onKeineMobilenDatenAendern: (_) async {},
          onThemeAendern: (_) async {},
          onRechtliches: () {},
          onSystemEinstellungen: () {},
        ),
      ),
    );
  }
}

/// Bottom-Sheet am unteren Rand, wie es in der App aufgeht.
class _SheetScene extends StatelessWidget {
  const _SheetScene({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StoreSceneApp(
      home: Scaffold(
        backgroundColor: Colors.black54,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            elevation: 2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilScene extends StatelessWidget {
  const _ProfilScene();

  @override
  Widget build(BuildContext context) {
    return const StorySignedInScope(
      profile: _profil,
      child: StoreSceneApp(home: ProfilePage()),
    );
  }
}

class _AltersgrenzenScene extends StatelessWidget {
  const _AltersgrenzenScene();

  @override
  Widget build(BuildContext context) {
    final heute = DateTime.now();
    return StoreSceneApp(
      home: SettingsStammPage(
        addressRepository: InMemoryAddressSettingsRepository(),
        initialAltersgrenzen: StufenDefaults.build(),
        initialStufenwechsel: DateTime(heute.year + 1, 9, 1),
        onSaveAltersgrenzen: (_) {},
        onStufenwechselChanged: (_) {},
      ),
    );
  }
}

class _RollenScene extends StatelessWidget {
  const _RollenScene();

  @override
  Widget build(BuildContext context) {
    final heute = DateTime.now();
    // Greta Winter (Woelfling, ueberfaellig): zeigt den naechsten Wechsel.
    final mitglied = StoreShowcaseData.mitglieder(
      today: heute,
    ).firstWhere((m) => m.mitgliedsnummer == '1016');
    return StoreSceneApp(
      home: Scaffold(
        appBar: AppBar(title: Text('${mitglied.vorname} ${mitglied.nachname}')),
        body: MemberRollenTab(
          mitglied: mitglied,
          heute: heute,
          aktiverLayerName: StoreShowcaseData.stammName,
        ),
      ),
    );
  }
}

class _KatalogScene extends StatelessWidget {
  const _KatalogScene();

  @override
  Widget build(BuildContext context) {
    const datensatz = StatistikBeispielDatensatz.silberfels;
    return StoreSceneApp(
      home: Scaffold(
        body: SafeArea(
          child: KachelKatalogSheet(
            daten: StatistikKachelBeispiele.daten(datensatz),
            readModel: datensatz.readModel(StatistikKachelBeispiele.heute),
            neueId: () => 'docs',
          ),
        ),
      ),
    );
  }
}

class _EigeneKachelScene extends StatelessWidget {
  const _EigeneKachelScene();

  @override
  Widget build(BuildContext context) {
    const datensatz = StatistikBeispielDatensatz.silberfels;
    return StoreSceneApp(
      home: Scaffold(
        body: SafeArea(
          child: EigeneKachelEditor(
            readModel: datensatz.readModel(StatistikKachelBeispiele.heute),
            neueId: () => 'docs',
            onZurueck: () {},
            onFertig: (_) {},
          ),
        ),
      ),
    );
  }
}

class _BundesEinladungScene extends StatelessWidget {
  const _BundesEinladungScene();

  @override
  Widget build(BuildContext context) {
    return StoreSceneApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Bundesweiter Vergleich')),
        body: BundesvergleichView(
          status: BundesstatistikStatus.keineEinwilligung,
          hatEinwilligung: false,
          aggregat: null,
          eigeneKennzahlen: bundesstatistikBeispielKennzahlen,
          einwilligungAm: null,
          zuletztGesendet: null,
          onEinwilligungAendern: (_) {},
        ),
      ),
    );
  }
}

class _QualiScene extends StatelessWidget {
  const _QualiScene({
    required this.seite,
    this.zustand = QualifikationenStoryZustand.geladen,
  });

  final QualifikationenStorySeite seite;
  final QualifikationenStoryZustand zustand;

  @override
  Widget build(BuildContext context) {
    return StoreSceneApp(
      home: QualifikationenStoryHost(zustand: zustand, seite: seite),
    );
  }
}

class _BenachrichtigungenScene extends StatelessWidget {
  const _BenachrichtigungenScene();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<QualifikationsEinstellungenModel>(
      create: (_) => QualifikationsEinstellungenModel(
        InMemoryQualifikationsEinstellungenRepository(),
      ),
      child: StoreSceneApp(
        home: SettingsNotificationPage(
          geburstagsbenachrichtigungStufen: const {
            Stufe.woelfling,
            Stufe.jungpfadfinder,
            Stufe.leitung,
          },
          readModel: StoreShowcaseData.readModel(),
        ),
      ),
    );
  }
}

class _BearbeitenScene extends StatelessWidget {
  const _BearbeitenScene();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthSessionModel?>.value(value: null),
        Provider<MemberEditModel?>.value(value: null),
      ],
      child: StoreSceneApp(
        home: MemberEditPage(mitglied: StoreShowcaseData.featuredMitglied()),
      ),
    );
  }
}

class _AppEinstellungenScene extends StatelessWidget {
  const _AppEinstellungenScene();

  @override
  Widget build(BuildContext context) {
    return StoreSceneApp(
      home: AppSettingsPage(
        analyticsEnabled: false,
        biometricLockEnabled: true,
        memberListSearchResultHighlightEnabled: true,
        languageCode: 'de',
        onAnalyticsChanged: (_) {},
        onBiometricLockChanged: (_) {},
        onMemberListSearchResultHighlightChanged: (_) {},
        onLanguageChanged: (_) {},
      ),
    );
  }
}
