import 'package:flutter/material.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/qualifikation/ermittle_qualifikations_uebersicht_usecase.dart';
import 'package:nami/domain/qualifikation/qualifikations_einstellungen.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/qualifikations_einstellungen_model.dart';
import 'package:nami/presentation/screens/qualifikationen/qualifikation_einstellungen_page.dart';
import 'package:nami/presentation/widgets/section_header.dart';
import 'package:nami/presentation/widgets/stufen_choice_chips.dart';
import 'package:provider/provider.dart';

class SettingsNotificationPage extends StatefulWidget {
  final bool notificationsEnabled;
  final ValueChanged<bool>? onNotificationsChanged;
  final Set<Stufe> geburstagsbenachrichtigungStufen;
  final void Function(Set<Stufe> stufen)?
  geburstagsbenachrichtigungStufenChanged;

  const SettingsNotificationPage({
    super.key,
    this.notificationsEnabled = true,
    this.onNotificationsChanged,
    this.geburstagsbenachrichtigungStufen = const {
      Stufe.biber,
      Stufe.woelfling,
      Stufe.jungpfadfinder,
      Stufe.pfadfinder,
      Stufe.rover,
      Stufe.leitung,
    },
    this.geburstagsbenachrichtigungStufenChanged,
    this.readModel,
  });

  /// Fuer Stories und Tests; sonst aus dem ArbeitskontextModel.
  final ArbeitskontextReadModel? readModel;

  @override
  State<SettingsNotificationPage> createState() =>
      _SettingsNotificationPageState();
}

class _SettingsNotificationPageState extends State<SettingsNotificationPage> {
  late bool _notificationsEnabled;
  late bool _birthdayEnabled;
  late Set<Stufe> _geburstagsbenachrichtigungStufen;

  /// Auswahl vor dem Ausschalten, damit sie beim Einschalten zurueckkommt.
  late Set<Stufe> _letzteGeburtstagsStufen;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.notificationsEnabled;
    _geburstagsbenachrichtigungStufen = widget.geburstagsbenachrichtigungStufen;
    // Ausgeschaltet heisst: keine Stufe gewaehlt.
    _birthdayEnabled = _geburstagsbenachrichtigungStufen.isNotEmpty;
    _letzteGeburtstagsStufen = _birthdayEnabled
        ? _geburstagsbenachrichtigungStufen
        : Stufe.values.toSet();
  }

  void _setGeburtstagsStufen(Set<Stufe> stufen) {
    setState(() => _geburstagsbenachrichtigungStufen = stufen);
    widget.geburstagsbenachrichtigungStufenChanged?.call(stufen);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('settings_notifications'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              title: Text(t.t('notifications_enable')),
              subtitle: const Text('Push-Mitteilungen empfangen'),
              value: _notificationsEnabled,
              onChanged: (v) {
                setState(() => _notificationsEnabled = v);
                widget.onNotificationsChanged?.call(v);
              },
            ),
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: _notificationsEnabled ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !_notificationsEnabled,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('geburtstag-schalter'),
                        title: const Text('Geburtstagserinnerungen'),
                        subtitle: Text(t.t('geburtstag_einstellung_hinweis')),
                        value: _birthdayEnabled,
                        onChanged: (v) {
                          setState(() => _birthdayEnabled = v);
                          if (v) {
                            _setGeburtstagsStufen(_letzteGeburtstagsStufen);
                          } else {
                            if (_geburstagsbenachrichtigungStufen.isNotEmpty) {
                              _letzteGeburtstagsStufen =
                                  _geburstagsbenachrichtigungStufen;
                            }
                            _setGeburtstagsStufen(const <Stufe>{});
                          }
                        },
                      ),
                      if (_birthdayEnabled) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stufen',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              StufenChoiceChips(
                                singleSelect: false,
                                showBiber: true,
                                showLeader: true,
                                ausgewaehlteStufen:
                                    _geburstagsbenachrichtigungStufen,
                                ausgewaehlteStufenChanged:
                                    _setGeburtstagsStufen,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          _MeineQualifikationen(
            aktiv: _notificationsEnabled,
            readModel:
                widget.readModel ??
                context.watch<ArbeitskontextModel?>()?.readModel,
          ),
        ],
      ),
    );
  }
}

/// Erinnerung an die eigenen Qualifikationen, frei fuer alle Nutzer.
class _MeineQualifikationen extends StatelessWidget {
  const _MeineQualifikationen({required this.aktiv, required this.readModel});

  final bool aktiv;
  final ArbeitskontextReadModel? readModel;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<QualifikationsEinstellungenModel?>();
    if (model == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final eigene = model.einstellungen.eigene;
    final readModel = this.readModel;
    final katalog = readModel == null
        ? const <KatalogEintrag>[]
        : const ErmittleQualifikationsUebersichtUseCase().katalog(
            readModel: readModel,
            einstellungen: model.einstellungen,
          );
    final gewaehlt =
        eigene.arten ??
        {
          for (final eintrag in katalog)
            if (QualifikationsVorgaben.istVorgabe(
              eintrag.art.schluessel,
              eintrag.art.label,
            ))
              eintrag.art.schluessel,
        };

    Future<void> speichern(EigeneQualifikationsErinnerung neu) =>
        model.aendern((alt) => alt.copyWith(eigene: neu));

    return Opacity(
      opacity: aktiv ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !aktiv,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            DpsgSectionHeader(label: t.t('quali_meine_titel')),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      key: const Key('quali-meine-schalter'),
                      title: Text(t.t('quali_meine_schalter')),
                      subtitle: Text(t.t('quali_meine_schalter_hinweis')),
                      value: eigene.aktiv,
                      onChanged: (wert) =>
                          speichern(eigene.copyWith(aktiv: wert)),
                    ),
                    if (eigene.aktiv)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.t('quali_meine_welche'),
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            if (katalog.isEmpty)
                              Text(
                                t.t('quali_meine_keine_arten'),
                                style: theme.textTheme.bodySmall,
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final eintrag in katalog)
                                    FilterChip(
                                      key: Key(
                                        'quali-meine-${eintrag.art.schluessel}',
                                      ),
                                      label: Text(
                                        eintrag.art.istEfz
                                            ? 'EFZ'
                                            : eintrag.art.label,
                                      ),
                                      selected: gewaehlt.contains(
                                        eintrag.art.schluessel,
                                      ),
                                      onSelected:
                                          eintrag.art.gueltigkeitJahre == null
                                          ? null
                                          : (an) => speichern(
                                              eigene.copyWith(
                                                arten: {
                                                  ...gewaehlt.where(
                                                    (s) =>
                                                        s !=
                                                        eintrag.art.schluessel,
                                                  ),
                                                  if (an)
                                                    eintrag.art.schluessel,
                                                },
                                              ),
                                            ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.t('quali_meine_wann'),
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ),
                                QualifikationTageStepper(
                                  tage: eigene.tageVorher,
                                  onAendern: (tage) => speichern(
                                    eigene.copyWith(tageVorher: tage),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                t.t('quali_meine_fuss'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
