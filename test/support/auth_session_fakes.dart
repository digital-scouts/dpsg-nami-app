import 'dart:async';

import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_profile_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';

import 'hitobito_jsonapi_fixtures.dart';

class InMemoryAuthProfileRepository implements AuthProfileRepository {
  InMemoryAuthProfileRepository({this.profile, this.lastSyncAt});

  AuthProfile? profile;
  DateTime? lastSyncAt;

  @override
  Future<void> clear() async {
    profile = null;
    lastSyncAt = null;
  }

  @override
  Future<AuthProfile?> loadCached() async => profile;

  @override
  Future<DateTime?> loadLastSyncAt() async => lastSyncAt;

  @override
  Future<void> save(AuthProfile profile) async {
    this.profile = profile;
  }

  @override
  Future<void> saveLastSyncAt(DateTime timestamp) async {
    lastSyncAt = timestamp;
  }
}

class InMemoryAuthSessionRepository implements AuthSessionRepository {
  InMemoryAuthSessionRepository({AuthSession? initialSession})
    : _session = initialSession;

  AuthSession? _session;
  Object? loadError;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<AuthSession?> load() async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return _session;
  }

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }
}

/// OAuth-Dienst ohne Netz. Zaehlt interaktive Logins und Refreshes;
/// `refreshIfNeeded` laesst die Session unveraendert, damit keine echte Uhr
/// ueber den Ablauf entscheidet.
class FakeOauthService extends HitobitoOauthService {
  FakeOauthService({
    required this.sessionToReturn,
    required this.profileToReturn,
  }) : super(config: testHitobitoAuthConfig);

  final AuthSession sessionToReturn;
  final AuthProfile profileToReturn;
  Object? authenticateError;
  Object? refreshError;
  Object? fetchProfileError;

  /// Ob `refreshIfNeeded` wie bei abgelaufenem Access-Token erneuert.
  bool refreshIfNeededErneuert = false;

  /// Haelt Refresh bzw. Browser-Login an, bis der Test sie freigibt.
  Completer<void>? refreshSperre;
  Completer<void>? anmeldungSperre;
  int authenticateInteractiveCallCount = 0;
  int refreshCallCount = 0;
  int fetchProfileCallCount = 0;
  final List<AuthSession> widerrufeneSessions = <AuthSession>[];
  Completer<bool>? revokeAntwort;

  @override
  Future<AuthSession> authenticateInteractive() async {
    authenticateInteractiveCallCount += 1;
    await anmeldungSperre?.future;
    final error = authenticateError;
    if (error != null) {
      throw error;
    }
    return sessionToReturn;
  }

  @override
  Future<AuthSession> refresh(AuthSession session) async {
    refreshCallCount += 1;
    await refreshSperre?.future;
    final error = refreshError;
    if (error != null) {
      throw error;
    }
    return sessionToReturn;
  }

  @override
  Future<bool> revoke(AuthSession session) {
    widerrufeneSessions.add(session);
    return revokeAntwort?.future ?? Future.value(true);
  }

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async {
    fetchProfileCallCount += 1;
    final error = fetchProfileError;
    if (error != null) {
      throw error;
    }
    return profileToReturn;
  }

  @override
  Future<AuthSession> refreshIfNeeded(
    AuthSession session, {
    Duration threshold = const Duration(minutes: 5),
  }) async {
    return refreshIfNeededErneuert ? refresh(session) : session;
  }
}

class FakeBiometricLockService extends BiometricLockService {
  FakeBiometricLockService({this.available = false}) : super();

  final bool available;
  int authenticateCallCount = 0;

  @override
  Future<bool> authenticate() async {
    authenticateCallCount += 1;
    return true;
  }

  @override
  Future<bool> isAvailable() async => available;
}

class FakeSensitiveStorageService extends SensitiveStorageService {
  FakeSensitiveStorageService() : super();

  String? principal;
  DateTime? lastSensitiveSyncAt;
  DateTime? lastSensitiveSyncAttemptAt;
  DateTime? lastBackgroundedAt;

  /// Ob App-Daten einer frueheren Sitzung vorliegen. `false` bildet eine
  /// Neuinstallation nach, bei der nur der Schluesselbund uebrig ist.
  bool hasLocalData = true;

  @override
  Future<bool> hasLocalSensitiveData() async => hasLocalData;

  @override
  Future<String?> loadPrincipal() async => principal;

  @override
  Future<DateTime?> loadLastSensitiveSyncAt() async => lastSensitiveSyncAt;

  @override
  Future<DateTime?> loadLastSensitiveSyncAttemptAt() async =>
      lastSensitiveSyncAttemptAt;

  @override
  Future<DateTime?> loadLastBackgroundedAt() async => lastBackgroundedAt;

  @override
  Future<void> purgeSensitiveData() async {
    principal = null;
    lastSensitiveSyncAt = null;
    lastSensitiveSyncAttemptAt = null;
    lastBackgroundedAt = null;
  }

  @override
  Future<void> saveLastSensitiveSyncAt(DateTime timestamp) async {
    lastSensitiveSyncAt = timestamp;
  }

  @override
  Future<void> saveLastSensitiveSyncAttemptAt(DateTime? timestamp) async {
    lastSensitiveSyncAttemptAt = timestamp;
  }

  @override
  Future<void> saveLastBackgroundedAt(DateTime? timestamp) async {
    lastBackgroundedAt = timestamp;
  }

  @override
  Future<void> savePrincipal(String? principal) async {
    this.principal = principal;
  }
}
