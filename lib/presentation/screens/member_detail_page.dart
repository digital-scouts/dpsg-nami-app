import 'package:flutter/material.dart';

import '../../domain/maps/address_map_location_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/settings/address_settings_repository.dart';
import '../../services/geoapify_address_map_service.dart';
import '../../services/map_tile_cache_service.dart';
import '../widgets/member_basis.dart';

class MemberDetailPage extends StatelessWidget {
  const MemberDetailPage({
    super.key,
    required this.mitglied,
    this.addressLocationRepository,
    this.mapService,
    this.addressSettingsRepository,
    this.tileCacheService,
    this.previewTimeout,
  });

  final Mitglied mitglied;
  final AddressMapLocationRepository? addressLocationRepository;
  final GeoapifyAddressMapService? mapService;
  final AddressSettingsRepository? addressSettingsRepository;
  final MapTileCacheService? tileCacheService;
  final Duration? previewTimeout;

  @override
  Widget build(BuildContext context) {
    final title = mitglied.fullName.trim().isEmpty
        ? mitglied.mitgliedsnummer
        : mitglied.fullName;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: MemberDetails(
        mitglied: mitglied,
        addressLocationRepository: addressLocationRepository,
        mapService: mapService,
        addressSettingsRepository: addressSettingsRepository,
        tileCacheService: tileCacheService,
        previewTimeout: previewTimeout,
      ),
    );
  }
}
