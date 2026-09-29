import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/member/efz_einsichtnahme.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/qualifikation/ermittle_qualifikations_uebersicht_usecase.dart';
import '../../domain/qualifikation/qualifikations_status.dart';
import '../../domain/qualifikation/qualifikationsart.dart';
import '../../services/hitobito_efz_service.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';
import '../navigation/app_router.dart';
import '../widgets/qualifikations_status_badge.dart';
import 'member_detail_page.dart';

/// Qualifikationen-Uebersicht fuer Leitende: zeigt den EFZ-Status aller
/// aktiven Leitenden im aktuellen Arbeitskontext (ein Stamm), mit Filter nach
/// Qualifikationsart. Erreichbar ueber Einstellungen -> Schnellzugriff.
class SettingsQualifikationenPage extends StatefulWidget {
  const SettingsQualifikationenPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<SettingsQualifikationenPage> createState() =>
      _SettingsQualifikationenPageState();
}

class _SettingsQualifikationenPageState
    extends State<SettingsQualifikationenPage> {
  static const _useCase = ErmittleQualifikationsUebersichtUseCase();

  Qualifikationsart _selectedQualifikationsart = efzQualifikationsart;
  Future<List<EfzEinsichtnahme>>? _future;

  Future<List<EfzEinsichtnahme>> _loadEinsichtnahmen() {
    final accessToken = context.read<AuthSessionModel?>()?.session?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      return Future.value(const <EfzEinsichtnahme>[]);
    }
    final service = context.read<HitobitoEfzService>();
    return service.fetchAlleEfzEinsichtnahmen(accessToken);
  }

  Future<void> _openMemberDetails(Mitglied mitglied) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: AppRoutes.memberDetail,
          arguments: mitglied.mitgliedsnummer,
        ),
        builder: (_) => MemberDetailPage(mitglied: mitglied),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readModel = context.watch<ArbeitskontextModel>().readModel;
    _future ??= _loadEinsichtnahmen();

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Qualifikationen'))
          : null,
      body: readModel == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<EfzEinsichtnahme>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const _QualifikationenStatusView(
                    icon: Icons.error_outline,
                    title: 'Qualifikationen konnten nicht geladen werden',
                    message: 'Bitte versuche es später erneut.',
                  );
                }

                final einsichtnahmen =
                    snapshot.data ?? const <EfzEinsichtnahme>[];
                final eintraege = _useCase(
                  readModel: readModel,
                  einsichtnahmen: einsichtnahmen,
                  qualifikationsart: _selectedQualifikationsart,
                );

                return _QualifikationenContent(
                  eintraege: eintraege,
                  selectedQualifikationsart: _selectedQualifikationsart,
                  onQualifikationsartChanged: (art) =>
                      setState(() => _selectedQualifikationsart = art),
                  onMemberTap: _openMemberDetails,
                );
              },
            ),
    );
  }
}

class _QualifikationenContent extends StatelessWidget {
  const _QualifikationenContent({
    required this.eintraege,
    required this.selectedQualifikationsart,
    required this.onQualifikationsartChanged,
    required this.onMemberTap,
  });

  final List<QualifikationsUebersichtEintrag> eintraege;
  final Qualifikationsart selectedQualifikationsart;
  final ValueChanged<Qualifikationsart> onQualifikationsartChanged;
  final ValueChanged<Mitglied> onMemberTap;

  @override
  Widget build(BuildContext context) {
    final ohneGueltigenNachweis = eintraege
        .where((eintrag) => eintrag.status != QualifikationsStatus.gueltig)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final qualifikationsart in alleQualifikationsarten)
              ChoiceChip(
                label: Text(qualifikationsart.label),
                selected:
                    qualifikationsart.key == selectedQualifikationsart.key,
                onSelected: (_) =>
                    onQualifikationsartChanged(qualifikationsart),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$ohneGueltigenNachweis von ${eintraege.length}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'ohne gültiges ${selectedQualifikationsart.label}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (eintraege.isEmpty)
          const _QualifikationenStatusView(
            icon: Icons.info_outline,
            title: 'Keine Leitenden gefunden',
            message:
                'Im aktuellen Arbeitskontext sind keine aktiven Leitenden vorhanden.',
          )
        else
          for (var i = 0; i < eintraege.length; i++) ...[
            _QualifikationEintragRow(
              eintrag: eintraege[i],
              onTap: () => onMemberTap(eintraege[i].mitglied),
            ),
            if (i < eintraege.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _QualifikationEintragRow extends StatelessWidget {
  const _QualifikationEintragRow({required this.eintrag, required this.onTap});

  final QualifikationsUebersichtEintrag eintrag;
  final VoidCallback onTap;

  static final _dateFormat = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mitglied = eintrag.mitglied;
    final gueltigBis = eintrag.gueltigBis;

    return InkWell(
      key: Key('qualifikation-member-row-${mitglied.mitgliedsnummer}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _memberName(mitglied),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gueltigBis == null
                        ? 'Keine Einsichtnahme hinterlegt'
                        : 'Gültig bis ${_dateFormat.format(gueltigBis)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
            QualifikationsStatusBadge(status: eintrag.status),
          ],
        ),
      ),
    );
  }
}

class _QualifikationenStatusView extends StatelessWidget {
  const _QualifikationenStatusView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _memberName(Mitglied mitglied) {
  final fahrtenname = mitglied.fahrtenname?.trim();
  if (fahrtenname != null && fahrtenname.isNotEmpty) {
    return fahrtenname;
  }
  final fullName = '${mitglied.vorname} ${mitglied.nachname}'.trim();
  return fullName.isEmpty ? mitglied.mitgliedsnummer : fullName;
}
