import 'package:flutter/material.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:nami/data/settings/shared_prefs_address_settings_repository.dart';
import 'package:nami/domain/maps/address_map_location_repository.dart';
import 'package:nami/domain/member/member_address_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/address_settings_repository.dart';
import 'package:nami/presentation/widgets/address_map_preview.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/map_tile_cache_service.dart';
import 'package:nami/services/maps_env.dart';

class MemberAddressCard extends StatelessWidget {
  const MemberAddressCard({
    super.key,
    required this.mitglied,
    this.addressLocationRepository,
    this.mapService,
    this.addressSettingsRepository,
    this.tileCacheService,
    this.previewTimeout,
    this.onLaunchAddress,
  });

  final Mitglied mitglied;
  final AddressMapLocationRepository? addressLocationRepository;
  final GeoapifyAddressMapService? mapService;
  final AddressSettingsRepository? addressSettingsRepository;
  final MapTileCacheService? tileCacheService;
  final Duration? previewTimeout;
  final Future<bool> Function(String addressQuery)? onLaunchAddress;

  @override
  Widget build(BuildContext context) {
    final address = mitglied.primaryAddress;
    if (address == null) {
      return const SizedBox.shrink();
    }

    final formattedAddress = MemberAddressUtils.formatCompactDisplayAddress(
      address,
    );
    final mapQueryAddress = MemberAddressUtils.formatMapQueryAddress(address);
    final cacheKey = mitglied.primaryAddressCacheKey;
    final stammRepository =
        addressSettingsRepository ?? SharedPrefsAddressSettingsRepository();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Adresse', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 5.0),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddressLink(
                  displayAddress: formattedAddress,
                  queryAddress: mapQueryAddress,
                  onLaunchAddress: onLaunchAddress,
                ),
                if (cacheKey != null) ...[
                  const SizedBox(height: 16),
                  FutureBuilder<String?>(
                    future: stammRepository.loadAddress(),
                    builder: (context, snapshot) {
                      final stammAddress = snapshot.data?.trim();
                      return AddressMapPreview(
                        addressText: MemberAddressUtils.formatSingleLineAddress(
                          address,
                        ),
                        cacheKey: cacheKey,
                        addressFingerprint: MemberAddressUtils.fingerprint(
                          address,
                        ),
                        secondaryAddressText:
                            (stammAddress?.isNotEmpty ?? false)
                            ? stammAddress
                            : null,
                        secondaryCacheKey: (stammAddress?.isNotEmpty ?? false)
                            ? 'stamm:0'
                            : null,
                        secondaryAddressFingerprint:
                            (stammAddress?.isNotEmpty ?? false)
                            ? MemberAddressUtils.fingerprintFromText(
                                stammAddress!,
                              )
                            : null,
                        previewTimeout:
                            previewTimeout ?? const Duration(seconds: 5),
                        repository: addressLocationRepository,
                        mapService: mapService,
                        tileCacheService: tileCacheService,
                        offlineDownloadRadiusKm: MapsEnv.memberOfflineRadiusKm,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressLink extends StatelessWidget {
  const _AddressLink({
    required this.displayAddress,
    required this.queryAddress,
    this.onLaunchAddress,
  });

  final String displayAddress;
  final String queryAddress;
  final Future<bool> Function(String addressQuery)? onLaunchAddress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.titleMedium;
    final linkStyle = textStyle?.copyWith(
      color: Colors.blue,
      decoration: TextDecoration.none,
    );

    if (displayAddress.isEmpty || queryAddress.isEmpty) {
      return Text(displayAddress, style: textStyle);
    }

    return InkWell(
      onTap: () async {
        final launch = onLaunchAddress ?? MapsLauncher.launchQuery;
        final success = await launch(queryAddress);
        if (!context.mounted || success) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kann Adresse nicht in Karten öffnen')),
        );
      },
      child: Text(displayAddress, style: linkStyle),
    );
  }
}
