import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

import '../../data/maps/shared_prefs_address_map_location_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart' show navigatorKey;
import '../../services/app_runtime_controller.dart';
import '../../services/hitobito_traffic_log_service.dart';
import '../../services/logger_service.dart';
import '../../services/map_tile_cache_service.dart';
import '../../services/problem_melden_service.dart';
import '../../domain/rechtliches/anbieter.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';
import '../model/member_edit_model.dart';
import '../notifications/app_snackbar.dart';
import '../widgets/section_header.dart';
import '../widgets/problem_melden_sheet.dart';
import 'log_viewer_page.dart';
import 'settings_debug_tools_page.dart';

/// „Hilfe & Diagnose“ (A-94, Variante G3 aus
/// `design/entscheidung/2026-10-07-hilfe-diagnose.md`):
/// Statuskarte mit „Problem melden“, Werkzeuge und Speicher. Die bisherigen
/// Debug & Tools gibt es nur noch in Debug- und Profile-Builds.
class HilfeDiagnosePage extends StatefulWidget {
  const HilfeDiagnosePage({
    super.key,
    this.entwicklerFunktionen = !kReleaseMode,
    this.problemMelden,
    this.onResetAllData,
  });

  /// Zeigt die Gruppe „Entwicklung“ mit den bisherigen Debug & Tools.
  final bool entwicklerFunktionen;

  /// Nur für Tests; sonst [ProblemMeldenService].
  final ProblemMeldenService? problemMelden;
  final Future<void> Function()? onResetAllData;

  @override
  State<HilfeDiagnosePage> createState() => _HilfeDiagnosePageState();
}

class _HilfeDiagnosePageState extends State<HilfeDiagnosePage> {
  static final DateFormat _zeit = DateFormat('dd.MM., HH:mm');
  int _revision = 0;

  T? _lies<T>() {
    try {
      return Provider.of<T>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  void _meldung(String text, {AppSnackbarType type = AppSnackbarType.info}) {
    if (mounted) {
      AppSnackbar.show(context, message: text, type: type);
    }
  }

  Future<void> _problemMelden() async {
    final t = AppLocalizations.of(context);
    final logger = context.read<LoggerService>();
    final meldung = await showProblemMeldenSheet(context);
    if (meldung == null || !mounted) {
      return;
    }
    await logger.trackAndLog('hilfe', 'debug_action', {
      'action': 'report_issue',
    });
    try {
      await (widget.problemMelden ?? ProblemMeldenService(logger: logger))
          .melden(meldung, t.t);
    } catch (_) {
      _meldung(
        t.t('hilfe_mail_fehler', {'email': Anbieter.email}),
        type: AppSnackbarType.warning,
      );
    }
  }

  Future<void> _aktualisieren(AuthSessionModel authModel) async {
    final t = AppLocalizations.of(context);
    final arbeitskontext = context.read<ArbeitskontextModel>();
    await authModel.syncHitobitoData(
      syncMembers: (_) => arbeitskontext.syncVollstaendig(
        session: authModel.session,
        profile: authModel.profile,
      ),
      force: true,
      trigger: 'hilfe_diagnose',
    );
    if (!mounted) {
      return;
    }
    final ok =
        authModel.dataSyncStatus.lastAttemptResult == SyncAttemptResult.success;
    _meldung(
      ok ? t.t('debug_sync_success') : t.t('debug_sync_partial_failure'),
      type: ok ? AppSnackbarType.success : AppSnackbarType.warning,
    );
  }

  Future<void> _wartendeSenden(
    MemberEditModel model,
    AuthSessionModel authModel,
  ) async {
    final t = AppLocalizations.of(context);
    final token = authModel.session?.accessToken;
    if (token == null || token.isEmpty) {
      _meldung(t.t('debug_retry_missing_token'), type: AppSnackbarType.warning);
      return;
    }
    final summary = await model.retryPending(
      accessToken: token,
      trigger: 'manual_hilfe',
    );
    _meldung(
      t.t('debug_retry_summary', {
        'successCount': summary.successCount,
        'discardedCount': summary.discardedCount,
        'retainedCount': summary.retainedCount,
      }),
    );
  }

  Future<void> _protokolle() async {
    final logger = context.read<LoggerService>();
    final traffic = _lies<HitobitoTrafficLogService>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/settings/debug/protokolle'),
        builder: (_) => _ProtokollePage(
          quellen: [
            LogQuelle.app(logger),
            if (traffic != null) LogQuelle.traffic(traffic),
          ],
        ),
      ),
    );
  }

  void _feedback() {
    final ctx = navigatorKey.currentContext ?? context;
    try {
      Wiredash.of(ctx).show(inheritMaterialTheme: true);
    } catch (_) {
      _meldung(
        AppLocalizations.of(context).t('debug_feedback_missing_root'),
        type: AppSnackbarType.error,
      );
    }
  }

  Future<bool> _bestaetigen({
    required String titel,
    required String text,
    required String aktion,
  }) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titel),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.t('hilfe_abbrechen')),
          ),
          FilledButton(
            key: const Key('hilfe-bestaetigen'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(aktion),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _cachesLoeschen() async {
    final t = AppLocalizations.of(context);
    final karten = _lies<MapTileCacheService>();
    if (!await _bestaetigen(
      titel: t.t('hilfe_caches_confirm_title'),
      text: t.t('hilfe_caches_confirm_body'),
      aktion: t.t('hilfe_caches_confirm_action'),
    )) {
      return;
    }
    await karten?.deleteRoot();
    await SharedPrefsAddressMapLocationRepository().clearAll();
    if (mounted) {
      setState(() => _revision++);
      _meldung(t.t('hilfe_caches_geloescht'), type: AppSnackbarType.success);
    }
  }

  Future<void> _zuruecksetzen() async {
    final t = AppLocalizations.of(context);
    if (!await _bestaetigen(
      titel: t.t('debug_reset_confirm_title'),
      text: t.t('debug_reset_confirm_body'),
      aktion: t.t('debug_reset_confirm_action'),
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    final handler =
        widget.onResetAllData ?? context.read<AppRuntimeController>().resetApp;
    await handler();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final authModel = context.watch<AuthSessionModel>();
    final memberEdit = context.watch<MemberEditModel?>();
    final karten = _lies<MapTileCacheService>();
    final angemeldet = authModel.session != null;
    final wartend = memberEdit?.pendingUpdates.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(t.t('hilfe_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _StatusKarte(
            authModel: authModel,
            wartend: wartend,
            zeit: _zeit,
            onProblemMelden: _problemMelden,
          ),
          const SizedBox(height: 12),
          DpsgSectionHeader(label: t.t('hilfe_werkzeuge')),
          _Gruppe(
            children: [
              _Zeile(
                key: const Key('hilfe-sync'),
                icon: Icons.refresh,
                titel: t.t('hilfe_sync_now'),
                onTap: angemeldet && !authModel.isSyncingHitobitoData
                    ? () => _aktualisieren(authModel)
                    : null,
              ),
              if (wartend > 0 && memberEdit != null)
                _Zeile(
                  key: const Key('hilfe-wartende'),
                  icon: Icons.schedule_send_outlined,
                  titel: t.t('hilfe_pending_senden'),
                  untertitel: t.t('hilfe_pending_hint', {'count': wartend}),
                  onTap: memberEdit.isBusy
                      ? null
                      : () => _wartendeSenden(memberEdit, authModel),
                ),
              _Zeile(
                key: const Key('hilfe-protokolle'),
                icon: Icons.article_outlined,
                titel: t.t('hilfe_protokolle'),
                untertitel: t.t('hilfe_protokolle_hint'),
                onTap: _protokolle,
              ),
              _Zeile(
                key: const Key('hilfe-feedback'),
                icon: Icons.chat_bubble_outline,
                titel: t.t('hilfe_feedback'),
                untertitel: t.t('hilfe_feedback_hint'),
                onTap: _feedback,
              ),
              _Zeile(
                key: ValueKey('hilfe-offline-karten-$_revision'),
                icon: Icons.layers_outlined,
                titel: t.t('hilfe_offline_karten'),
                untertitelFuture: karten?.realSizeKiB().then(_groesse),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DpsgSectionHeader(label: t.t('hilfe_speicher')),
          _Gruppe(
            children: [
              _Zeile(
                key: const Key('hilfe-caches'),
                icon: Icons.delete_sweep_outlined,
                farbe: Theme.of(context).colorScheme.onSurfaceVariant,
                titel: t.t('hilfe_caches_loeschen'),
                onTap: _cachesLoeschen,
              ),
              _Zeile(
                key: const Key('hilfe-reset'),
                icon: Icons.warning_amber_rounded,
                farbe: Theme.of(context).colorScheme.error,
                titel: t.t('hilfe_reset'),
                untertitel: t.t('hilfe_reset_hint'),
                onTap: _zuruecksetzen,
              ),
            ],
          ),
          if (widget.entwicklerFunktionen) ...[
            const SizedBox(height: 12),
            DpsgSectionHeader(label: t.t('hilfe_entwicklung')),
            _Gruppe(
              children: [
                _Zeile(
                  key: const Key('hilfe-entwickler'),
                  icon: Icons.bug_report_outlined,
                  farbe: const Color(0xFF8E8E93),
                  titel: t.t('hilfe_entwickler_werkzeuge'),
                  untertitel: t.t('hilfe_entwickler_hint'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(
                        name: '/settings/debug/entwicklung',
                      ),
                      builder: (_) => const DebugToolsPage(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _groesse(double kib) => kib >= 1024
      ? '${(kib / 1024).toStringAsFixed(1)} MB'
      : '${kib.toStringAsFixed(0)} KB';
}

class _StatusKarte extends StatelessWidget {
  const _StatusKarte({
    required this.authModel,
    required this.wartend,
    required this.zeit,
    required this.onProblemMelden,
  });

  final AuthSessionModel authModel;
  final int wartend;
  final DateFormat zeit;
  final VoidCallback onProblemMelden;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = authModel.dataSyncStatus;
    final fehlgeschlagen =
        status.lastAttemptResult != null &&
        status.lastAttemptResult != SyncAttemptResult.success;
    final (IconData icon, Color farbe, String titel) = switch (true) {
      _ when authModel.session == null => (
        Icons.person_off_outlined,
        theme.colorScheme.outline,
        t.t('hilfe_status_signed_out'),
      ),
      _ when wartend > 0 => (
        Icons.schedule_send_outlined,
        const Color(0xFFB26A00),
        t.t('hilfe_status_pending', {'count': wartend}),
      ),
      _ when fehlgeschlagen => (
        Icons.sync_problem_outlined,
        const Color(0xFFB26A00),
        t.t('hilfe_status_failed'),
      ),
      _ when status.lastSuccessfulSyncAt == null => (
        Icons.cloud_download_outlined,
        theme.colorScheme.primary,
        t.t('hilfe_status_keine_daten'),
      ),
      _ => (
        Icons.check_circle_outline,
        const Color(0xFF00823C),
        t.t('hilfe_status_ok'),
      ),
    };
    final letzte = status.lastSuccessfulSyncAt;
    final untertitel = [
      if (letzte != null)
        t.t('hilfe_status_daten', {'time': zeit.format(letzte)}),
      if (wartend == 0 && authModel.session != null)
        t.t('hilfe_status_keine_pending'),
    ].join(' · ');
    return Card(
      key: const Key('hilfe-status'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: farbe.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: farbe, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titel, style: theme.textTheme.titleSmall),
                      if (untertitel.isNotEmpty)
                        Text(untertitel, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('hilfe-problem-melden'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: onProblemMelden,
              icon: const Icon(Icons.mail_outline),
              label: Text(t.t('hilfe_problem_melden')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Gruppe extends StatelessWidget {
  const _Gruppe({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final trenner = Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) trenner,
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({
    super.key,
    required this.icon,
    required this.titel,
    this.untertitel,
    this.untertitelFuture,
    this.farbe,
    this.onTap,
  });

  final IconData icon;
  final String titel;
  final String? untertitel;
  final Future<String>? untertitelFuture;
  final Color? farbe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = this.farbe ?? theme.colorScheme.primary;
    Widget? sub;
    if (untertitel != null) {
      sub = Text(untertitel!, style: theme.textTheme.bodySmall);
    } else if (untertitelFuture != null) {
      sub = FutureBuilder<String>(
        future: untertitelFuture,
        builder: (context, snapshot) =>
            Text(snapshot.data ?? '…', style: theme.textTheme.bodySmall),
      );
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: farbe.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: farbe, size: 20),
      ),
      title: Text(titel, style: theme.textTheme.titleSmall),
      subtitle: sub,
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

/// App-Log und Traffic-Log zur Auswahl.
class _ProtokollePage extends StatelessWidget {
  const _ProtokollePage({required this.quellen});

  final List<LogQuelle> quellen;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('hilfe_protokolle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Gruppe(
            children: [
              for (final quelle in quellen)
                _Zeile(
                  key: Key('hilfe-protokoll-${quelle.dateiKennung}'),
                  icon: quelle.dateiKennung == 'app'
                      ? Icons.article_outlined
                      : Icons.swap_horiz,
                  titel: t.t(quelle.titelKey),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(
                        name: '/settings/debug/logs',
                      ),
                      builder: (_) => LogViewerPage(quelle: quelle),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
