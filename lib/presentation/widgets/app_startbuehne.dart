import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/auth/auth_state.dart';
import '../../l10n/app_localizations.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';
import '../screens/auth_gate_screen.dart';
import '../theme/app_bewegung.dart';
import '../theme/theme.dart';
import 'app_sperre_flaeche.dart';
import 'arbeitskontext_lade_checkliste.dart';
import 'startbuehne_person.dart';

/// Was die Startbühne gerade zeigen muss, abgeleitet aus Anmeldung und
/// Arbeitskontext. Spiegelt die Ladezustände aus `_buildPlaceholder` in
/// `navigation_home.page.dart`.
@immutable
class StartbuehneLage {
  const StartbuehneLage({
    required this.laedt,
    this.gesperrt = false,
    this.statusKey,
    this.schritte,
    this.fehler,
  });

  /// Der Inhalt ist noch nicht bereit.
  final bool laedt;

  /// Die App-Sperre liegt; die Bühne zeigt Glas und Knopf (E1).
  final bool gesperrt;

  /// Text, der nach 1,5 s unter der Person erscheint.
  final String? statusKey;

  /// Ladeschritte beim ersten Laden des Arbeitskontexts; dann erscheint
  /// statt des Status die Checkliste (L1).
  final List<ArbeitskontextLoadingStepStatus>? schritte;

  /// Fehlermeldung der Sperre.
  final String? fehler;

  bool get bereit => !laedt && !gesperrt;

  static const bereitLage = StartbuehneLage(laedt: false);

  factory StartbuehneLage.aus(
    AuthSessionModel auth,
    ArbeitskontextModel arbeitskontext,
  ) {
    final state = auth.state;
    final ohneKontext = arbeitskontext.arbeitskontext == null;
    final laedtKontext =
        ohneKontext &&
        (arbeitskontext.status == ArbeitskontextStatus.initial ||
            arbeitskontext.isLoading);
    final neuanmeldung =
        state == AuthState.signedIn &&
        (auth.requiresInteractiveLogin || auth.isNeuanmeldungAktiv) &&
        (ohneKontext || arbeitskontext.hasError);
    switch (state) {
      case AuthState.initializing:
      case AuthState.authenticating:
        return const StartbuehneLage(
          laedt: true,
          statusKey: 'nav_auth_preparing_title',
        );
      case AuthState.signedIn:
      case AuthState.unlockRequired:
        final laedt = laedtKontext && !neuanmeldung;
        return StartbuehneLage(
          laedt: laedt,
          gesperrt: state == AuthState.unlockRequired,
          statusKey: 'nav_work_context_loading_title',
          schritte: laedt ? arbeitskontext.loadingSteps : null,
          fehler: auth.errorMessage,
        );
      case AuthState.signedOut:
      case AuthState.reloginRequired:
      case AuthState.error:
        return bereitLage;
    }
  }
}

/// Hält die [StartbuehneLage] aktuell, solange Anmeldung und Arbeitskontext
/// sich ändern.
class StartbuehneQuelle extends ValueNotifier<StartbuehneLage> {
  StartbuehneQuelle(this._auth, this._arbeitskontext)
    : super(StartbuehneLage.aus(_auth, _arbeitskontext)) {
    _auth.addListener(_aktualisieren);
    _arbeitskontext.addListener(_aktualisieren);
  }

  final AuthSessionModel _auth;
  final ArbeitskontextModel _arbeitskontext;

  void _aktualisieren() {
    value = StartbuehneLage.aus(_auth, _arbeitskontext);
  }

  @override
  void dispose() {
    _auth.removeListener(_aktualisieren);
    _arbeitskontext.removeListener(_aktualisieren);
    super.dispose();
  }
}

enum _Phase { steht, geht, weg }

/// Startbühne (#279, `design/entscheidung/2026-10-30-startbuehne.md`).
///
/// Übernimmt pixelgleich vom nativen Startbild: Verlauf in der Standard-
/// Primärfarbe nach Systemhelligkeit, mittig die Person ohne Halstuch. Die
/// Bühne bleibt immer Standard, auch mit Supporter-Paket.
///
/// - Ist der Inhalt in unter 300 ms bereit, läuft nur der Abgang.
/// - Sonst knotet die Person einmal ihr Halstuch und steht dann still.
///   Nach 1,5 s erscheint der Status bzw. bei der Erstanmeldung die
///   Checkliste.
/// - Liegt die App-Sperre, zeigt die Bühne Glas und Knopf; nach dem
///   Entsperren gehen erst diese, dann die Fläche.
/// - Lädt der Arbeitskontext nach einer Anmeldung neu, kommt die Bühne mit
///   der Checkliste zurück.
/// - Bei „Bewegung reduzieren“ gibt es nur Überblendungen von 200 ms.
///
/// Spielt bei Rückkehr aus dem Hintergrund nicht ab, weil der Zustand an
/// dieser Instanz hängt und nur ein neuer App-Aufbau sie neu anlegt.
class AppStartbuehne extends StatefulWidget {
  const AppStartbuehne({
    super.key,
    required this.lage,
    required this.child,
    this.onEntsperren,
    this.gebunden = false,
  });

  final ValueListenable<StartbuehneLage> lage;
  final Widget child;
  final VoidCallback? onEntsperren;

  /// Halstuch schon geknotet, z. B. nach dem Demo-/Live-Wechsel.
  final bool gebunden;

  static const Duration bewegungAb = Duration(milliseconds: 300);
  static const Duration hinweisAb = Duration(milliseconds: 1500);

  /// Ob die Bühne gerade steht; dann zeigt sie auch die App-Sperre.
  static bool sichtbar(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BuehneSichtbar>()?.sichtbar ??
      false;

  @override
  State<AppStartbuehne> createState() => _AppStartbuehneState();
}

class _AppStartbuehneState extends State<AppStartbuehne>
    with TickerProviderStateMixin {
  late final AnimationController _knoten;
  late final AnimationController _blende;
  late final AnimationController _hinweis;
  late final AnimationController _abgang;

  _Phase _phase = _Phase.steht;
  bool _bewegt = false;
  bool _nurBlende = false;
  bool _hinweisZeit = false;
  bool _mitInhalt = false;
  // Was beim Abgang zu sehen war, bleibt bis zum Ende stehen.
  StartbuehneLage? _eingefroren;
  Timer? _bewegungTimer;
  Timer? _hinweisTimer;

  StartbuehneLage get _lage => _eingefroren ?? widget.lage.value;

  @override
  void initState() {
    super.initState();
    _knoten = AnimationController(
      vsync: this,
      duration: StartbuehnePerson.dauer,
    );
    _blende = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hinweis = AnimationController(vsync: this, duration: AppBewegung.standard);
    _abgang = AnimationController(vsync: this);
    widget.lage.addListener(_pruefe);
    if (widget.gebunden) {
      _knoten.value = 1;
    }
    // Die Zeiten zählen ab dem ersten Bild der Bühne; bis dahin steht das
    // native Startbild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bewegungTimer = Timer(AppStartbuehne.bewegungAb, _bewegen);
      _hinweisTimer = Timer(AppStartbuehne.hinweisAb, _zeigeHinweis);
      _pruefe();
    });
  }

  @override
  void didUpdateWidget(covariant AppStartbuehne oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lage != widget.lage) {
      oldWidget.lage.removeListener(_pruefe);
      widget.lage.addListener(_pruefe);
      _pruefe();
    }
  }

  @override
  void dispose() {
    widget.lage.removeListener(_pruefe);
    _bewegungTimer?.cancel();
    _hinweisTimer?.cancel();
    _knoten.dispose();
    _blende.dispose();
    _hinweis.dispose();
    _abgang.dispose();
    super.dispose();
  }

  bool get _reduziert => AppBewegung.reduziert(context);

  void _bewegen() {
    if (!mounted || _phase != _Phase.steht || _lage.bereit) {
      return;
    }
    if (_knoten.value == 1) {
      return;
    }
    _bewegt = true;
    if (_reduziert) {
      setState(() => _nurBlende = true);
      _blende.forward();
    } else {
      _knoten.forward();
    }
  }

  void _zeigeHinweis() {
    if (!mounted || _phase != _Phase.steht || _lage.bereit) {
      return;
    }
    setState(() => _hinweisZeit = true);
    _hinweis.forward();
  }

  void _pruefe() {
    if (!mounted) {
      return;
    }
    final lage = widget.lage.value;
    switch (_phase) {
      case _Phase.steht:
        if (lage.bereit) {
          _abgehen();
        } else {
          setState(() {});
        }
      case _Phase.geht:
        break;
      case _Phase.weg:
        if (lage.laedt && lage.schritte != null) {
          _zurueckkehren();
        }
    }
  }

  Future<void> _abgehen() async {
    _bewegungTimer?.cancel();
    _hinweisTimer?.cancel();
    final schnell = !_bewegt && _knoten.value == 0;
    setState(() {
      _phase = _Phase.geht;
      _eingefroren = _letzteAnzeige;
      _mitInhalt = _letzteAnzeige.gesperrt || _hinweis.value > 0;
      if (schnell) {
        // Schneller Start: Das Tuch erscheint mit dem Abgang.
        _nurBlende = true;
      }
    });
    if (schnell) {
      unawaited(_blende.forward());
    }
    _abgang.duration = StartbuehneAbgang.dauer(
      reduziert: _reduziert,
      mitInhalt: _mitInhalt,
    );
    await _abgang.forward(from: 0).orCancel.catchError((_) {});
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = _Phase.weg;
      _eingefroren = null;
    });
  }

  Future<void> _zurueckkehren() async {
    setState(() {
      _phase = _Phase.steht;
      _eingefroren = null;
      _mitInhalt = true;
      _hinweisZeit = true;
      _nurBlende = false;
      _knoten.value = 1;
      _hinweis.value = 1;
    });
    _abgang.duration = StartbuehneAbgang.dauer(
      reduziert: _reduziert,
      mitInhalt: true,
    );
    await _abgang.reverse(from: 1).orCancel.catchError((_) {});
    if (mounted && widget.lage.value.bereit) {
      unawaited(_abgehen());
    }
  }

  // Letzter angezeigter Stand: Sperre und Ladeschritte verschwinden aus der
  // Lage, sobald sie erledigt sind, sollen beim Abgang aber stehen bleiben.
  StartbuehneLage _letzteAnzeige = StartbuehneLage.bereitLage;

  @override
  Widget build(BuildContext context) {
    final lage = _lage;
    if (_phase == _Phase.steht && (lage.gesperrt || lage.laedt)) {
      _letzteAnzeige = lage;
    }
    final reduziert = AppBewegung.reduziert(context);
    final steht = _phase == _Phase.steht;
    return _BuehneSichtbar(
      sichtbar: steht,
      child: Stack(
        fit: StackFit.expand,
        children: [
          StartbuehneInhalt(
            animation: _abgang,
            reduziert: reduziert,
            mitInhalt: _mitInhalt,
            child: widget.child,
          ),
          if (_phase != _Phase.weg)
            IgnorePointer(
              ignoring: !steht,
              child: BlockSemantics(
                child: StartbuehneAbgang(
                  animation: _abgang,
                  reduziert: reduziert,
                  mitInhalt: _mitInhalt,
                  builder: (context, inhalt) => Material(
                    type: MaterialType.transparency,
                    child: StartbuehneFlaeche(
                      person: StartbuehnePerson(
                        knoten: _knoten,
                        blende: _nurBlende ? _blende : null,
                      ),
                      unterPerson: _unterPerson(lage, inhalt),
                      unten: lage.gesperrt && widget.onEntsperren != null
                          ? FadeTransition(
                              opacity: inhalt,
                              child: AppSperreKnopf(
                                onEntsperren: widget.onEntsperren!,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _unterPerson(StartbuehneLage lage, Animation<double> inhalt) {
    if (lage.gesperrt) {
      return FadeTransition(
        opacity: inhalt,
        child: AppSperreText(errorMessage: lage.fehler),
      );
    }
    if (!_hinweisZeit) {
      return null;
    }
    final schritte = lage.schritte;
    final statusKey = lage.statusKey;
    final Widget hinweis;
    if (schritte != null && schritte.isNotEmpty) {
      hinweis = AppSperreGlas(
        child: ArbeitskontextLadeCheckliste(
          key: const Key('startbuehne-checkliste'),
          steps: schritte,
        ),
      );
    } else if (statusKey != null) {
      hinweis = Text(
        AppLocalizations.of(context).t(statusKey),
        key: const Key('startbuehne-status'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.8),
        ),
      );
    } else {
      return null;
    }
    return FadeTransition(
      opacity: inhalt,
      child: FadeTransition(opacity: _hinweis, child: hinweis),
    );
  }
}

class _BuehneSichtbar extends InheritedWidget {
  const _BuehneSichtbar({required this.sichtbar, required super.child});

  final bool sichtbar;

  @override
  bool updateShouldNotify(_BuehneSichtbar oldWidget) =>
      oldWidget.sichtbar != sichtbar;
}

/// Fläche der Startbühne: Verlauf in der Standard-Primärfarbe nach der
/// Systemhelligkeit (wie das native Startbild), mittig [person]. Darunter
/// [unterPerson] (Status, Checkliste, Sperrtext), unten [unten] (Knopf).
class StartbuehneFlaeche extends StatelessWidget {
  const StartbuehneFlaeche({
    super.key,
    required this.person,
    this.unterPerson,
    this.unten,
  });

  final Widget person;
  final Widget? unterPerson;
  final Widget? unten;

  @override
  Widget build(BuildContext context) {
    final dunkel = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final unterPerson = this.unterPerson;
    final unten = this.unten;
    final padding = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final unterkante =
            constraints.maxHeight / 2 +
            StartbuehnePerson.groesseStandard / 2 +
            12;
        return Stack(
          key: const Key('startbuehne'),
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: AppSperreFlaeche.verlauf(
                dunkel ? DPSGColors.primaryDark : DPSGColors.primaryLight,
                dunkel: dunkel,
              ),
            ),
            Center(child: person),
            if (unterPerson != null)
              Positioned(
                left: 24,
                right: 24,
                top: unterkante,
                bottom: padding.bottom + (unten != null ? 96 : 24),
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: unterPerson,
                    ),
                  ),
                ),
              ),
            if (unten != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: padding.bottom + 24,
                child: unten,
              ),
          ],
        );
      },
    );
  }
}

/// Abgang einer Fläche wie bei der Startbühne (A1): Mit [mitInhalt] blenden
/// zuerst Glas und Knopf aus (150 ms), dann hebt sich die Fläche um 40 pt
/// und blendet aus (300 ms, [AppBewegung.blatt]). Bei reduzierter Bewegung
/// nur eine Überblendung von 200 ms. [animation] läuft von 0 bis 1.
class StartbuehneAbgang extends StatelessWidget {
  const StartbuehneAbgang({
    super.key,
    required this.animation,
    required this.reduziert,
    required this.builder,
    this.mitInhalt = false,
  });

  final Animation<double> animation;
  final bool reduziert;
  final bool mitInhalt;

  /// Baut die Fläche; `inhalt` ist die Deckkraft für Glas und Knopf.
  final Widget Function(BuildContext context, Animation<double> inhalt) builder;

  static const _inhaltMs = 150;
  static const _flaecheMs = 300;
  static const _reduziertMs = 200;

  static Duration dauer({required bool reduziert, bool mitInhalt = false}) =>
      Duration(
        milliseconds: reduziert
            ? _reduziertMs
            : _flaecheMs + (mitInhalt ? _inhaltMs : 0),
      );

  /// Anteil des Abgangs, der auf Glas und Knopf entfällt.
  static double inhaltAnteil({
    required bool reduziert,
    bool mitInhalt = false,
  }) => reduziert || !mitInhalt ? 0 : _inhaltMs / (_inhaltMs + _flaecheMs);

  @override
  Widget build(BuildContext context) {
    if (reduziert) {
      return FadeTransition(
        opacity: ReverseAnimation(animation),
        child: builder(context, kAlwaysCompleteAnimation),
      );
    }
    final teil = inhaltAnteil(reduziert: reduziert, mitInhalt: mitInhalt);
    final inhalt = teil == 0
        ? kAlwaysCompleteAnimation
        : animation.drive(
            Tween<double>(begin: 1, end: 0).chain(
              CurveTween(curve: Interval(0, teil, curve: AppBewegung.ausgang)),
            ),
          );
    final flaeche = animation.drive(
      CurveTween(curve: Interval(teil, 1, curve: AppBewegung.blatt)),
    );
    return AnimatedBuilder(
      animation: flaeche,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -40 * flaeche.value),
        child: Opacity(opacity: 1 - flaeche.value, child: child),
      ),
      child: builder(context, inhalt),
    );
  }
}

/// Auftritt des Inhalts unter der Bühne: Scale 0,98 → 1 und Fade, zeitgleich
/// mit dem Abgang der Fläche; bei reduzierter Bewegung nur Fade.
class StartbuehneInhalt extends StatelessWidget {
  const StartbuehneInhalt({
    super.key,
    required this.animation,
    required this.reduziert,
    required this.mitInhalt,
    required this.child,
  });

  final Animation<double> animation;
  final bool reduziert;
  final bool mitInhalt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final teil = StartbuehneAbgang.inhaltAnteil(
      reduziert: reduziert,
      mitInhalt: mitInhalt,
    );
    final auftritt = animation.drive(
      CurveTween(curve: Interval(teil, 1, curve: AppBewegung.ausgang)),
    );
    return FadeTransition(
      opacity: auftritt,
      child: reduziert
          ? child
          : ScaleTransition(
              scale: auftritt.drive(Tween<double>(begin: 0.98, end: 1)),
              child: child,
            ),
    );
  }
}

/// Standbild der Bühne für den Demo-/Live-Wechsel, solange der alte App-Baum
/// abgebaut und der neue aufgebaut wird. Ohne Provider und Theme.
class StartbuehneStandbild extends StatelessWidget {
  const StartbuehneStandbild({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: StartbuehneFlaeche(
        person: StartbuehnePerson(knoten: kAlwaysCompleteAnimation),
      ),
    );
  }
}
