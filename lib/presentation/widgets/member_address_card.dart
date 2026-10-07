import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:nami/data/settings/shared_prefs_address_settings_repository.dart';
import 'package:nami/domain/maps/address_map_location_repository.dart';
import 'package:nami/domain/member/member_address_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/address_settings_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:nami/presentation/widgets/address_map_preview.dart';
import 'package:nami/presentation/widgets/member_basis_info_card.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/map_tile_cache_service.dart';
import 'package:nami/services/maps_env.dart';

const double _memberAddressCardRadius = 16;

Future<bool> _launchMapQuery(String query) async {
  try {
    await MapLauncher.marker(Location.search(query)).show();
    return true;
  } catch (_) {
    return false;
  }
}

/// Hauptadresse mit Kartenvorschau; Zusatzadressen sind eingeklappt.
class MemberAddressCard extends StatefulWidget {
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
  State<MemberAddressCard> createState() => _MemberAddressCardState();
}

class _MemberAddressCardState extends State<MemberAddressCard> {
  bool _offen = false;

  @override
  Widget build(BuildContext context) {
    final address = widget.mitglied.primaryAddress;
    final weitere = widget.mitglied.additionalAddresses
        .where((adresse) => !adresse.istLeer)
        .toList(growable: false);
    if (address == null && weitere.isEmpty) {
      return const SizedBox.shrink();
    }
    final t = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_memberAddressCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address != null) ...[
            _AdressZeile(
              adresse: address,
              label: t.t('member_address_wohnort'),
              icon: Icons.location_on,
              onLaunchAddress: widget.onLaunchAddress,
            ),
            _karte(context, address),
          ],
          if (weitere.isNotEmpty) ...[
            if (_offen || address == null)
              for (final adresse in weitere)
                _AdressZeile(
                  adresse: adresse,
                  label: adresse.label?.trim().isNotEmpty == true
                      ? adresse.label!.trim()
                      : t.t('member_address_wohnort'),
                  icon: Icons.place_outlined,
                  onLaunchAddress: widget.onLaunchAddress,
                ),
            if (address != null)
              MemberAufklappZeile(
                offen: _offen,
                text: _offen
                    ? t.t('member_contact_less')
                    : weitere.length == 1
                    ? t.t('member_address_more_one')
                    : t.t('member_address_more', {'n': weitere.length}),
                onTap: () => setState(() => _offen = !_offen),
              ),
          ],
        ],
      ),
    );
  }

  Widget _karte(BuildContext context, MitgliedKontaktAdresse address) {
    final addressFingerprint = MemberAddressUtils.fingerprint(address);
    final mapQueryAddress = MemberAddressUtils.formatMapQueryAddress(address);
    final stammRepository =
        widget.addressSettingsRepository ??
        SharedPrefsAddressSettingsRepository();
    final weitereVorhanden = widget.mitglied.additionalAddresses.any(
      (adresse) => !adresse.istLeer,
    );
    return FutureBuilder<String?>(
      future: stammRepository.loadAddress(),
      builder: (context, snapshot) {
        final stammAddress = snapshot.data?.trim();
        final stammFingerprint = (stammAddress?.isNotEmpty ?? false)
            ? MemberAddressUtils.fingerprintFromText(stammAddress!)
            : null;
        return AddressMapPreview(
          addressText: MemberAddressUtils.formatGeocodingAddress(address),
          cacheKey: addressFingerprint,
          addressFingerprint: addressFingerprint,
          secondaryAddressText: (stammAddress?.isNotEmpty ?? false)
              ? stammAddress
              : null,
          secondaryCacheKey: stammFingerprint,
          secondaryAddressFingerprint: stammFingerprint,
          previewTimeout: widget.previewTimeout ?? const Duration(seconds: 5),
          repository: widget.addressLocationRepository,
          mapService: widget.mapService,
          tileCacheService: widget.tileCacheService,
          offlineDownloadRadiusKm: MapsEnv.memberOfflineRadiusKm,
          height: 186,
          borderRadius: weitereVorhanden
              ? BorderRadius.zero
              : const BorderRadius.vertical(
                  bottom: Radius.circular(_memberAddressCardRadius),
                ),
          onOpenInMaps: mapQueryAddress.isEmpty
              ? null
              : () => _openInMaps(context, mapQueryAddress),
        );
      },
    );
  }

  Future<void> _openInMaps(BuildContext context, String query) async {
    final launch = widget.onLaunchAddress ?? _launchMapQuery;
    final success = await launch(query);
    if (!context.mounted || success) {
      return;
    }
    AppSnackbar.show(
      context,
      message: AppLocalizations.of(
        context,
      ).t('member_address_open_maps_failed'),
      type: AppSnackbarType.error,
    );
  }
}

class _AdressZeile extends StatelessWidget {
  const _AdressZeile({
    required this.adresse,
    required this.label,
    required this.icon,
    this.onLaunchAddress,
  });

  final MitgliedKontaktAdresse adresse;
  final String label;
  final IconData icon;
  final Future<bool> Function(String addressQuery)? onLaunchAddress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: _AddressLink(
        displayAddress: MemberAddressUtils.formatCompactDisplayAddress(adresse),
        queryAddress: MemberAddressUtils.formatMapQueryAddress(adresse),
        onLaunchAddress: onLaunchAddress,
      ),
      subtitle: Text(label),
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
    final linkStyle = textStyle?.copyWith(decoration: TextDecoration.none);

    if (displayAddress.isEmpty || queryAddress.isEmpty) {
      return Text(displayAddress, style: textStyle);
    }

    return InkWell(
      onTap: () async {
        final launch = onLaunchAddress ?? _launchMapQuery;
        final success = await launch(queryAddress);
        if (!context.mounted || success) {
          return;
        }
        AppSnackbar.show(
          context,
          message: AppLocalizations.of(
            context,
          ).t('member_address_open_maps_failed'),
          type: AppSnackbarType.error,
        );
      },
      child: Text(displayAddress, style: linkStyle),
    );
  }
}
