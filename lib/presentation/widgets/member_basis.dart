import 'package:flutter/material.dart';
import 'package:nami/domain/maps/address_map_location_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member_filters/beitragsart.dart';
import 'package:nami/domain/settings/address_settings_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/format/date_formatters.dart';
import 'package:nami/presentation/widgets/app_lesebreite.dart';
import 'package:nami/presentation/widgets/member_address_card.dart';
import 'package:nami/presentation/widgets/member_detail/member_fakt_kacheln.dart';
import 'package:nami/presentation/widgets/member_detail/member_familie_chips.dart';
import 'package:nami/presentation/widgets/section_header.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/map_tile_cache_service.dart';

import 'member_basis_info_card.dart';

/// Daten-Tab eines Mitglieds: Kacheln zu Geburtstag und Mitgliedsdauer,
/// Familie, Kontakt, Adresse und Details.
class MemberDetails extends StatelessWidget {
  const MemberDetails({
    super.key,
    required this.mitglied,
    this.heute,
    this.beitragsart,
    this.stammNamen = const <String>[],
    this.gruppenNamen = const <String>[],
    this.haushalt = const <Mitglied>[],
    this.onHaushaltTap,
    this.onEndMembership,
    this.addressLocationRepository,
    this.mapService,
    this.addressSettingsRepository,
    this.tileCacheService,
    this.previewTimeout,
    this.leadingChildren = const <Widget>[],
    this.spacing = 8,
  });

  final Mitglied mitglied;

  /// Stichtag fuer Geburtstag, Dauer und Austritt; Standard ist heute.
  final DateTime? heute;
  final Beitragsart? beitragsart;
  final List<String> stammNamen;
  final List<String> gruppenNamen;

  /// Sichtbare Mitglieder im selben Haushalt.
  final List<Mitglied> haushalt;
  final ValueChanged<Mitglied>? onHaushaltTap;
  final VoidCallback? onEndMembership;
  final AddressMapLocationRepository? addressLocationRepository;
  final GeoapifyAddressMapService? mapService;
  final AddressSettingsRepository? addressSettingsRepository;
  final MapTileCacheService? tileCacheService;
  final Duration? previewTimeout;
  final List<Widget> leadingChildren;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final stichtag = heute ?? DateTime.now();
    final austritt = mitglied.austrittsdatum;
    final hatAdresse =
        mitglied.primaryAddress != null ||
        mitglied.additionalAddresses.any((adresse) => !adresse.istLeer);
    final abstand = SizedBox(height: spacing * 2);

    return AppLesebreite(
      builder: (context, rand) => ListView(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 16) + rand,
        children: <Widget>[
          ...leadingChildren,
          if (austritt != null && !austritt.isAfter(stichtag)) ...[
            _AustrittsHinweis(
              text: t.t('member_detail_ausgetreten_zum', {
                'datum': DateFormatter.formatGermanShortDate(austritt),
              }),
            ),
            SizedBox(height: spacing),
          ],
          MemberFaktKacheln(mitglied: mitglied, heute: stichtag),
          if (haushalt.isNotEmpty) ...[
            abstand,
            DpsgSectionHeader(label: t.t('member_detail_familie')),
            MemberFamilieChips(
              haushalt: haushalt,
              heute: stichtag,
              onTap: onHaushaltTap,
            ),
          ],
          abstand,
          DpsgSectionHeader(label: t.t('member_detail_kontakt')),
          MemberContactInfoCard(mitglied: mitglied),
          if (hatAdresse) ...[
            abstand,
            DpsgSectionHeader(label: t.t('member_detail_adresse')),
            MemberAddressCard(
              mitglied: mitglied,
              addressLocationRepository: addressLocationRepository,
              mapService: mapService,
              addressSettingsRepository: addressSettingsRepository,
              tileCacheService: tileCacheService,
              previewTimeout: previewTimeout,
            ),
          ],
          abstand,
          DpsgSectionHeader(label: t.t('member_detail_details')),
          MemberMembershipInfoCard(
            mitglied: mitglied,
            beitragsart: beitragsart,
            stammNamen: stammNamen,
            gruppenNamen: gruppenNamen,
            onEndMembership: onEndMembership,
          ),
        ],
      ),
    );
  }
}

class _AustrittsHinweis extends StatelessWidget {
  const _AustrittsHinweis({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_busy_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
