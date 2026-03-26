class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.receivedAt,
    this.refreshToken,
    this.idToken,
    this.expiresAt,
    this.scopes = const [],
    this.principal,
    this.email,
    this.displayName,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime receivedAt;
  final DateTime? expiresAt;
  final List<String> scopes;
  final String? principal;
  final String? email;
  final String? displayName;

  bool get canRefresh => refreshToken != null && refreshToken!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'idToken': idToken,
      'receivedAt': receivedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'scopes': scopes,
      'principal': principal,
      'email': email,
      'displayName': displayName,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      idToken: json['idToken'] as String?,
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      scopes: (json['scopes'] as List<dynamic>? ?? const [])
          .map((scope) => scope.toString())
          .toList(),
      principal: json['principal'] as String?,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
    );
  }
}
