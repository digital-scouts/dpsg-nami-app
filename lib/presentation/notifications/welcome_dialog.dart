import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';

/// Optionen und Rueckmeldungen fuer den Willkommen-Stepper nach dem ersten
/// Login. Der Stepper selbst speichert nichts.
class WillkommenOptionen {
  const WillkommenOptionen({
    required this.biometrieVerfuegbar,
    required this.biometrieAktiv,
    required this.benachrichtigungenErlaubt,
    required this.analyseAktiv,
    required this.keineMobilenDaten,
    required this.themeMode,
    required this.onBiometrieAktivieren,
    required this.onBenachrichtigungenAktivieren,
    required this.onAnalyseAendern,
    required this.onKeineMobilenDatenAendern,
    required this.onThemeAendern,
    required this.onRechtliches,
    this.onSystemEinstellungen,
  });

  /// Ohne Biometrie auf dem Geraet entfaellt der Schritt „App schuetzen“.
  final bool biometrieVerfuegbar;
  final bool biometrieAktiv;

  /// `null`, solange das System noch nicht gefragt hat.
  final bool? benachrichtigungenErlaubt;
  final bool analyseAktiv;
  final bool keineMobilenDaten;
  final ThemeMode themeMode;

  /// Bestaetigt per Face ID bzw. Fingerabdruck und schaltet die Sperre ein;
  /// liefert, ob das geklappt hat.
  final Future<bool> Function() onBiometrieAktivieren;

  /// Zeigt die Systemabfrage; liefert, ob Benachrichtigungen erlaubt sind.
  final Future<bool> Function() onBenachrichtigungenAktivieren;
  final Future<void> Function(bool aktiv) onAnalyseAendern;
  final Future<void> Function(bool aktiv) onKeineMobilenDatenAendern;
  final Future<void> Function(ThemeMode mode) onThemeAendern;
  final VoidCallback onRechtliches;

  /// Oeffnet die Systemeinstellungen der App; ohne (Android) nur ein Hinweis.
  final VoidCallback? onSystemEinstellungen;
}

/// Zeigt den Stepper als Vollbild-Dialog.
Future<void> showWelcomeDialog(
  BuildContext context, {
  required WillkommenOptionen optionen,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (_) =>
        Dialog.fullscreen(child: WillkommenStepper(optionen: optionen)),
  );
}

enum _Schritt { schutz, benachrichtigungen, einstellungen, highlights }

class WillkommenStepper extends StatefulWidget {
  const WillkommenStepper({
    super.key,
    required this.optionen,
    this.startSchritt = 0,
    this.weiterNachErlaubnis = const Duration(milliseconds: 700),
  });

  final WillkommenOptionen optionen;

  /// Nur fuer Storybook und Tests.
  final int startSchritt;

  /// Nach einer Erlaubnis bleibt „Aktiv“ kurz sichtbar, dann geht es weiter.
  final Duration weiterNachErlaubnis;

  @override
  State<WillkommenStepper> createState() => _WillkommenStepperState();
}

class _WillkommenStepperState extends State<WillkommenStepper> {
  late final List<_Schritt> _schritte = [
    if (widget.optionen.biometrieVerfuegbar) _Schritt.schutz,
    _Schritt.benachrichtigungen,
    _Schritt.einstellungen,
    _Schritt.highlights,
  ];
  late int _index = widget.startSchritt.clamp(0, _schritte.length - 1);
  late bool _biometrie = widget.optionen.biometrieAktiv;
  late bool? _benachrichtigungen = widget.optionen.benachrichtigungenErlaubt;
  late bool _analyse = widget.optionen.analyseAktiv;
  late bool _keineMobilenDaten = widget.optionen.keineMobilenDaten;
  late ThemeMode _themeMode = widget.optionen.themeMode;
  bool _beschaeftigt = false;

  _Schritt get _aktuell => _schritte[_index];
  bool get _istLetzter => _index == _schritte.length - 1;

  /// Richtung des letzten Wechsels fuer die Wisch-Animation.
  bool _vorwaerts = true;

  void _weiter() {
    if (_istLetzter) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _vorwaerts = true;
      _index++;
    });
  }

  void _zurueck() => setState(() {
    _vorwaerts = false;
    _index--;
  });

  /// Nach erteilter Erlaubnis ist der naechste Schritt offensichtlich.
  Future<void> _weiterNachErlaubnis(_Schritt schritt) async {
    await Future<void>.delayed(widget.weiterNachErlaubnis);
    if (mounted && _aktuell == schritt) {
      _weiter();
    }
  }

  Future<void> _biometrieAktivieren() async {
    setState(() => _beschaeftigt = true);
    final ok = await widget.optionen.onBiometrieAktivieren();
    if (!mounted) {
      return;
    }
    setState(() {
      _beschaeftigt = false;
      _biometrie = ok;
    });
    if (ok) {
      await _weiterNachErlaubnis(_Schritt.schutz);
    }
  }

  Future<void> _benachrichtigungenAktivieren() async {
    setState(() => _beschaeftigt = true);
    final ok = await widget.optionen.onBenachrichtigungenAktivieren();
    if (!mounted) {
      return;
    }
    setState(() {
      _beschaeftigt = false;
      _benachrichtigungen = ok;
    });
    if (ok) {
      await _weiterNachErlaubnis(_Schritt.benachrichtigungen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (icon, titelKey, inhalt) = switch (_aktuell) {
      _Schritt.schutz => (null, 'welcome_lock_title', _schutzInhalt(t)),
      _Schritt.benachrichtigungen => (
        Icons.notifications_none,
        'welcome_notify_title',
        _benachrichtigungInhalt(t),
      ),
      _Schritt.einstellungen => (
        Icons.tune,
        'welcome_settings_title',
        _einstellungenInhalt(t),
      ),
      _Schritt.highlights => (
        Icons.auto_awesome_outlined,
        'welcome_highlights_title',
        _highlightsInhalt(t),
      ),
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Fortschritt(anzahl: _schritte.length, aktiv: _index),
                const SizedBox(height: 8),
                Text(
                  t.t('welcome_step', {
                    'current': _index + 1,
                    'total': _schritte.length,
                  }),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  // Wischen: vorwaerts kommt der Schritt von rechts, zurueck
                  // von links; der alte gleitet zur Gegenseite hinaus.
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (aktuell, vorherige) => Stack(
                        alignment: Alignment.topLeft,
                        children: [...vorherige, ?aktuell],
                      ),
                      transitionBuilder: (child, animation) {
                        final richtung = _vorwaerts ? 1.0 : -1.0;
                        final eingehend = child.key == ValueKey(_aktuell);
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(eingehend ? richtung : -richtung, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        );
                      },
                      child: SingleChildScrollView(
                        key: ValueKey(_aktuell),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_index == 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  t.t('welcome_title').toUpperCase(),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                _SchrittIcon(
                                  icon: _index == 0 ? null : icon,
                                  size: 40,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    t.t(titelKey),
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            inhalt,
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: Key(_istLetzter ? 'welcome-finish' : 'welcome-next'),
                    onPressed: _beschaeftigt ? null : _weiter,
                    child: Text(
                      t.t(_istLetzter ? 'welcome_finish' : 'welcome_next'),
                    ),
                  ),
                ),
                if (_index > 0)
                  Center(
                    child: TextButton(
                      key: const Key('welcome-back'),
                      onPressed: _beschaeftigt ? null : _zurueck,
                      child: Text(t.t('welcome_back')),
                    ),
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _schutzInhalt(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Absatz(t.t('welcome_lock_body')),
        const SizedBox(height: 16),
        _WarumPunkte(
          punkte: [
            (Icons.smartphone, t.t('welcome_lock_why_offline')),
            (Icons.person_outline, t.t('welcome_lock_why_lend')),
            (Icons.visibility_off_outlined, t.t('welcome_lock_why_pause')),
          ],
        ),
        const SizedBox(height: 16),
        _AktivierenKarte(
          key: const Key('welcome-lock-card'),
          icon: Icons.face_unlock_outlined,
          titel: t.t('welcome_lock_option'),
          text: t.t('welcome_lock_option_hint'),
          aktiv: _biometrie,
          beschaeftigt: _beschaeftigt,
          aktivierenKey: const Key('welcome-lock-on'),
          onAktivieren: _biometrieAktivieren,
        ),
        const SizedBox(height: 10),
        _Hinweis(t.t('welcome_change_later')),
      ],
    );
  }

  Widget _benachrichtigungInhalt(AppLocalizations t) {
    final colors = Theme.of(context).colorScheme;
    final abgelehnt = _benachrichtigungen == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Absatz(t.t('welcome_notify_body')),
        const SizedBox(height: 16),
        _WarumPunkte(
          punkte: [
            (Icons.workspace_premium_outlined, t.t('welcome_notify_why_quali')),
            (Icons.cake_outlined, t.t('welcome_notify_why_birthday')),
            (Icons.sync, t.t('welcome_notify_why_expiry')),
            (Icons.shield_outlined, t.t('welcome_notify_why_local')),
          ],
        ),
        const SizedBox(height: 16),
        _AktivierenKarte(
          key: const Key('welcome-notify-card'),
          icon: Icons.notifications_none,
          titel: t.t('welcome_notify_option'),
          text: t.t('welcome_notify_option_hint'),
          aktiv: _benachrichtigungen == true,
          aus: abgelehnt,
          beschaeftigt: _beschaeftigt,
          aktivierenKey: const Key('welcome-notify-on'),
          onAktivieren: _benachrichtigungenAktivieren,
          zusatz: abgelehnt
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.t('welcome_notify_denied')),
                          if (widget.optionen.onSystemEinstellungen != null)
                            TextButton.icon(
                              key: const Key('welcome-notify-settings'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              iconAlignment: IconAlignment.end,
                              onPressed: widget.optionen.onSystemEinstellungen,
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: Text(t.t('welcome_notify_open_settings')),
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 10),
        _Hinweis(t.t('welcome_change_later')),
      ],
    );
  }

  Widget _einstellungenInhalt(AppLocalizations t) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Absatz(t.t('welcome_settings_body')),
        const SizedBox(height: 16),
        _OptionKarte(
          titel: t.t('welcome_theme'),
          unten: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              key: const Key('welcome-theme'),
              showSelectedIcon: false,
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: _Einzeilig(t.t('theme_light')),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: _Einzeilig(t.t('theme_dark')),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: _Einzeilig(t.t('theme_system')),
                ),
              ],
              selected: {_themeMode},
              onSelectionChanged: (auswahl) async {
                final mode = auswahl.first;
                setState(() => _themeMode = mode);
                await widget.optionen.onThemeAendern(mode);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        _OptionKarte(
          titel: t.t('settings_app_analytics_title'),
          text: t.t('welcome_analytics_hint'),
          rechts: Switch(
            key: const Key('welcome-analytics'),
            value: _analyse,
            onChanged: (wert) async {
              setState(() => _analyse = wert);
              await widget.optionen.onAnalyseAendern(wert);
            },
          ),
        ),
        const SizedBox(height: 10),
        _OptionKarte(
          titel: t.t('welcome_no_mobile_data'),
          text: t.t('welcome_no_mobile_data_hint'),
          rechts: Switch(
            key: const Key('welcome-no-mobile-data'),
            value: _keineMobilenDaten,
            onChanged: (wert) async {
              setState(() => _keineMobilenDaten = wert);
              await widget.optionen.onKeineMobilenDatenAendern(wert);
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('welcome-legal'),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: widget.optionen.onRechtliches,
          icon: Icon(Icons.shield_outlined, size: 18, color: colors.primary),
          label: Text(t.t('legal_title')),
        ),
      ],
    );
  }

  Widget _highlightsInhalt(AppLocalizations t) {
    const kacheln = <(IconData, String)>[
      (Icons.groups_outlined, 'members'),
      (Icons.cloud_off_outlined, 'offline'),
      (Icons.bar_chart, 'statistics'),
      (Icons.trending_up, 'stage_change'),
      (Icons.workspace_premium_outlined, 'qualifications'),
      (Icons.account_tree_outlined, 'layers'),
    ];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.t('welcome_highlights_body'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            // Auf dem Telefon 2 Spalten (3 Zeilen), breiter 3 Spalten.
            final spalten = constraints.maxWidth >= 560 ? 3 : 2;
            const abstand = 10.0;
            return Column(
              children: [
                for (var i = 0; i < kacheln.length; i += spalten)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i + spalten < kacheln.length ? abstand : 0,
                    ),
                    // Gleiche Hoehe je Zeile; die Mindesthoehe haelt alle
                    // Zeilen gleich, solange die Texte hineinpassen.
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var j = i; j < i + spalten; j++) ...[
                            if (j > i) const SizedBox(width: abstand),
                            Expanded(
                              child: j < kacheln.length
                                  ? _HighlightKachel(
                                      key: Key(
                                        'welcome-highlight-${kacheln[j].$2}',
                                      ),
                                      icon: kacheln[j].$1,
                                      titel: t.t(
                                        'welcome_highlight_${kacheln[j].$2}_title',
                                      ),
                                      text: t.t(
                                        'welcome_highlight_${kacheln[j].$2}_text',
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Einzeilig extends StatelessWidget {
  const _Einzeilig(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false),
  );
}

class _Absatz extends StatelessWidget {
  const _Absatz(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyLarge);
}

class _Hinweis extends StatelessWidget {
  const _Hinweis(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _WarumPunkte extends StatelessWidget {
  const _WarumPunkte({required this.punkte});

  final List<(IconData, String)> punkte;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final (icon, text) in punkte)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
              ],
            ),
          ),
      ],
    );
  }
}

class _AktivierenKarte extends StatelessWidget {
  const _AktivierenKarte({
    super.key,
    required this.icon,
    required this.titel,
    required this.text,
    required this.aktiv,
    required this.beschaeftigt,
    required this.aktivierenKey,
    required this.onAktivieren,
    this.aus = false,
    this.zusatz,
  });

  final IconData icon;
  final String titel;
  final String text;
  final bool aktiv;
  final bool aus;
  final bool beschaeftigt;
  final Key aktivierenKey;
  final VoidCallback onAktivieren;
  final Widget? zusatz;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final gruen = Colors.green.shade600;

    final Widget rechts;
    if (aktiv) {
      rechts = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 18, color: gruen),
          const SizedBox(width: 4),
          Text(
            t.t('welcome_active'),
            style: TextStyle(color: gruen, fontWeight: FontWeight.w700),
          ),
        ],
      );
    } else if (aus) {
      rechts = Text(
        t.t('welcome_off'),
        style: TextStyle(color: colors.onSurfaceVariant),
      );
    } else if (beschaeftigt) {
      rechts = const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else {
      rechts = FilledButton.tonal(
        // Akzentflaeche wie im Entwurf; tonal waere das DPSG-Rot.
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        key: aktivierenKey,
        onPressed: onAktivieren,
        child: Text(t.t('welcome_activate')),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: aktiv ? gruen : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              rechts,
            ],
          ),
          if (zusatz case final zusatz?) ...[
            const SizedBox(height: 10),
            zusatz,
          ],
        ],
      ),
    );
  }
}

class _OptionKarte extends StatelessWidget {
  const _OptionKarte({required this.titel, this.text, this.rechts, this.unten});

  final String titel;
  final String? text;
  final Widget? rechts;
  final Widget? unten;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = this.text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (text != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (rechts case final rechts?) ...[
                const SizedBox(width: 12),
                rechts,
              ],
            ],
          ),
          if (unten case final unten?) ...[const SizedBox(height: 10), unten],
        ],
      ),
    );
  }
}

class _HighlightKachel extends StatelessWidget {
  const _HighlightKachel({
    super.key,
    required this.icon,
    required this.titel,
    required this.text,
  });

  final IconData icon;
  final String titel;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
          ),
          const SizedBox(height: 10),
          Text(
            titel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fortschritt extends StatelessWidget {
  const _Fortschritt({required this.anzahl, required this.aktiv});

  final int anzahl;
  final int aktiv;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < anzahl; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: i <= aktiv ? colors.primary : colors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SchrittIcon extends StatelessWidget {
  const _SchrittIcon({required this.icon, this.size = 56});

  /// Ohne Icon (erster Schritt) erscheint die Lilie.
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = this.icon;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: icon == null ? colors.primary : colors.primaryContainer,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Center(
        child: icon == null
            ? SvgPicture.asset(
                'assets/images/lilie.svg',
                width: size * 0.6,
                height: size * 0.6,
                colorFilter: ColorFilter.mode(
                  colors.onPrimary,
                  BlendMode.srcIn,
                ),
              )
            : Icon(icon, size: size / 2, color: colors.onPrimaryContainer),
      ),
    );
  }
}
