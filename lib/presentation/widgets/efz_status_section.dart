import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/member/efz_einsichtnahme.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/qualifikation/berechne_efz_gueltigkeit_usecase.dart';
import '../../domain/qualifikation/qualifikations_status.dart';
import '../../services/hitobito_efz_service.dart';
import '../model/auth_session_model.dart';
import '../notifications/app_snackbar.dart';
import 'qualifikations_status_badge.dart';

/// Zeigt den EFZ-Status (erweitertes Führungszeugnis) eines Mitglieds an:
/// Gültig-bis-Datum, Status-Badge, ggf. Handlungs-Hinweistext, sowie einen
/// Button zum Herunterladen der Antragsunterlagen.
class EfzStatusSection extends StatefulWidget {
  const EfzStatusSection({super.key, required this.mitglied});

  final Mitglied mitglied;

  @override
  State<EfzStatusSection> createState() => _EfzStatusSectionState();
}

class _EfzStatusSectionState extends State<EfzStatusSection> {
  static const _berechneGueltigkeit = BerechneEfzGueltigkeitUseCase();
  static final _dateFormat = DateFormat('dd.MM.yyyy');

  late Future<List<EfzEinsichtnahme>> _future;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _future = _loadEinsichtnahmen();
  }

  @override
  void didUpdateWidget(covariant EfzStatusSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mitglied.personId != widget.mitglied.personId) {
      setState(() {
        _future = _loadEinsichtnahmen();
      });
    }
  }

  Future<List<EfzEinsichtnahme>> _loadEinsichtnahmen() async {
    final personId = widget.mitglied.personId;
    final accessToken = context.read<AuthSessionModel?>()?.session?.accessToken;
    if (personId == null || accessToken == null || accessToken.isEmpty) {
      return const <EfzEinsichtnahme>[];
    }

    final service = context.read<HitobitoEfzService>();
    return service.fetchEfzEinsichtnahmenFuerPerson(
      accessToken,
      personId: personId,
    );
  }

  Future<void> _downloadAntrag() async {
    final personId = widget.mitglied.personId;
    final groupId = widget.mitglied.primaryGroupId;
    final accessToken = context.read<AuthSessionModel?>()?.session?.accessToken;
    if (personId == null ||
        groupId == null ||
        accessToken == null ||
        accessToken.isEmpty) {
      _showMessage(
        'Antragsunterlagen konnten nicht geladen werden (fehlende Daten).',
        type: AppSnackbarType.warning,
      );
      return;
    }

    final service = context.read<HitobitoEfzService>();
    setState(() {
      _isDownloading = true;
    });

    try {
      final bytes = await service.downloadEfzAntrag(
        accessToken,
        groupId: groupId,
        personId: personId,
      );
      if (!mounted) {
        return;
      }
      await _openPdf(bytes, personId: personId);
    } on HitobitoEfzAntragUnavailableException {
      await _openInBrowserFallback(
        service,
        groupId: groupId,
        personId: personId,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(
        'Antragsunterlagen konnten nicht geladen werden.',
        type: AppSnackbarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _openPdf(List<int> bytes, {required int personId}) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/efz_antrag_$personId.pdf');
    await file.writeAsBytes(bytes, flush: true);
    if (!mounted) {
      return;
    }
    final result = await OpenFile.open(file.path);
    if (!mounted || result.type == ResultType.done) {
      return;
    }
    _showMessage(
      'Die Antragsunterlagen konnten nicht geöffnet werden.',
      type: AppSnackbarType.warning,
    );
  }

  Future<void> _openInBrowserFallback(
    HitobitoEfzService service, {
    required int groupId,
    required int personId,
  }) async {
    final fallbackUri = service.config.efzAntragUri(
      groupId: groupId,
      personId: personId,
    );
    var launched = false;
    if (fallbackUri != null) {
      launched = await launchUrl(
        fallbackUri,
        mode: LaunchMode.externalApplication,
      );
    }
    if (!mounted) {
      return;
    }
    if (!launched) {
      _showMessage(
        'Antragsunterlagen konnten nicht geöffnet werden.',
        type: AppSnackbarType.error,
      );
    }
  }

  void _showMessage(
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
  }) {
    AppSnackbar.show(context, message: message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EfzEinsichtnahme>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 32,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 8),
                Text(
                  'EFZ-Status konnte nicht geladen werden',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _future = _loadEinsichtnahmen();
                  }),
                  child: const Text('Erneut versuchen'),
                ),
              ],
            ),
          );
        }

        final einsichtnahmen = snapshot.data ?? const <EfzEinsichtnahme>[];
        final gueltigkeit = _berechneGueltigkeit(einsichtnahmen);
        final status = berechneStatus(
          gueltigBis: gueltigkeit.gueltigBis,
          heute: DateTime.now(),
        );

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 32,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Erweitertes Führungszeugnis',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(child: QualifikationsStatusBadge(status: status)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  gueltigkeit.gueltigBis == null
                      ? 'Keine Einsichtnahme hinterlegt'
                      : 'Gültig bis ${_dateFormat.format(gueltigkeit.gueltigBis!)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (status != QualifikationsStatus.gueltig) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    gueltigkeit.gueltigBis == null
                        ? 'Erneute Vorlage notwendig'
                        : status == QualifikationsStatus.fehlt
                        ? 'Erneute Vorlage sofort notwendig'
                        : 'Erneute Vorlage bis zum '
                              '${_dateFormat.format(gueltigkeit.gueltigBis!)} notwendig',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isDownloading ? null : _downloadAntrag,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('Antragsunterlagen herunterladen'),
              ),
            ],
          ),
        );
      },
    );
  }
}
