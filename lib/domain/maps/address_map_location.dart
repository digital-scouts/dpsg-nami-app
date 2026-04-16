class AddressMapLocation {
  const AddressMapLocation({
    required this.cacheKey,
    required this.resolvedAt,
    this.latitude,
    this.longitude,
    this.addressFingerprint,
    this.addressNotFound = false,
  });

  final String cacheKey;
  final double? latitude;
  final double? longitude;
  final DateTime resolvedAt;
  final String? addressFingerprint;
  final bool addressNotFound;

  bool get hasCoordinates => latitude != null && longitude != null;

  AddressMapLocation copyWith({
    String? cacheKey,
    double? latitude,
    double? longitude,
    DateTime? resolvedAt,
    String? addressFingerprint,
    bool? addressNotFound,
    bool addressFingerprintLoeschen = false,
  }) => AddressMapLocation(
    cacheKey: cacheKey ?? this.cacheKey,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    addressFingerprint: addressFingerprintLoeschen
        ? null
        : addressFingerprint ?? this.addressFingerprint,
    addressNotFound: addressNotFound ?? this.addressNotFound,
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cache_key': cacheKey,
      'latitude': latitude,
      'longitude': longitude,
      'resolved_at': resolvedAt.toIso8601String(),
      'address_fingerprint': addressFingerprint,
      'address_not_found': addressNotFound,
    };
  }

  factory AddressMapLocation.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final resolvedAtRaw = json['resolved_at']?.toString();
    final resolvedAt = resolvedAtRaw == null
        ? null
        : DateTime.tryParse(resolvedAtRaw);
    final addressNotFound = json['address_not_found'] == true;
    if (resolvedAt == null ||
        (!addressNotFound && (latitude == null || longitude == null))) {
      throw const FormatException('Ungueltiger AddressMapLocation-Eintrag.');
    }

    return AddressMapLocation(
      cacheKey: json['cache_key']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      resolvedAt: resolvedAt,
      addressFingerprint: json['address_fingerprint']?.toString(),
      addressNotFound: addressNotFound,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AddressMapLocation &&
        other.cacheKey == cacheKey &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.resolvedAt == resolvedAt &&
        other.addressFingerprint == addressFingerprint &&
        other.addressNotFound == addressNotFound;
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    latitude,
    longitude,
    resolvedAt,
    addressFingerprint,
    addressNotFound,
  );
}
