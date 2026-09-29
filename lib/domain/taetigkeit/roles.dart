enum RoleCategory { mitglied, leitung, sonstiges }

class Role {
  Role({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.startOn,
    this.endOn,
    String? name,
    this.personId,
    this.groupId,
    String? type,
    String? label,
  }) : name = _trimToNull(name),
       type = _trimToNull(type),
       label = _trimToNull(label);

  final int? id;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? startOn;
  final DateTime? endOn;
  final String? name;
  final int? personId;
  final int? groupId;
  final String? type;
  final String? label;

  DateTime get effectiveStart =>
      startOn ??
      createdAt ??
      updatedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  bool isActiveAt(DateTime referenceDate) {
    if (effectiveStart.isAfter(referenceDate)) {
      return false;
    }
    return endOn == null || endOn!.isAfter(referenceDate);
  }

  bool get istAktiv => isActiveAt(DateTime.now());

  String? get resolvedLabel {
    final trimmedLabel = label?.trim();
    if (trimmedLabel != null && trimmedLabel.isNotEmpty) {
      return trimmedLabel;
    }

    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }

    final trimmedType = type?.trim();
    if (trimmedType == null || trimmedType.isEmpty) {
      return null;
    }

    final segments = trimmedType
        .split('::')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return null;
    }

    return segments.last;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'start_on': startOn?.toIso8601String(),
      'end_on': endOn?.toIso8601String(),
      'name': name,
      'person_id': personId,
      'group_id': groupId,
      'type': type,
      'label': label,
    };
  }

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: _tryParseInt(json['id']),
      createdAt: _tryParseDateTime(json['created_at']),
      updatedAt: _tryParseDateTime(json['updated_at']),
      startOn:
          _tryParseDateTime(json['start_on']) ??
          _tryParseDateTime(json['start']),
      endOn:
          _tryParseDateTime(json['end_on']) ?? _tryParseDateTime(json['ende']),
      name: _trimToNull(json['name']?.toString()),
      personId: _tryParseInt(json['person_id']),
      groupId: _tryParseInt(json['group_id']),
      type: _trimToNull(json['type']?.toString()),
      label: _trimToNull(json['label']?.toString()),
    );
  }

  Role copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startOn,
    DateTime? endOn,
    String? name,
    int? personId,
    int? groupId,
    String? type,
    String? label,
  }) => Role(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    startOn: startOn ?? this.startOn,
    endOn: endOn ?? this.endOn,
    name: name ?? this.name,
    personId: personId ?? this.personId,
    groupId: groupId ?? this.groupId,
    type: type ?? this.type,
    label: label ?? this.label,
  );

  @override
  bool operator ==(Object other) {
    return other is Role &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.startOn == startOn &&
        other.endOn == endOn &&
        other.name == name &&
        other.personId == personId &&
        other.groupId == groupId &&
        other.type == type &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    startOn,
    endOn,
    name,
    personId,
    groupId,
    type,
    label,
  );

  @override
  String toString() =>
      'Role(id: $id, type: $type, label: $label, name: $name, startOn: $startOn, endOn: $endOn, personId: $personId, groupId: $groupId)';
}

DateTime? _tryParseDateTime(Object? value) {
  final raw = _trimToNull(value?.toString());
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw);
}

int? _tryParseInt(Object? value) {
  final raw = _trimToNull(value?.toString());
  if (raw == null) {
    return null;
  }
  return int.tryParse(raw);
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
