import 'package:flutter/material.dart';
import 'package:nami/domain/maps/address_map_location_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member_filters/beitragsart.dart';
import 'package:nami/domain/settings/address_settings_repository.dart';
import 'package:nami/presentation/widgets/member_address_card.dart';
import 'package:nami/presentation/widgets/section_header.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/map_tile_cache_service.dart';

import 'member_basis_info_card.dart';

/// Kombiniertes Detail-Widget für ein Mitglied.
/// Enthält allgemeine Infos + Mitgliedschafts-Infos untereinander.
class MemberDetails extends StatelessWidget {
  const MemberDetails({
    super.key,
    required this.mitglied,
    this.beitragsart,
    this.stammNamen = const <String>[],
    this.gruppenNamen = const <String>[],
    this.onEndMembership,
    this.addressLocationRepository,
    this.mapService,
    this.addressSettingsRepository,
    this.tileCacheService,
    this.previewTimeout,
    this.leadingChildren = const <Widget>[],
    this.spacing = 8,
    this.showGeneralInfo = true,
    this.showMembershipInfo = true,
  });

  final Mitglied mitglied;
  final Beitragsart? beitragsart;
  final List<String> stammNamen;
  final List<String> gruppenNamen;
  final VoidCallback? onEndMembership;
  final AddressMapLocationRepository? addressLocationRepository;
  final GeoapifyAddressMapService? mapService;
  final AddressSettingsRepository? addressSettingsRepository;
  final MapTileCacheService? tileCacheService;
  final Duration? previewTimeout;
  final List<Widget> leadingChildren;
  final double spacing;
  final bool showGeneralInfo;
  final bool showMembershipInfo;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (leadingChildren.isNotEmpty) {
      children.addAll(leadingChildren);
      children.add(SizedBox(height: spacing));
    }
    if (showGeneralInfo) {
      children.add(const DpsgSectionHeader(label: 'Persönliche Daten'));
      children.add(MemberGeneralInfoCard(mitglied: mitglied));
      children.add(SizedBox(height: spacing));
      children.add(const DpsgSectionHeader(label: 'Kontakt'));
      children.add(MemberContactInfoCard(mitglied: mitglied));
    }
    if (showGeneralInfo && mitglied.primaryAddress != null) {
      children.add(SizedBox(height: spacing));
      children.add(const DpsgSectionHeader(label: 'Adresse'));
      children.add(
        MemberAddressCard(
          mitglied: mitglied,
          addressLocationRepository: addressLocationRepository,
          mapService: mapService,
          addressSettingsRepository: addressSettingsRepository,
          tileCacheService: tileCacheService,
          previewTimeout: previewTimeout,
        ),
      );
    }
    if ((showGeneralInfo || mitglied.primaryAddress != null) &&
        showMembershipInfo) {
      children.add(SizedBox(height: spacing));
    }
    if (showMembershipInfo) {
      children.add(const DpsgSectionHeader(label: 'Mitgliedschaft'));
      children.add(
        MemberMembershipInfoCard(
          mitglied: mitglied,
          beitragsart: beitragsart,
          stammNamen: stammNamen,
          gruppenNamen: gruppenNamen,
          onEndMembership: onEndMembership,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      children: <Widget>[...children],
    );
  }
}
