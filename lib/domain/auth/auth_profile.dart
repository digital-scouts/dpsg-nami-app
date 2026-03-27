class AuthProfileRole {
  const AuthProfileRole({
    required this.groupId,
    required this.groupName,
    required this.roleName,
    required this.roleClass,
    this.permissions = const <String>[],
  });

  final int groupId;
  final String groupName;
  final String roleName;
  final String roleClass;
  final List<String> permissions;

  factory AuthProfileRole.fromJson(Map<String, dynamic> json) {
    return AuthProfileRole(
      groupId: _toInt(json['group_id']),
      groupName: json['group_name']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? '',
      roleClass: json['role_class']?.toString() ?? '',
      permissions: (json['permissions'] as List<dynamic>? ?? const <dynamic>[])
          .map((permission) => permission.toString())
          .toList(growable: false),
    );
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AuthProfile {
  const AuthProfile({
    required this.namiId,
    this.email,
    this.firstName,
    this.lastName,
    this.nickname,
    this.language,
    this.roles = const <AuthProfileRole>[],
  });

  final int namiId;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? nickname;
  final String? language;
  final List<AuthProfileRole> roles;

  String? get trimmedNickname {
    final value = nickname?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String get fullName {
    return <String>[
      firstName?.trim() ?? '',
      lastName?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ').trim();
  }

  String get primaryDisplayName {
    final nicknameValue = trimmedNickname;
    if (nicknameValue != null) {
      return nicknameValue;
    }

    final fullNameValue = fullName;
    if (fullNameValue.isNotEmpty) {
      return fullNameValue;
    }

    return email?.trim().isNotEmpty == true ? email!.trim() : 'Unbekannt';
  }

  String? get secondaryDisplayName {
    if (trimmedNickname == null) {
      return null;
    }

    final fullNameValue = fullName;
    if (fullNameValue.isEmpty) {
      return null;
    }

    return fullNameValue;
  }

  String get normalizedLanguage => normalizeLanguageCode(language);

  factory AuthProfile.fromJson(Map<String, dynamic> json) {
    return AuthProfile(
      namiId: _toInt(json['id']),
      email: json['email']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      nickname: json['nickname']?.toString(),
      language: json['language']?.toString(),
      roles: (json['roles'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AuthProfileRole.fromJson)
          .toList(growable: false),
    );
  }

  static String normalizeLanguageCode(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'en') {
      return 'en';
    }
    return 'de';
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
