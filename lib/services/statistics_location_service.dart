import 'package:latlong2/latlong.dart';

import '../data/maps/shared_prefs_address_map_location_repository.dart';
import '../domain/maps/address_map_location.dart';
import '../domain/maps/address_map_location_repository.dart';
import '../domain/member/member_address_utils.dart';
import '../domain/member/mitglied.dart';
import 'geoapify_address_map_service.dart';
import 'logger_service.dart';

class StatisticsResolvedLocations {
  const StatisticsResolvedLocations({
    required this.memberPoints,
    required this.stammPoint,
  });

  final List<LatLng> memberPoints;
  final LatLng? stammPoint;
}

class StatisticsLocationService {
  StatisticsLocationService({
    AddressMapLocationRepository? repository,
    GeoapifyAddressMapService? mapService,
    LoggerService? logger,
  }) : _repository = repository ?? SharedPrefsAddressMapLocationRepository(),
       _mapService = mapService ?? GeoapifyAddressMapService(logger: logger),
       _logger = logger;

  final AddressMapLocationRepository _repository;
  final GeoapifyAddressMapService _mapService;
  final LoggerService? _logger;

  Future<StatisticsResolvedLocations> resolveLocations({
    required Iterable<Mitglied> members,
    String? stammAddress,
  }) async {
    final memberPoints = await resolveMemberLocations(members);
    final stammPoint = await resolveAddressText(stammAddress);
    return StatisticsResolvedLocations(
      memberPoints: memberPoints,
      stammPoint: stammPoint,
    );
  }

  Future<List<LatLng>> resolveMemberLocations(Iterable<Mitglied> members) async {
    final byFingerprint = <String, MitgliedKontaktAdresse>{};

    for (final member in members) {
      final address = member.primaryAddress;
      if (address == null) {
        continue;
      }
      final fingerprint = MemberAddressUtils.fingerprint(address);
      byFingerprint.putIfAbsent(fingerprint, () => address);
    }

    final points = <LatLng>[];
    final seenPoints = <String>{};

    for (final entry in byFingerprint.entries) {
      final fingerprint = entry.key;
      final address = entry.value;

      final cached = await _repository.load(fingerprint);
      if (cached != null) {
        if (cached.addressNotFound) {
          continue;
        }
        if (cached.hasCoordinates) {
          final point = LatLng(cached.latitude!, cached.longitude!);
          final pointKey = '${point.latitude.toStringAsFixed(6)}:${point.longitude.toStringAsFixed(6)}';
          if (seenPoints.add(pointKey)) {
            points.add(point);
          }
          continue;
        }
      }

      final addressText = MemberAddressUtils.formatSingleLineAddress(address);
      if (addressText.trim().isEmpty) {
        continue;
      }

      final result = await _mapService.resolveAddress(addressText);
      if (result.addressNotFound) {
        await _repository.save(
          AddressMapLocation(
            cacheKey: fingerprint,
            resolvedAt: DateTime.now(),
            addressFingerprint: fingerprint,
            addressNotFound: true,
          ),
        );
        continue;
      }
      final location = result.location;
      if (location == null) {
        await _logger?.log(
          'statistics',
          'Standort fuer Statistik konnte nicht aufgeloest werden: $fingerprint',
        );
        continue;
      }

      await _repository.save(
        AddressMapLocation(
          cacheKey: fingerprint,
          latitude: location.latitude,
          longitude: location.longitude,
          resolvedAt: DateTime.now(),
          addressFingerprint: fingerprint,
        ),
      );

      final pointKey =
          '${location.latitude.toStringAsFixed(6)}:${location.longitude.toStringAsFixed(6)}';
      if (seenPoints.add(pointKey)) {
        points.add(location);
      }
    }

    return points;
  }

  Future<LatLng?> resolveAddressText(String? addressText) async {
    final normalizedAddress = (addressText ?? '').trim();
    if (normalizedAddress.isEmpty) {
      return null;
    }

    final fingerprint = MemberAddressUtils.fingerprintFromText(normalizedAddress);
    final cached = await _repository.load(fingerprint);
    if (cached != null) {
      if (cached.addressNotFound || !cached.hasCoordinates) {
        return null;
      }
      return LatLng(cached.latitude!, cached.longitude!);
    }

    final result = await _mapService.resolveAddress(normalizedAddress);
    if (result.addressNotFound) {
      await _repository.save(
        AddressMapLocation(
          cacheKey: fingerprint,
          resolvedAt: DateTime.now(),
          addressFingerprint: fingerprint,
          addressNotFound: true,
        ),
      );
      return null;
    }

    final location = result.location;
    if (location == null) {
      await _logger?.log(
        'statistics',
        'Stamm-Standort konnte nicht aufgeloest werden: $fingerprint',
      );
      return null;
    }

    await _repository.save(
      AddressMapLocation(
        cacheKey: fingerprint,
        latitude: location.latitude,
        longitude: location.longitude,
        resolvedAt: DateTime.now(),
        addressFingerprint: fingerprint,
      ),
    );

    return location;
  }
}
