import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/arbeitskontext/teildaten_stand.dart';
import '../../../domain/member/efz_einsichtnahme.dart';
import '../../../domain/member/mitglied.dart';
import '../../../domain/qualifikation/berechne_efz_gueltigkeit_usecase.dart';
import '../../../domain/qualifikation/qualifikation.dart';
import '../../../domain/qualifikation/qualifikations_status.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/hitobito_efz_service.dart';
import '../../../services/teilen_ordner.dart';
import '../../format/date_formatters.dart';
import '../../model/auth_session_model.dart';
import '../../notifications/app_snackbar.dart';
import '../../theme/status_farben.dart';
import '../leserechte_hinweis.dart';
import '../section_header.dart';
import 'mitglied_dauer_text.dart';

/// Qualifikationen-Tab: kompakte EFZ-Zeile mit Download der
/// Antragsunterlagen und darunter die Qualifikationen. Beides kommt aus dem
/// beim Sync gespeicherten Arbeitskontext.
class MemberQualifikationenTab extends StatefulWidget {
  const MemberQualifikationenTab({
    super.key,
    required this.mitglied,
    required this.heute,
    this.efzStand = TeildatenStand.unbekannt,
    this.efzEinsichtnahmen = const <EfzEinsichtnahme>[],
    this.qualifikationenStand = TeildatenStand.unbekannt,
    this.qualifikationen = const <Qualifikation>[],
    this.vollLesbar = true,
  });

  final Mitglied mitglied;
  final DateTime heute;
  final TeildatenStand efzStand;
  final List<EfzEinsichtnahme> efzEinsichtnahmen;
  final TeildatenStand qualifikationenStand;
  final List<Qualifikation> qualifikationen;

  /// Hitobito liefert Qualifikationen und EFZ nur fuer voll lesbare
  /// Personen. Sonst ist ein leerer Stand keine Aussage („Keines hinterlegt“
  /// waere falsch) und der Tab zeigt „Keine Berechtigung“.
  final bool vollLesbar;

  TeildatenStand get _efzStand =>
      vollLesbar ? efzStand : TeildatenStand.keineBerechtigung;
  TeildatenStand get _qualifikationenStand =>
      vollLesbar ? qualifikationenStand : TeildatenStand.keineBerechtigung;

  @override
  State<MemberQualifikationenTab> createState() =>
      _MemberQualifikationenTabState();
}

enum _Ton { gut, warnung, kritisch, leise }

class _MemberQualifikationenTabState extends State<MemberQualifikationenTab> {
  static const _berechneGueltigkeit = BerechneEfzGueltigkeitUseCase();

  bool _laedtAntrag = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final qualifikationen = widget.qualifikationen;
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
      children: [
        DpsgSectionHeader(label: t.t('quali_abschnitt_efz')),
        _karte(_efzZeile(context, t)),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            DpsgSectionHeader(label: t.t('quali_abschnitt_liste')),
            if (widget._qualifikationenStand == TeildatenStand.geladen &&
                qualifikationen.isNotEmpty) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${qualifikationen.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        _karte(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _qualifikationsZeilen(context, t),
          ),
        ),
        if (!widget.vollLesbar)
          LeserechteHinweis(
            text: t.t('leserechte_quali_hinweis'),
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          ),
      ],
    );
  }

  Widget _karte(Widget kind) => Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: kind,
    ),
  );

  Widget _efzZeile(BuildContext context, AppLocalizations t) {
    final (
      ton,
      hauptzeile,
      detail,
      downloadErlaubt,
    ) = switch (widget._efzStand) {
      TeildatenStand.keineBerechtigung => (
        _Ton.leise,
        t.t('quali_keine_berechtigung'),
        widget.vollLesbar ? t.t('quali_efz_keine_berechtigung_text') : null,
        false,
      ),
      TeildatenStand.unbekannt => (
        _Ton.leise,
        t.t('quali_nicht_synchronisiert'),
        t.t('quali_nicht_synchronisiert_text'),
        true,
      ),
      TeildatenStand.fehlgeschlagen => (
        _Ton.leise,
        t.t('quali_nicht_geladen'),
        t.t('quali_fehlgeschlagen'),
        true,
      ),
      TeildatenStand.geladen => _efzAusEinsichtnahmen(t),
    };

    return _StatusZeile(
      key: const ValueKey('efz-zeile'),
      ton: ton,
      oberzeile: t.t('quali_efz_titel'),
      hauptzeile: hauptzeile,
      detail: detail,
      aktion: downloadErlaubt
          ? IconButton(
              key: const Key('efz-antrag-download'),
              tooltip: t.t('quali_download'),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: _laedtAntrag ? null : _downloadAntrag,
              icon: _laedtAntrag
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 20),
            )
          : null,
    );
  }

  (_Ton, String, String?, bool) _efzAusEinsichtnahmen(AppLocalizations t) {
    final gueltigkeit = _berechneGueltigkeit(widget.efzEinsichtnahmen);
    final gueltigBis = gueltigkeit.gueltigBis;
    final status = berechneStatus(gueltigBis: gueltigBis, heute: widget.heute);
    return switch (status) {
      QualifikationsStatus.fehlt => (
        _Ton.leise,
        t.t('quali_efz_keines'),
        null,
        true,
      ),
      QualifikationsStatus.abgelaufen => (
        _Ton.kritisch,
        t.t('quali_efz_abgelaufen_am', {'datum': _datum(gueltigBis!)}),
        null,
        true,
      ),
      QualifikationsStatus.baldAblaufend => (
        _Ton.warnung,
        t.t('quali_efz_gueltig_bis', {'datum': _datum(gueltigBis!)}),
        t.t('quali_efz_noch', {
          'dauer': mitgliedDauerText(t, widget.heute, gueltigBis),
        }),
        true,
      ),
      QualifikationsStatus.gueltig => (
        _Ton.gut,
        t.t('quali_efz_gueltig_bis', {'datum': _datum(gueltigBis!)}),
        null,
        true,
      ),
    };
  }

  List<Widget> _qualifikationsZeilen(BuildContext context, AppLocalizations t) {
    final hinweis = switch (widget._qualifikationenStand) {
      TeildatenStand.unbekannt => t.t('quali_nicht_synchronisiert'),
      TeildatenStand.fehlgeschlagen => t.t('quali_fehlgeschlagen'),
      TeildatenStand.keineBerechtigung => t.t('quali_keine_berechtigung'),
      TeildatenStand.geladen =>
        widget.qualifikationen.isEmpty ? t.t('quali_keine') : null,
    };
    if (hinweis != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            hinweis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ];
    }

    final eintraege =
        widget.qualifikationen.map((q) => (q, _qualiStatus(q, t))).toList()
          ..sort((a, b) {
            final abgelaufenA = a.$2.$1 == _Ton.kritisch ? 1 : 0;
            final abgelaufenB = b.$2.$1 == _Ton.kritisch ? 1 : 0;
            if (abgelaufenA != abgelaufenB) {
              return abgelaufenA - abgelaufenB;
            }
            final datumA = a.$1.erworbenAm ?? DateTime(1900);
            final datumB = b.$1.erworbenAm ?? DateTime(1900);
            return datumB.compareTo(datumA);
          });
    return [
      for (final (quali, (ton, text)) in eintraege)
        _StatusZeile(
          ton: ton,
          hauptzeile: quali.label,
          detail: text,
          gedaempft: ton == _Ton.kritisch,
        ),
    ];
  }

  (_Ton, String) _qualiStatus(Qualifikation quali, AppLocalizations t) {
    final bis = quali.finishAt;
    final erworben = quali.erworbenAm;
    if (bis == null) {
      return (
        _Ton.leise,
        erworben == null
            ? t.t('quali_ohne_ablauf')
            : t.t('quali_erworben_ohne_ablauf', {'datum': _datum(erworben)}),
      );
    }
    return switch (berechneStatus(gueltigBis: bis, heute: widget.heute)) {
      QualifikationsStatus.abgelaufen || QualifikationsStatus.fehlt => (
        _Ton.kritisch,
        [
          t.t('quali_abgelaufen', {'datum': _datum(bis)}),
          if (quali.reaktivierbar) t.t('quali_reaktivierbar'),
        ].join(' · '),
      ),
      QualifikationsStatus.baldAblaufend => (
        _Ton.warnung,
        t.t('quali_gueltig_bis', {'datum': _datum(bis)}),
      ),
      QualifikationsStatus.gueltig => (
        _Ton.gut,
        t.t('quali_gueltig_bis', {'datum': _datum(bis)}),
      ),
    };
  }

  String _datum(DateTime datum) => DateFormatter.formatGermanShortDate(datum);

  T? _lies<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _downloadAntrag() async {
    final t = AppLocalizations.of(context);
    final personId = widget.mitglied.personId;
    final groupId = widget.mitglied.primaryGroupId;
    final accessToken = _lies<AuthSessionModel?>()?.session?.accessToken;
    final service = _lies<HitobitoEfzService>();
    if (personId == null ||
        groupId == null ||
        accessToken == null ||
        accessToken.isEmpty ||
        service == null) {
      _meldung(
        t.t('quali_download_fehlende_daten'),
        type: AppSnackbarType.warning,
      );
      return;
    }

    setState(() => _laedtAntrag = true);
    try {
      final bytes = await service.downloadEfzAntrag(
        accessToken,
        groupId: groupId,
        personId: personId,
      );
      if (!mounted) {
        return;
      }
      await _oeffnePdf(bytes, personId: personId);
    } on HitobitoEfzAntragUnavailableException {
      await _oeffneImBrowser(service, groupId: groupId, personId: personId);
    } catch (_) {
      if (mounted) {
        _meldung(t.t('quali_download_fehler'), type: AppSnackbarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _laedtAntrag = false);
      }
    }
  }

  Future<void> _oeffnePdf(List<int> bytes, {required int personId}) async {
    final ordner = await TeilenOrdner.verzeichnis();
    final file = File('${ordner.path}/efz_antrag_$personId.pdf');
    await file.writeAsBytes(bytes, flush: true);
    if (!mounted) {
      return;
    }
    final geoeffnet = await const PdfOeffnen().oeffnen(file);
    if (!mounted || geoeffnet) {
      return;
    }
    _meldung(
      AppLocalizations.of(context).t('quali_download_oeffnen_fehler'),
      type: AppSnackbarType.warning,
    );
  }

  Future<void> _oeffneImBrowser(
    HitobitoEfzService service, {
    required int groupId,
    required int personId,
  }) async {
    final fallbackUri = service.config.efzAntragUri(
      groupId: groupId,
      personId: personId,
    );
    var geoeffnet = false;
    if (fallbackUri != null) {
      geoeffnet = await launchUrl(
        fallbackUri,
        mode: LaunchMode.externalApplication,
      );
    }
    if (mounted && !geoeffnet) {
      _meldung(
        AppLocalizations.of(context).t('quali_download_oeffnen_fehler'),
        type: AppSnackbarType.error,
      );
    }
  }

  void _meldung(String message, {required AppSnackbarType type}) {
    AppSnackbar.show(context, message: message, type: type);
  }
}

class _StatusZeile extends StatelessWidget {
  const _StatusZeile({
    super.key,
    required this.ton,
    required this.hauptzeile,
    this.oberzeile,
    this.detail,
    this.aktion,
    this.gedaempft = false,
  });

  final _Ton ton;
  final String? oberzeile;
  final String hauptzeile;
  final String? detail;
  final Widget? aktion;
  final bool gedaempft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = StatusFarben.of(context);
    final gedimmt = theme.colorScheme.outlineVariant;
    final punktFarbe = switch (ton) {
      _Ton.gut => farben.gut,
      _Ton.warnung => farben.warnung,
      _Ton.kritisch => farben.kritisch,
      _Ton.leise => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            key: ValueKey('status-punkt-${ton.name}'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: punktFarbe,
              shape: BoxShape.circle,
              border: punktFarbe == null
                  ? Border.all(color: gedimmt, width: 2)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (oberzeile != null)
                  Text(
                    oberzeile!,
                    style: theme.textTheme.bodySmall?.copyWith(color: gedimmt),
                  ),
                Text(
                  hauptzeile,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: gedaempft ? gedimmt : null,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(color: gedimmt),
                  ),
              ],
            ),
          ),
          if (aktion != null) ...[const SizedBox(width: 8), aktion!],
        ],
      ),
    );
  }
}
