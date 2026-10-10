import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/achievements_model.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/urgent_notification_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/notifications/notification_card.dart';
import 'package:nami/presentation/notifications/notification_links.dart';
import 'package:nami/presentation/screens/member_people_page.dart';
import 'package:nami/presentation/screens/nami_ai/nami_ai_chat_page.dart';
import 'package:nami/presentation/screens/nami_ai/nami_ai_paywall_page.dart';
import 'package:nami/presentation/screens/profile_page.dart';
import 'package:nami/presentation/screens/settings_map_page.dart';
import 'package:nami/presentation/screens/settings_page.dart';
import 'package:nami/presentation/screens/settings_qualifikationen_page.dart';
import 'package:nami/presentation/screens/veranstaltungen/veranstaltungen_page.dart';
import 'package:nami/presentation/screens/settings_stufenwechsel_page.dart';
import 'package:nami/presentation/screens/statistics_page.dart';
import 'package:nami/presentation/widgets/abmeldung_hinweis_karte.dart';
import 'package:nami/presentation/widgets/app_bottom_navigation.dart';
import 'package:nami/presentation/widgets/app_lesebreite.dart';
import 'package:nami/presentation/widgets/app_falz.dart';
import 'package:nami/presentation/widgets/app_seitenleiste.dart';
import 'package:nami/presentation/widgets/demo_zugang_sheet.dart';
import 'package:nami/presentation/widgets/logout_flow.dart';
import 'package:nami/presentation/widgets/supporter_backdrop.dart';
import 'package:nami/services/achievement_service.dart';
import 'package:nami/services/app_mode_controller.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/nami_ai/nami_ai_access_service.dart';
import 'package:provider/provider.dart';

class NavigationHomeScreen extends StatefulWidget {
  const NavigationHomeScreen({super.key});

  /// Navigator des Inhaltsbereichs, solange die Shell sichtbar ist.
  /// Unterseiten oeffnen darin neben der Seitenleiste bzw. ueber der unteren
  /// Leiste, die dabei sichtbar bleiben.
  static NavigatorState? get inhaltNavigator =>
      _NavigationHomeScreenState._aktiv?._inhaltKey.currentState;

  /// Schliesst alle Unterseiten im Inhaltsbereich, z. B. nach Modus-Wechsel
  /// oder Reset.
  static void zurueckZumHauptbereich() =>
      inhaltNavigator?.popUntil((route) => route.isFirst);

  @override
  State<NavigationHomeScreen> createState() => _NavigationHomeScreenState();
}

/// Ziel im Schnellzugriff der Seitenleiste. Auf schmalen Fenstern stehen
/// dieselben Ziele in den Einstellungen und oeffnen sich als eigene Seite.
class _Schnellziel {
  const _Schnellziel({
    required this.id,
    required this.ziel,
    required this.route,
    required this.seite,
    this.eintrag,
  });

  final String id;

  /// Feste Nummer des Ziels, siehe [_NavigationHomeScreenState._index].
  final int ziel;

  /// Eintrag im Schnellzugriff; `null` fuer das Profil, das oben steht.
  final AppSeitenleisteEintrag? eintrag;
  final String route;

  /// Seite neben der Seitenleiste, ohne Zurueck-Pfeil.
  final WidgetBuilder seite;
}

/// Merkt sich die Routen des Inhalts-Navigators, damit die Shell beim Auf-
/// und Zuklappen Schnellziele zwischen Seitenleiste und Unterseite verschieben
/// kann.
class _StapelBeobachter extends NavigatorObserver {
  final List<Route<dynamic>> stapel = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stapel.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stapel.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stapel.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : stapel.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      stapel[i] = newRoute;
    }
  }
}

class _NavigationHomeScreenState extends State<NavigationHomeScreen> {
  static _NavigationHomeScreenState? _aktiv;

  /// 0-3: Hauptbereiche, ab 4: Ziele nur der Seitenleiste.
  int _index = 0;
  static const int _karte = 4;
  static const int _qualifikationen = 5;
  static const int _namiAiZiel = 6;
  static const int _profil = 7;
  static const int _veranstaltungen = 8;
  NamiAiAccessDecision _namiAi = const NamiAiAccessDecision(
    state: NamiAiAccessState.hidden,
  );
  final GlobalKey<NavigatorState> _inhaltKey = GlobalKey<NavigatorState>(
    debugLabel: 'shell-inhalt',
  );
  final _StapelBeobachter _stapel = _StapelBeobachter();
  AppNavigationLoggingObserver? _routenLog;

  /// Ob im letzten Aufbau die Seitenleiste sichtbar war.
  bool? _warSeitenleiste;

  /// Route des Ziels, das beim Zuklappen in die Einstellungen gewandert ist.
  String? _zugeklappteRoute;

  /// Rechts geoeffnete Einstellungsseite, solange die Einstellungen
  /// nebeneinander stehen; `null` heisst Profil (bzw. App ohne Anmeldung).
  String? _einstellungAuswahl;

  static const Map<String, String> _einstellungsRouten = {
    SettingsPage.profil: AppRoutes.profile,
    SettingsPage.stamm: AppRoutes.settingsStamm,
    SettingsPage.app: AppRoutes.settingsApp,
    SettingsPage.erscheinungsbild: AppRoutes.settingsAppearance,
    SettingsPage.benachrichtigungen: AppRoutes.settingsNotification,
    SettingsPage.nachrichten: AppRoutes.settingsMessages,
    SettingsPage.rechtliches: AppRoutes.settingsRechtliches,
    SettingsPage.hilfe: AppRoutes.debugTools,
  };

  String _einstellungsWahl(bool profilDa) {
    final wahl = _einstellungAuswahl;
    if (wahl == null || (wahl == SettingsPage.profil && !profilDa)) {
      return profilDa ? SettingsPage.profil : SettingsPage.app;
    }
    return wahl;
  }

  /// Oeffnet eine Seite im Inhaltsbereich, nicht ueber der Navigation.
  Future<void> _unterseite(String route) async {
    await _inhaltKey.currentState?.pushNamed(route);
  }

  /// Rechte Spalte der Einstellungen mit eigenem Navigator: Folgeseiten
  /// (z. B. Altersgrenzen) bleiben in der Spalte.
  Widget _einstellungsDetail(String wahl) {
    final route = _einstellungsRouten[wahl]!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(22)),
        child: Navigator(
          key: ValueKey('einstellungen-$wahl'),
          initialRoute: route,
          onGenerateInitialRoutes: (_, name) => [
            onGenerateRoute(RouteSettings(name: name)),
          ],
          onGenerateRoute: onGenerateRoute,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _aktiv = this;
    unawaited(_ladeNamiAiFreigabe());
  }

  Future<void> _ladeNamiAiFreigabe() async {
    NamiAiAccessDecision entscheidung;
    try {
      entscheidung = await context.read<NamiAiAccessService>().evaluate();
    } catch (_) {
      entscheidung = await NamiAiAccessService().evaluate();
    }
    if (mounted) {
      setState(() => _namiAi = entscheidung);
    }
  }

  /// Der Hinweis auf veraltete Daten verschwindet nach dieser Zeit von
  /// selbst. Gespeicherte Daten sind innerhalb der Datenfrist normal nutzbar.
  static const Duration _syncHinweisDauer = Duration(seconds: 15);
  Timer? _syncHinweisTimer;
  int? _syncHinweisNr;
  int? _ausgeblendeterSyncHinweisNr;

  @override
  void dispose() {
    if (identical(_aktiv, this)) {
      _aktiv = null;
    }
    _syncHinweisTimer?.cancel();
    super.dispose();
  }

  /// Zeigt den Hinweis je Fehlschlag fuer [_syncHinweisDauer].
  bool _zeigtSyncHinweis(ArbeitskontextModel arbeitskontextModel) {
    if (!arbeitskontextModel.hasStaleDataWarning) {
      return false;
    }
    final nr = arbeitskontextModel.fehlermeldungNr;
    if (_ausgeblendeterSyncHinweisNr == nr) {
      return false;
    }
    if (_syncHinweisNr != nr) {
      _syncHinweisNr = nr;
      _syncHinweisTimer?.cancel();
      _syncHinweisTimer = Timer(_syncHinweisDauer, () {
        if (mounted) {
          setState(() => _ausgeblendeterSyncHinweisNr = nr);
        }
      });
    }
    return true;
  }

  static const List<String> _tabIds = <String>[
    'members',
    'statistics',
    'stage_change',
    'settings',
  ];

  bool _isDemo(BuildContext context) =>
      context.read<AppModeController?>()?.isDemo ?? false;

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthSessionModel>();
    final arbeitskontextModel = context.watch<ArbeitskontextModel>();
    final urgentNotification = _currentUrgentNotification(context);
    if (authModel.state == AuthState.signedOut &&
        (_index != 0 || _stapel.stapel.length > 1)) {
      // Nach dem Abmelden zeigt die Mitgliederliste den Anmeldebildschirm,
      // statt dass die Person auf einem leeren Tab zurueckbleibt.
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _inhaltKey.currentState?.popUntil((route) => route.isFirst),
      );
    }
    final t = AppLocalizations.of(context);
    final seitenleiste = AppSeitenleiste.sichtbar(
      MediaQuery.sizeOf(context).width,
    );
    final schnellziele = _schnellziele(context, t);
    _passeAnFensterAn(seitenleiste, schnellziele);
    Widget body;
    switch (_index) {
      case 0:
        body = _buildProtectedBody(
          context,
          readyBody: const MemberPeoplePage(),
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        );
        break;
      case 1:
        body = _buildProtectedBody(
          context,
          readyBody: const StatisticsPage(),
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        );
        break;
      case 2:
        body = _buildProtectedBody(
          context,
          readyBody: const SettingsStufenwechselPage(showAppBar: false),
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        );
        break;
      case 3:
        // Mit Seitenleiste stehen Liste und gewaehlte Seite nebeneinander,
        // sonst oeffnen die Seiten im Inhaltsbereich.
        final profilDa = _isProfileAvailable(authModel);
        final wahl = _einstellungsWahl(profilDa);
        VoidCallback oeffne(String eintrag) => seitenleiste
            ? () => setState(() => _einstellungAuswahl = eintrag)
            : () => _unterseite(_einstellungsRouten[eintrag]!);
        body = SettingsPage(
          onStammSettings: oeffne(SettingsPage.stamm),
          onAppSettings: oeffne(SettingsPage.app),
          onAppearanceSettings: oeffne(SettingsPage.erscheinungsbild),
          onMessages: seitenleiste
              ? oeffne(SettingsPage.nachrichten)
              : () => _unterseite(AppRoutes.settingsMessages),
          onRechtliches: oeffne(SettingsPage.rechtliches),
          onMapSettings: () => _unterseite(AppRoutes.settingsMap),
          onQualifikationen: () =>
              _unterseite(AppRoutes.settingsQualifikationen),
          onVeranstaltungen: () => _unterseite(AppRoutes.veranstaltungen),
          onNamiAi: () => _unterseite(AppRoutes.namiAiChat),
          onNamiAiPaywall: () => _unterseite(AppRoutes.namiAiPaywall),
          onProfile: profilDa ? oeffne(SettingsPage.profil) : null,
          onExitDemo: _isDemo(context)
              ? context.read<AppModeController>().exitDemo
              : null,
          demoZugang: context.read<AppModeController?>()?.demoZugang,
          // Die Debug-Tools wirken auf die echte Installation.
          onDebugTools: _isDemo(context) ? null : oeffne(SettingsPage.hilfe),
          onNotificationSettings: oeffne(SettingsPage.benachrichtigungen),
          // Mit Seitenleiste steht der Schnellzugriff dort.
          zeigeSchnellzugriff: !seitenleiste,
          detail: seitenleiste ? _einstellungsDetail(wahl) : null,
          ausgewaehlt: seitenleiste ? wahl : null,
        );
        break;
      default:
        body = const MemberPeoplePage();
    }

    final schnellziel = _schnellziel(_index, schnellziele);
    final inhalt = schnellziel != null
        ? schnellziel.seite(context)
        : _buildMainTabShell(
            context,
            content: body,
            urgentNotification: urgentNotification,
            authModel: authModel,
            arbeitskontextModel: arbeitskontextModel,
            // Die Einstellungen bleiben ohne Sync- und Lade-Banner.
            showStatusBanners: _index != 3,
          );

    _routenLog ??= AppNavigationLoggingObserver(
      logger: context.read<LoggerService>(),
    );
    final hauptbereiche = AppBottomNavigation.hauptbereiche(t);
    // Unterseiten oeffnen im Inhaltsbereich, Seitenleiste und untere Leiste
    // bleiben sichtbar. Zurueck (Android) schliesst zuerst die Unterseite.
    final inhaltsbereich = NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => _inhaltKey.currentState?.maybePop(),
      child: Navigator(
        key: _inhaltKey,
        observers: [_stapel, _routenLog!],
        pages: [
          MaterialPage<void>(
            key: const ValueKey('hauptbereich'),
            name: Navigator.defaultRouteName,
            child: inhalt,
          ),
        ],
        onDidRemovePage: (_) {},
        onGenerateRoute: onGenerateRoute,
      ),
    );

    final leistenbreite = AppSeitenleiste.breiteFuer(
      MediaQuery.sizeOf(context).width,
    );
    return Scaffold(
      // Der Inhalt behaelt seinen Zustand, wenn die Seitenleiste beim Auf-
      // oder Zuklappen erscheint oder verschwindet.
      body: Row(
        children: [
          if (seitenleiste)
            AppSeitenleiste(
              profil: _seitenleistenProfil(context, authModel),
              oben: hauptbereiche.sublist(0, 3),
              schnellzugriff: [for (final z in schnellziele) ?z.eintrag],
              unten: hauptbereiche.sublist(3),
              ausgewaehlt: _index,
              breite: leistenbreite,
              onAuswahl: (i) => _wechsle(i, schnellziele),
            ),
          Expanded(
            key: const ValueKey('shell-inhalt'),
            child: AppFalzBereich.fuer(
              context,
              versatz: seitenleiste ? leistenbreite : 0,
              child: inhaltsbereich,
            ),
          ),
        ],
      ),
      bottomNavigationBar: seitenleiste
          ? null
          : AppBottomNavigation(
              currentIndex: _index,
              onTap: (i) => _wechsle(i, schnellziele),
            ),
    );
  }

  /// Verschiebt beim Auf- und Zuklappen (Duo, Split View) ein Schnellziel
  /// zwischen Seitenleiste und Unterseite der Einstellungen.
  void _passeAnFensterAn(bool seitenleiste, List<_Schnellziel> schnellziele) {
    final war = _warSeitenleiste;
    _warSeitenleiste = seitenleiste;
    if (_index >= _tabIds.length) {
      final ziel = _schnellziel(_index, schnellziele);
      if (!seitenleiste || ziel == null) {
        // Ohne Seitenleiste gibt es das Ziel nur als Unterseite der
        // Einstellungen; ist es weggefallen, bleiben die Einstellungen.
        _index = 3;
        if (ziel != null) {
          _zugeklappteRoute = ziel.route;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navigator = _inhaltKey.currentState;
            navigator?.popUntil((route) => route.isFirst);
            navigator?.pushNamed(ziel.route);
          });
        }
      }
      return;
    }
    if (war == false && seitenleiste && _index == 3) {
      // Liegt in den Einstellungen nur ein Schnellziel offen, wird es wieder
      // ein Ziel der Seitenleiste.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final stapel = _stapel.stapel;
        if (!mounted || stapel.length != 2 || _index != 3) {
          return;
        }
        final name = stapel.last.settings.name;
        final ziel = schnellziele.where((z) => z.route == name).firstOrNull;
        final eintrag = _einstellungsRouten.entries
            .where((e) => e.value == name)
            .firstOrNull;
        if (ziel == null && eintrag == null) {
          return;
        }
        // Was die Seitenleiste beim Zuklappen abgegeben hat, geht dorthin
        // zurueck; andere Einstellungsseiten oeffnen rechts daneben.
        final zurueckInLeiste =
            ziel != null && (eintrag == null || name == _zugeklappteRoute);
        _zugeklappteRoute = null;
        _inhaltKey.currentState?.removeRoute(stapel.last);
        setState(() {
          if (zurueckInLeiste) {
            _index = ziel.ziel;
          } else {
            _einstellungAuswahl = eintrag!.key;
          }
        });
      });
    }
  }

  _Schnellziel? _schnellziel(int index, List<_Schnellziel> schnellziele) =>
      schnellziele.where((z) => z.ziel == index).firstOrNull;

  AppSeitenleisteProfil? _seitenleistenProfil(
    BuildContext context,
    AuthSessionModel authModel,
  ) {
    final profile = authModel.profile;
    if (profile == null || !_isProfileAvailable(authModel)) {
      return null;
    }
    return AppSeitenleisteProfil(
      name: profile.secondaryDisplayName ?? profile.primaryDisplayName,
      stamm: context
          .watch<ArbeitskontextModel>()
          .readModel
          ?.arbeitskontext
          .aktiverLayer
          .name,
      badge: context.watch<AppearanceModel?>()?.badge,
      ziel: _profil,
    );
  }

  /// Profil, Karte, Qualifikationen, Kurse & Veranstaltungen und NaMi AI
  /// (sofern sichtbar), wie im Schnellzugriff der Einstellungen ohne die
  /// Platzhalter.
  List<_Schnellziel> _schnellziele(BuildContext context, AppLocalizations t) {
    final qualiGesperrt =
        context.watch<AppearanceModel?>()?.access.qualifikationenFrei == false;
    final authModel = context.watch<AuthSessionModel>();
    return [
      if (_isProfileAvailable(authModel))
        _Schnellziel(
          id: 'profile',
          ziel: _profil,
          route: AppRoutes.profile,
          seite: (_) => Builder(
            builder: (context) => ProfilePage(
              achievements:
                  context.watch<AchievementsModel?>()?.achievements ?? const [],
              onAchievements: () =>
                  Navigator.pushNamed(context, AppRoutes.achievements),
            ),
          ),
        ),
      _Schnellziel(
        id: 'map',
        ziel: _karte,
        eintrag: AppSeitenleisteEintrag(
          icon: Icons.map_outlined,
          label: t.t('settings_map'),
          ziel: _karte,
        ),
        route: AppRoutes.settingsMap,
        seite: (_) => const SettingsMapPage(zeigeZurueck: false),
      ),
      _Schnellziel(
        id: 'qualifications',
        ziel: _qualifikationen,
        eintrag: AppSeitenleisteEintrag(
          icon: Icons.verified_outlined,
          label: t.t('quali_titel'),
          ziel: _qualifikationen,
          gesperrt: qualiGesperrt,
        ),
        route: AppRoutes.settingsQualifikationen,
        seite: (_) => const SettingsQualifikationenPage(),
      ),
      _Schnellziel(
        id: 'events',
        ziel: _veranstaltungen,
        eintrag: AppSeitenleisteEintrag(
          icon: Icons.event_outlined,
          label: t.t('veranstaltung_titel'),
          ziel: _veranstaltungen,
        ),
        route: AppRoutes.veranstaltungen,
        seite: (_) => const VeranstaltungenPage(),
      ),
      if (!_namiAi.isHidden)
        _Schnellziel(
          id: 'nami_ai',
          ziel: _namiAiZiel,
          eintrag: AppSeitenleisteEintrag(
            icon: Icons.auto_awesome,
            label: 'NaMi AI',
            ziel: _namiAiZiel,
          ),
          route: _namiAi.isEnabled
              ? AppRoutes.namiAiChat
              : AppRoutes.namiAiPaywall,
          seite: (_) => _namiAi.isEnabled
              ? const NamiAiChatPage()
              : const NamiAiPaywallPage(),
        ),
    ];
  }

  String _zielId(int index, List<_Schnellziel> schnellziele) =>
      index < _tabIds.length
      ? _tabIds[index]
      : _schnellziel(index, schnellziele)?.id ?? 'unknown';

  void _wechsle(int i, List<_Schnellziel> schnellziele) {
    // Ein Tipp auf einen Bereich fuehrt immer zu dessen Startseite.
    _inhaltKey.currentState?.popUntil((route) => route.isFirst);
    if (i == _index) {
      return;
    }
    final logger = context.read<LoggerService>();
    final previousTab = _zielId(_index, schnellziele);
    final nextTab = _zielId(i, schnellziele);
    logger.logNavigationAction(
      'tab_switch',
      fromRoute: previousTab,
      toRoute: nextTab,
    );
    if (nextTab == 'statistics') {
      context.read<AchievementService>().recordDaily(
        AchievementIds.statisticsOpened,
      );
    }
    setState(() => _index = i);
  }

  PullNotification? _currentUrgentNotification(BuildContext context) {
    if (_index >= 3) {
      return null;
    }
    return context.watch<UrgentNotificationModel>().notification;
  }

  Widget _buildMainTabShell(
    BuildContext context, {
    required Widget content,
    required PullNotification? urgentNotification,
    required AuthSessionModel authModel,
    required ArbeitskontextModel arbeitskontextModel,
    bool showStatusBanners = true,
  }) {
    final showsStaleDataWarning =
        showStatusBanners && _zeigtSyncHinweis(arbeitskontextModel);
    // Laufende Syncs zeigt nur der globale Ladebalken (GlobalLoadingTopBar);
    // die Schritt-Checkliste erscheint ausschliesslich im Vollbild-Platzhalter
    // beim allerersten Laden (_buildPlaceholder).
    final showsTopBanner = showsStaleDataWarning;
    // Die Header-Flaeche der Seite laeuft bis hinter Safe Area und Banner;
    // die Unterkante meldet der AppPageHeader der jeweiligen Seite.
    final backdropBackground = context.watch<AppearanceModel?>()?.background;
    return SupporterBackdrop(
      background: backdropBackground,
      child: Column(
        children: [
          if (urgentNotification != null)
            SafeArea(
              bottom: false,
              child: AppLesebreiteBox(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _UrgentBanner(notification: urgentNotification),
                ),
              ),
            ),
          if (showsStaleDataWarning)
            SafeArea(
              bottom: false,
              top: urgentNotification == null,
              child: _StaleDataWarningBanner(
                onRetry: () => arbeitskontextModel.refreshFromRemote(
                  session: authModel.session,
                  profile: authModel.profile,
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              top: urgentNotification == null && !showsTopBanner,
              bottom: false,
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  /// Das Profil hängt nur an der Anmeldung. Auch wenn der Arbeitskontext
  /// nicht geladen werden kann, bleibt es offen, damit man sich abmelden
  /// kann.
  bool _isProfileAvailable(AuthSessionModel authModel) {
    final state = authModel.state;
    return state == AuthState.signedIn || state == AuthState.unlockRequired;
  }

  Widget _buildProtectedBody(
    BuildContext context, {
    required Widget readyBody,
    required AuthSessionModel authModel,
    required ArbeitskontextModel arbeitskontextModel,
  }) {
    final placeholder = _buildPlaceholder(
      context,
      authModel: authModel,
      arbeitskontextModel: arbeitskontextModel,
    );
    return placeholder ?? readyBody;
  }

  Widget? _buildPlaceholder(
    BuildContext context, {
    required AuthSessionModel authModel,
    required ArbeitskontextModel arbeitskontextModel,
  }) {
    final t = AppLocalizations.of(context);
    switch (authModel.state) {
      case AuthState.initializing:
      case AuthState.authenticating:
        return _ShellStatusView(
          title: t.t('nav_auth_preparing_title'),
          message: t.t('nav_auth_preparing_body'),
          child: CircularProgressIndicator(),
        );
      case AuthState.reloginRequired:
        return _ShellStatusView(
          title: t.t('auth_relogin_title'),
          message: t.t('auth_relogin_body'),
          errorMessage: authModel.errorMessage,
          child: FilledButton.icon(
            onPressed: authModel.isConfigured ? authModel.signIn : null,
            icon: const Icon(Icons.login),
            label: Text(t.t('auth_login_action')),
          ),
        );
      case AuthState.signedOut:
      case AuthState.error:
        return _ShellStatusView(
          title: t.t('auth_login_title'),
          message: authModel.isConfigured
              ? t.t('auth_login_body')
              : t.t('auth_not_configured_body'),
          errorMessage: authModel.errorMessage,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (authModel.logoutReason == LogoutReason.keineBerechtigung) ...[
                const AbmeldungHinweisKarte(),
                const SizedBox(height: 20),
              ] else if (authModel.logoutReason ==
                  LogoutReason.datenAbgelaufen) ...[
                AbmeldungHinweisKarte.datenAbgelaufen(
                  verloren: authModel.verloreneAenderungen,
                ),
                const SizedBox(height: 20),
              ] else if (authModel.anmeldungUnterbrochen) ...[
                const AbmeldungHinweisKarte.anmeldungUnterbrochen(),
                const SizedBox(height: 20),
              ],
              _LoginActions(
                onSignIn: authModel.isConfigured ? authModel.signIn : null,
              ),
            ],
          ),
        );
      case AuthState.unlockRequired:
      case AuthState.signedIn:
        // Ohne geladene Daten fuehrt nur eine Neuanmeldung weiter; Laden und
        // Wiederholen enden sonst sofort wieder an der abgelaufenen Anmeldung.
        if (authModel.state == AuthState.signedIn &&
            (authModel.requiresInteractiveLogin ||
                authModel.isNeuanmeldungAktiv) &&
            (arbeitskontextModel.arbeitskontext == null ||
                arbeitskontextModel.hasError)) {
          return _ShellStatusView(
            title: t.t('auth_relogin_title'),
            message: t.t('auth_neuanmeldung_noetig_body'),
            errorMessage: authModel.errorMessage,
            child: _NeuanmeldungAktionen(authModel: authModel),
          );
        }
        if (arbeitskontextModel.arbeitskontext == null &&
            (arbeitskontextModel.status == ArbeitskontextStatus.initial ||
                arbeitskontextModel.isLoading)) {
          return _ShellStatusView(
            title: t.t('nav_work_context_loading_title'),
            message: t.t('nav_work_context_loading_body'),
            child: _ArbeitskontextLoadingChecklist(
              steps: arbeitskontextModel.loadingSteps,
            ),
          );
        }
        if (arbeitskontextModel.isUnauthorized) {
          return _ShellStatusView(
            title: ArbeitskontextModel.unauthorizedMessage,
            message: t.t('nav_work_context_unauthorized_body'),
            errorMessage: arbeitskontextModel.errorMessage,
            child: FilledButton.icon(
              onPressed: () => runLogoutFlow(context),
              icon: const Icon(Icons.logout),
              label: Text(t.t('logout')),
            ),
          );
        }
        if (arbeitskontextModel.hasError) {
          return _ShellStatusView(
            title: t.t('nav_work_context_error_title'),
            message: t.t('nav_work_context_error_body'),
            errorMessage: arbeitskontextModel.errorMessage,
            child: _FehlerAktionen(
              onRetry: () =>
                  _retryArbeitskontext(authModel, arbeitskontextModel),
            ),
          );
        }
        if (arbeitskontextModel.arbeitskontext == null &&
            !authModel.dataSyncStatus.hasValidLocalData) {
          return _ShellStatusView(
            title: t.t('nav_work_context_error_title'),
            message: t.t('nav_work_context_error_body'),
            errorMessage: authModel.errorMessage,
            child: _FehlerAktionen(
              onRetry: () => _retryInitialDataLoad(
                authModel: authModel,
                arbeitskontextModel: arbeitskontextModel,
              ),
            ),
          );
        }

        return null;
    }
  }

  Future<void> _retryArbeitskontext(
    AuthSessionModel authModel,
    ArbeitskontextModel arbeitskontextModel,
  ) async {
    // Ohne Profil (z.B. weil dessen Abruf zuvor fehlgeschlagen ist) kann
    // ArbeitskontextModel.retry() nichts tun - zuerst das Profil erneut
    // laden, bevor der eigentliche Arbeitskontext-Retry versucht wird.
    if (authModel.profile == null) {
      await authModel.ensureProfileLoaded(force: true);
    }
    final profile = authModel.profile;
    if (profile == null) {
      return;
    }
    await arbeitskontextModel.retry(profile);
  }

  Future<void> _retryInitialDataLoad({
    required AuthSessionModel authModel,
    required ArbeitskontextModel arbeitskontextModel,
  }) async {
    await arbeitskontextModel.clearCachedData();
    await authModel.syncHitobitoData(
      force: true,
      trigger: 'initial_data_retry',
      allowMobileDataOverride: true,
      syncMembers: (accessToken) => arbeitskontextModel.syncVollstaendig(
        session: authModel.session,
        profile: authModel.profile,
        allowMobileDataOverride: true,
      ),
    );
  }
}

class _LoginActions extends StatelessWidget {
  const _LoginActions({required this.onSignIn});

  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appModeController = context.read<AppModeController?>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: onSignIn,
          icon: const Icon(Icons.login),
          label: Text(t.t('auth_login_action')),
        ),
        if (appModeController != null) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('demo-start'),
            onPressed: () async {
              final zugang = await DemoZugangSheet.show(context);
              if (zugang != null) {
                await appModeController.enterDemo(zugang);
              }
            },
            icon: const Icon(Icons.visibility_outlined),
            label: Text(t.t('demo_start_action')),
          ),
          const SizedBox(height: 8),
          Text(
            t.t('demo_start_hint'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// „Neu anmelden“ und darunter „Abmelden“, wenn ohne geladene Daten nur eine
/// Neuanmeldung weiterhilft.
class _NeuanmeldungAktionen extends StatelessWidget {
  const _NeuanmeldungAktionen({required this.authModel});

  final AuthSessionModel authModel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final laeuft = authModel.isNeuanmeldungAktiv;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (authModel.anmeldungUnterbrochen) ...[
          const AbmeldungHinweisKarte.anmeldungUnterbrochen(),
          const SizedBox(height: 20),
        ],
        FilledButton.icon(
          key: const Key('shell-neuanmeldung'),
          onPressed: laeuft
              ? null
              : () =>
                    unawaited(authModel.neuAnmelden(trigger: 'shell_relogin')),
          icon: laeuft
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: Text(t.t('auth_neuanmeldung_action')),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('shell-neuanmeldung-logout'),
          onPressed: laeuft ? null : () => runLogoutFlow(context),
          icon: const Icon(Icons.logout),
          label: Text(t.t('logout')),
        ),
      ],
    );
  }
}

/// „Erneut versuchen“ und darunter „Abmelden“: Scheitert der Abruf
/// dauerhaft (z. B. wegen eines Fehlers in Hitobito), kommt man so trotzdem
/// aus dem Fehlerzustand heraus.
class _FehlerAktionen extends StatelessWidget {
  const _FehlerAktionen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(t.t('common_retry')),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('shell-error-logout'),
          onPressed: () => runLogoutFlow(context),
          icon: const Icon(Icons.logout),
          label: Text(t.t('logout')),
        ),
      ],
    );
  }
}

class _ShellStatusView extends StatelessWidget {
  const _ShellStatusView({
    required this.title,
    required this.message,
    required this.child,
    this.errorMessage,
  });

  final String title;
  final String message;
  final Widget child;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StaleDataWarningBanner extends StatelessWidget {
  const _StaleDataWarningBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.sync_problem,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.t('nav_work_context_sync_warning'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            iconSize: 18,
            color: theme.colorScheme.onErrorContainer,
            icon: const Icon(Icons.refresh),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _ArbeitskontextLoadingChecklist extends StatelessWidget {
  const _ArbeitskontextLoadingChecklist({required this.steps});

  final List<ArbeitskontextLoadingStepStatus> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _ArbeitskontextLoadingStepRow(step: step),
          ),
      ],
    );
  }
}

class _ArbeitskontextLoadingStepRow extends StatelessWidget {
  const _ArbeitskontextLoadingStepRow({required this.step});

  final ArbeitskontextLoadingStepStatus step;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const iconSize = 20.0;
    // "Wartet" wird bewusst nicht mit theme.colorScheme.outline eingefaerbt:
    // dieser Farbton ist in Material 3 fuer Raender/Trenner gedacht und in
    // beiden Themes zu kontrastarm fuer Text/Icons.
    final Widget icon = switch (step.state) {
      ArbeitskontextLoadingStepState.done => Icon(
        Icons.check_circle,
        size: iconSize,
        color: theme.colorScheme.primary,
      ),
      ArbeitskontextLoadingStepState.loading => SizedBox(
        width: iconSize,
        height: iconSize,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      ArbeitskontextLoadingStepState.waiting => Icon(
        Icons.circle_outlined,
        size: iconSize,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    };
    final hasDetail = step.detailKey != null;
    final textStyle = theme.textTheme.bodyMedium;
    final dimmed = step.state == ArbeitskontextLoadingStepState.waiting;
    return Padding(
      padding: EdgeInsets.only(left: step.indent ? 28 : 0),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Text(
            t.t(step.labelKey),
            style: textStyle?.copyWith(
              color: dimmed ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
          if (hasDetail) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.t(step.detailKey!, {
                  if (step.detailCount != null) 'count': '${step.detailCount}',
                }),
                textAlign: TextAlign.right,
                style: textStyle?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Urgent-Banner über den Tabs: eine Meldung mit „1 von n“, nach dem
/// Bestätigen rückt die nächste nach.
class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner({required this.notification});

  final PullNotification notification;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = context.watch<UrgentNotificationModel>().count;
    final hatLink = hatMeldungsLink(
      externalLink: notification.externalLink,
      deepLink: notification.deepLink,
    );
    return NotificationCard(
      key: const Key('urgent-banner'),
      notification: notification,
      kopfzeile: count > 1
          ? Row(
              children: [
                Text(
                  t.t('notif_urgent_position', {'n': 1, 'total': count}),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('urgent-banner-show-all'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.settingsMessages),
                  child: Text(t.t('notif_show_all')),
                ),
              ],
            )
          : null,
      onOpenLink: hatLink
          ? () => oeffneMeldungsLink(
              context,
              externalLink: notification.externalLink,
              deepLink: notification.deepLink,
            )
          : null,
      onAcknowledge: () =>
          context.read<UrgentNotificationModel>().acknowledgeCurrent(),
    );
  }
}
