class AddressMapLocation {
  const AddressMapLocation({
    required this.cacheKey,
    required this.latitude,
    required this.longitude,
    required this.resolvedAt,
    this.addressFingerprint,
    this.previewImagePath,
  });

  final String cacheKey;
  final double latitude;
  final double longitude;
  final DateTime resolvedAt;
  final String? addressFingerprint;
  final String? previewImagePath;

  AddressMapLocation copyWith({
    String? cacheKey,
    double? latitude,
    double? longitude,
    DateTime? resolvedAt,
    String? addressFingerprint,
    String? previewImagePath,
    bool addressFingerprintLoeschen = false,
    bool previewImagePathLoeschen = false,
  }) => AddressMapLocation(
    cacheKey: cacheKey ?? this.cacheKey,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    addressFingerprint: addressFingerprintLoeschen
        ? null
        : addressFingerprint ?? this.addressFingerprint,
    previewImagePath: previewImagePathLoeschen
        ? null
        : previewImagePath ?? this.previewImagePath,
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cache_key': cacheKey,
      'latitude': latitude,
      'longitude': longitude,
      'resolved_at': resolvedAt.toIso8601String(),
      'address_fingerprint': addressFingerprint,
      'preview_image_path': previewImagePath,
    };
  }

  factory AddressMapLocation.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final resolvedAtRaw = json['resolved_at']?.toString();
    final resolvedAt = resolvedAtRaw == null
        ? null
        : DateTime.tryParse(resolvedAtRaw);
    if (latitude == null || longitude == null || resolvedAt == null) {
      throw const FormatException('Ungueltiger AddressMapLocation-Eintrag.');
    }

    return AddressMapLocation(
      cacheKey: json['cache_key']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      resolvedAt: resolvedAt,
      addressFingerprint: json['address_fingerprint']?.toString(),
      previewImagePath: json['preview_image_path']?.toString(),
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
        other.previewImagePath == previewImagePath;
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    latitude,
    longitude,
    resolvedAt,
    addressFingerprint,
    previewImagePath,
  );
}
