import 'package:flutter/material.dart';
import 'package:nami/domain/maps/address_map_location_repository.dart';
import 'package:nami/domain/member/member_address_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/widgets/address_map_preview.dart';
import 'package:nami/services/geoapify_address_map_service.dart';

class MemberAddressCard extends StatelessWidget {
  const MemberAddressCard({
    super.key,
    required this.mitglied,
    this.addressLocationRepository,
    this.mapService,
    this.previewTimeout,
  });

  final Mitglied mitglied;
  final AddressMapLocationRepository? addressLocationRepository;
  final GeoapifyAddressMapService? mapService;
  final Duration? previewTimeout;

  @override
  Widget build(BuildContext context) {
    final address = mitglied.primaryAddress;
    if (address == null) {
      return const SizedBox.shrink();
    }

    final formattedAddress = MemberAddressUtils.formatMultilineAddress(address);
    final cacheKey = mitglied.primaryAddressCacheKey;

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
                Text(
                  formattedAddress,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (cacheKey != null) ...[
                  const SizedBox(height: 16),
                  AddressMapPreview(
                    addressText: MemberAddressUtils.formatSingleLineAddress(
                      address,
                    ),
                    cacheKey: cacheKey,
                    addressFingerprint: MemberAddressUtils.fingerprint(address),
                    previewTimeout:
                        previewTimeout ?? const Duration(seconds: 5),
                    repository: addressLocationRepository,
                    mapService: mapService,
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
