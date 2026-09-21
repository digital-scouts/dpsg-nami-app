class StammMapMarker {
  const StammMapMarker({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.street = '',
    this.city = '',
    this.postalCode = '',
    this.website = '',
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String street;
  final String city;
  final String postalCode;
  final String website;

  bool get hasDisplayableAddress {
    return street.trim().isNotEmpty ||
        city.trim().isNotEmpty ||
        postalCode.trim().isNotEmpty;
  }

  String get formattedAddress {
    final parts = <String>[];
    if (street.trim().isNotEmpty) {
      parts.add(street.trim());
    }

    final cityLine = [
      postalCode.trim(),
      city.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (cityLine.isNotEmpty) {
      parts.add(cityLine);
    }
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'street': street,
      'city': city,
      'postal_code': postalCode,
      'website': website,
    };
  }

  factory StammMapMarker.fromJson(Map<String, dynamic> json) {
    return StammMapMarker(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      street: json['street']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      postalCode: json['postal_code']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StammMapMarker &&
        other.id == id &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.street == street &&
        other.city == city &&
        other.postalCode == postalCode &&
        other.website == website;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    latitude,
    longitude,
    street,
    city,
    postalCode,
    website,
  );
}

enum StammMapMarkerCategory { district, diocese, federal, standard }

extension StammMapMarkerCategoryX on StammMapMarker {
  StammMapMarkerCategory get category {
    final normalized = name.toLowerCase();

    if (normalized.contains('dpsg bundesverband')) {
      return StammMapMarkerCategory.federal;
    }

    if (normalized.contains('diözesanleitung') ||
        normalized.contains('dioezesanleitung') ||
        normalized.contains('diözesanverband') ||
        normalized.contains('dioezesanverband')) {
      return StammMapMarkerCategory.diocese;
    }

    if (normalized.contains('bezirk')) {
      return StammMapMarkerCategory.district;
    }

    return StammMapMarkerCategory.standard;
  }
}

enum StammMapMarkerSource { asset, cache, remote }

class StammMapMarkerSnapshot {
  const StammMapMarkerSnapshot({
    required this.markers,
    required this.fetchedAt,
    required this.source,
  });

  final List<StammMapMarker> markers;
  final DateTime fetchedAt;
  final StammMapMarkerSource source;

  StammMapMarkerSnapshot copyWith({
    List<StammMapMarker>? markers,
    DateTime? fetchedAt,
    StammMapMarkerSource? source,
  }) {
    return StammMapMarkerSnapshot(
      markers: markers ?? this.markers,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fetched_at': fetchedAt.toIso8601String(),
      'source': source.name,
      'markers': markers.map((marker) => marker.toJson()).toList(),
    };
  }

  factory StammMapMarkerSnapshot.fromJson(Map<String, dynamic> json) {
    final fetchedAtRaw = json['fetched_at']?.toString();
    final fetchedAt = DateTime.tryParse(fetchedAtRaw ?? '');
    if (fetchedAt == null) {
      throw const FormatException('Ungueltiger Zeitstempel fuer Stammmarker.');
    }

    final rawMarkers = json['markers'];
    if (rawMarkers is! List) {
      throw const FormatException('Stammmarker muessen eine Liste sein.');
    }

    final rawSource = json['source']?.toString();
    final source = StammMapMarkerSource.values.where((value) {
      return value.name == rawSource;
    }).firstOrNull;

    return StammMapMarkerSnapshot(
      markers: rawMarkers
          .whereType<Map<String, dynamic>>()
          .map(StammMapMarker.fromJson)
          .toList(growable: false),
      fetchedAt: fetchedAt,
      source: source ?? StammMapMarkerSource.remote,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
