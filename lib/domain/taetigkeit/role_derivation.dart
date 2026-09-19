import 'roles.dart';
import 'stufe.dart';

class RoleClassification {
  const RoleClassification({required this.stufe, required this.category});

  final Stufe stufe;
  final RoleCategory category;
}

extension RoleCategoryDisplayName on RoleCategory {
  String get displayName => switch (this) {
    RoleCategory.mitglied => 'Mitglied',
    RoleCategory.leitung => 'Leitung',
    RoleCategory.sonstiges => 'Sonstiges',
  };
}

extension RoleDerivedAccess on Role {
  RoleClassification get classification => classifyRole(this);

  Stufe get stufe => classification.stufe;

  RoleCategory get art => classification.category;

  DateTime get start =>
      startOn ??
      createdAt ??
      updatedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  DateTime? get ende => endOn;

  String? get permission => resolvedLabel;
}

RoleClassification classifyRole(Role role) {
  final normalized = _normalizeRoleText(role.type, role.name, role.label);
  return RoleClassification(
    stufe: _resolveStufe(normalized),
    category: _resolveCategory(normalized),
  );
}

Role roleFromLegacy({
  int? id,
  DateTime? createdAt,
  DateTime? updatedAt,
  required Stufe stufe,
  required RoleCategory art,
  required DateTime start,
  DateTime? ende,
  String? permission,
  int? personId,
  int? groupId,
}) {
  final label = _legacyRoleLabel(
    stufe: stufe,
    art: art,
    permission: permission,
  );
  return Role(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    startOn: start,
    endOn: ende,
    name: permission?.trim().isNotEmpty == true
        ? permission!.trim()
        : art.displayName,
    personId: personId,
    groupId: groupId,
    type: 'Legacy::${stufe.name}::${art.name}',
    label: label,
  );
}

RoleCategory _resolveCategory(String normalized) {
  for (final keyword in const <String>[
    'leitung',
    'leiter',
    'leader',
    'vorstand',
    'vorsitz',
    'kurat',
    'praeses',
    'stammesfuehrung',
    'bezirksfuehrung',
    'dioezesan',
  ]) {
    if (normalized.contains(keyword)) {
      return RoleCategory.leitung;
    }
  }
  if (normalized.contains('mitglied')) {
    return RoleCategory.mitglied;
  }
  return RoleCategory.sonstiges;
}

Stufe _resolveStufe(String normalized) {
  if (normalized.contains('biber')) {
    return Stufe.biber;
  }
  if (normalized.contains('woelf') || normalized.contains('wolf')) {
    return Stufe.woelfling;
  }
  if (normalized.contains('jungpfad') || normalized.contains('jufi')) {
    return Stufe.jungpfadfinder;
  }
  if (normalized.contains('pfad') || normalized.contains('pfadi')) {
    return Stufe.pfadfinder;
  }
  if (normalized.contains('rover')) {
    return Stufe.rover;
  }
  return Stufe.leitung;
}

String _normalizeRoleText(
  String? first, [
  String? second,
  String? third,
  String? fourth,
]) {
  return [first, second, third, fourth]
      .whereType<String>()
      .map((value) => value.trim().toLowerCase())
      .map(
        (value) => value
            .replaceAll('ä', 'ae')
            .replaceAll('ö', 'oe')
            .replaceAll('ü', 'ue')
            .replaceAll('ß', 'ss'),
      )
      .join(' ');
}

String? _legacyRoleLabel({
  required Stufe stufe,
  required RoleCategory art,
  String? permission,
}) {
  final trimmedPermission = permission?.trim();
  if (trimmedPermission != null && trimmedPermission.isNotEmpty) {
    return trimmedPermission;
  }
  return '${art.displayName} - ${stufe.displayName}';
}
