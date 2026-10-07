import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/auth/auth_state.dart';
import '../../l10n/app_localizations.dart';
import '../model/auth_session_model.dart';
import '../navigation/navigation_home.page.dart';
import '../widgets/app_sperre_flaeche.dart';

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NavigationHomeScreen();
  }
}

/// Deckende Sperre bei [AuthState.unlockRequired] (A-16). Der Inhalt darunter
/// bleibt aufgebaut, ist aber durch [AppGesperrterInhalt] von Fokus,
/// Zeigern und Screenreader abgeschirmt.
class AppLockOverlay extends StatelessWidget {
  const AppLockOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSessionModel>(
      builder: (context, authModel, _) {
        if (authModel.state != AuthState.unlockRequired) {
          return const SizedBox.shrink();
        }
        return Material(
          key: const Key('app_lock_overlay'),
          type: MaterialType.transparency,
          child: AppSperreAnsicht(
            errorMessage: authModel.errorMessage,
            onEntsperren: authModel.unlock,
          ),
        );
      },
    );
  }
}

/// Inhalt der Sperre: Fläche, Glas mit Titel und Text, Knopf unten.
class AppSperreAnsicht extends StatelessWidget {
  const AppSperreAnsicht({
    super.key,
    required this.onEntsperren,
    this.errorMessage,
  });

  final VoidCallback onEntsperren;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final errorMessage = this.errorMessage;
    return AppSperreFlaeche(
      inhalt: AppSperreGlas(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.t('auth_unlock_title'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t.t('auth_unlock_body'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (errorMessage != null && errorMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                errorMessage,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      unten: FilledButton.icon(
        key: const Key('app_lock_unlock'),
        autofocus: true,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF003056),
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: onEntsperren,
        icon: const Icon(Icons.lock_open_outlined),
        label: Text(t.t('auth_unlock_action')),
      ),
    );
  }
}

/// Schirmt den App-Inhalt ab, solange die Sperre liegt: kein Fokus per
/// Tastatur, keine Zeiger und nichts für den Screenreader.
class AppGesperrterInhalt extends StatelessWidget {
  const AppGesperrterInhalt({
    super.key,
    required this.gesperrt,
    required this.child,
  });

  final bool gesperrt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      excluding: gesperrt,
      child: ExcludeSemantics(
        excluding: gesperrt,
        child: IgnorePointer(ignoring: gesperrt, child: child),
      ),
    );
  }
}

/// Fängt die Zurück-Taste ab, solange die Sperre liegt: Statt Routen unter
/// der Sperre zu schließen, geht die App in den Hintergrund (A-16). Muss
/// über dem `MaterialApp` stehen, damit dieser Observer vor dem des
/// Navigators registriert ist und zuerst gefragt wird.
class AppSperreZurueckTaste extends StatefulWidget {
  const AppSperreZurueckTaste({
    super.key,
    required this.gesperrt,
    required this.child,
    this.onZurueck,
  });

  final bool Function() gesperrt;
  final Widget child;

  /// Standard: [SystemNavigator.pop].
  final Future<void> Function()? onZurueck;

  @override
  State<AppSperreZurueckTaste> createState() => _AppSperreZurueckTasteState();
}

class _AppSperreZurueckTasteState extends State<AppSperreZurueckTaste>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (!widget.gesperrt()) {
      return false;
    }
    await (widget.onZurueck ?? SystemNavigator.pop)();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Sichtschutz im App-Umschalter (A-17): Bei aktiver App-Sperre verdeckt die
/// App ihren Inhalt, sobald sie nicht mehr im Vordergrund ist. iOS übernimmt
/// diese Fläche in den Schnappschuss; unter Android 13+ blendet das System
/// die Vorschau zusätzlich selbst aus.
class AppSichtschutz extends StatefulWidget {
  const AppSichtschutz({super.key, required this.aktiv, this.plattform});

  final bool aktiv;

  /// Nur für Tests; sonst der Android-Kanal.
  final AppSichtschutzPlattform? plattform;

  @override
  State<AppSichtschutz> createState() => _AppSichtschutzState();
}

class _AppSichtschutzState extends State<AppSichtschutz>
    with WidgetsBindingObserver {
  AppLifecycleState? _zustand = WidgetsBinding.instance.lifecycleState;

  AppSichtschutzPlattform get _plattform =>
      widget.plattform ?? AppSichtschutzPlattform.standard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _plattform.setzen(widget.aktiv);
  }

  @override
  void didUpdateWidget(covariant AppSichtschutz oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aktiv != widget.aktiv) {
      _plattform.setzen(widget.aktiv);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _zustand = state);
  }

  @override
  Widget build(BuildContext context) {
    final imHintergrund =
        _zustand != null && _zustand != AppLifecycleState.resumed;
    if (!widget.aktiv || !imHintergrund) {
      return const SizedBox.shrink();
    }
    return Consumer<AuthSessionModel>(
      builder: (context, authModel, _) {
        // Die Sperre ist schon deckend; so bleibt sie auch während der
        // Face-ID-Abfrage sichtbar.
        if (authModel.state == AuthState.unlockRequired) {
          return const SizedBox.shrink();
        }
        return const Material(
          key: Key('app_sichtschutz'),
          type: MaterialType.transparency,
          child: AppSperreFlaeche(),
        );
      },
    );
  }
}

/// Plattformteil des Sichtschutzes: Unter Android 13+ blendet
/// `setRecentsScreenshotEnabled(false)` die Vorschau im Umschalter aus.
class AppSichtschutzPlattform {
  const AppSichtschutzPlattform();

  static const AppSichtschutzPlattform standard = AppSichtschutzPlattform();

  static const MethodChannel _kanal = MethodChannel('com.namiapp/sichtschutz');

  Future<void> setzen(bool aktiv) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _kanal.invokeMethod<void>('setzen', <String, Object>{
        'aktiv': aktiv,
      });
    } on MissingPluginException {
      // Tests und Plattformen ohne Kanal.
    } on PlatformException {
      // Ohne Plattformteil bleibt die Flutter-Abdeckung.
    }
  }
}
