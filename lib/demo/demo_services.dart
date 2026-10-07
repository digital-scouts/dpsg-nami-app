import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

import '../data/arbeitskontext/hitobito_group_resource.dart';
import '../domain/arbeitskontext/arbeitskontext.dart';
import '../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import '../domain/auth/auth_profile.dart';
import '../domain/auth/auth_session.dart';
import '../domain/auth/auth_session_repository.dart';
import '../domain/bundesstatistik/bundesstatistik_teilnahme.dart';
import '../domain/bundesstatistik/installation_credentials.dart';
import '../domain/member/efz_einsichtnahme.dart';
import '../domain/member/member_write_repository.dart';
import '../domain/member/mitglied.dart';
import '../domain/member_filters/member_filter_repository.dart';
import '../domain/qualifikation/qualifikations_einstellungen.dart';
import '../domain/qualifikation/qualifikations_einstellungen_repository.dart';
import '../services/hitobito_auth_env.dart';
import '../services/hitobito_efz_service.dart';
import '../services/hitobito_groups_service.dart';
import '../services/hitobito_oauth_service.dart';
import '../services/logger_service.dart';
import '../services/sensitive_storage_service.dart';
import 'demo_data.dart';

/// Konfiguration ohne erreichbaren Server: Im Demo-Modus spricht keine
/// Hitobito-Anfrage das Netz an.
const HitobitoAuthConfig demoAuthConfig = HitobitoAuthConfig(
  clientId: 'demo',
  clientSecret: 'demo',
  authorizationUrl: 'https://demo.invalid/oauth/authorize',
  tokenUrl: 'https://demo.invalid/oauth/token',
  redirectUri: 'de.jlange.nami.app:/oauth/callback',
  scopeString: HitobitoAuthConfig.defaultScopeString,
  discoveryUrl: '',
  profileUrl: 'https://demo.invalid/oauth/profile',
);

/// Einziges Telemetrie-Ereignis, das der Demo-Zugang sendet.
const String demoUsedEvent = 'demo_used';

/// Laesst im Demo nur [demoUsedEvent] an [inner] durch. Alle anderen
/// Ereignisse stammen aus Demo-Aktionen und werden nicht gesendet.
WiredashEventHook demoEventHook(WiredashEventHook inner) {
  return (name, properties) async {
    if (name == demoUsedEvent) {
      await inner(name, properties);
    }
  };
}

/// Haelt alle sensiblen Boxen nur im Speicher. Echte Boxen und der
/// Verschluesselungsschluessel im Secure Storage bleiben unberuehrt.
class DemoSensitiveStorageService extends SensitiveStorageService {
  DemoSensitiveStorageService() : super();

  static const String _boxPrefix = 'demo_';
  static final Set<String> _openedBoxNames = <String>{};

  // Die Demo-Boxen liegen nur im Speicher; die Sitzung der echten
  // Installation bleibt unberuehrt.
  @override
  void beginSession() {}

  @override
  void endSession() {}

  @override
  Future<bool> hasLocalSensitiveData() async => true;

  @override
  Future<Box<String>> openEncryptedStringBox(String boxName) async {
    final demoBoxName = '$_boxPrefix$boxName';
    if (Hive.isBoxOpen(demoBoxName)) {
      return Hive.box<String>(demoBoxName);
    }
    _openedBoxNames.add(demoBoxName);
    return Hive.openBox<String>(demoBoxName, bytes: Uint8List(0));
  }

  @override
  Future<void> purgeSensitiveData() async {
    for (final boxName in _openedBoxNames.toList()) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<String>(boxName).close();
      }
    }
    _openedBoxNames.clear();
  }
}

class InMemoryAuthSessionRepository implements AuthSessionRepository {
  AuthSession? _session;

  @override
  Future<AuthSession?> load() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

class DemoOauthService extends HitobitoOauthService {
  DemoOauthService(this.demoData) : super(config: demoAuthConfig);

  final DemoData demoData;

  @override
  Future<AuthSession> authenticateInteractive() async => demoData.session();

  @override
  Future<AuthSession> refresh(AuthSession session) async => session;

  @override
  Future<AuthSession> refreshIfNeeded(
    AuthSession session, {
    Duration threshold = const Duration(minutes: 5),
  }) async => session;

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async =>
      demoData.profile;
}

class DemoHitobitoGroupsService extends HitobitoGroupsService {
  DemoHitobitoGroupsService(this.demoData) : super(config: demoAuthConfig);

  final DemoData demoData;

  @override
  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async => demoData.hitobitoGruppen();
}

/// Liefert den Demo-Layer mit kurzer Verzoegerung, damit der Ladeablauf wie
/// bei einer echten Anmeldung sichtbar wird.
class DemoArbeitskontextReadModelRepository
    implements ArbeitskontextReadModelRepository {
  DemoArbeitskontextReadModelRepository(
    this.demoData, {
    this.ladedauer = const Duration(milliseconds: 1200),
  });

  final DemoData demoData;
  final Duration ladedauer;

  @override
  Future<ArbeitskontextReadModel> loadCached(
    Arbeitskontext arbeitskontext,
  ) async {
    return demoData.readModel(arbeitskontext: arbeitskontext);
  }

  @override
  Future<ArbeitskontextReadModel> refresh({
    required String accessToken,
    required Arbeitskontext arbeitskontext,
    List<HitobitoGroupResource>? accessibleGroups,
    void Function(ArbeitskontextReadModel partial)? onProgress,
  }) async {
    await Future<void>.delayed(ladedauer);
    return demoData.readModel(arbeitskontext: arbeitskontext);
  }

  @override
  Future<ArbeitskontextReadModel> loadRoles({
    required String accessToken,
    required ArbeitskontextReadModel readModel,
  }) async {
    return readModel.copyWith(rolesSindGeladen: true);
  }
}

class DemoHitobitoEfzService extends HitobitoEfzService {
  DemoHitobitoEfzService(this.demoData) : super(config: demoAuthConfig);

  final DemoData demoData;

  @override
  Future<List<EfzEinsichtnahme>> fetchEfzEinsichtnahmenFuerPerson(
    String accessToken, {
    required int personId,
  }) async {
    return demoData
        .efzEinsichtnahmen()
        .where((einsichtnahme) => einsichtnahme.personId == personId)
        .toList(growable: false);
  }

  @override
  Future<List<EfzEinsichtnahme>> fetchAlleEfzEinsichtnahmen(
    String accessToken,
  ) async {
    return demoData.efzEinsichtnahmen();
  }

  @override
  Future<Uint8List> downloadEfzAntrag(
    String accessToken, {
    required int groupId,
    required int personId,
  }) async {
    throw const HitobitoEfzAntragUnavailableException(
      'Im Demo-Modus gibt es keinen EFZ-Antrag.',
    );
  }
}

/// Der Demo-Zugang ist nur lesend. Die Bearbeitung ist in der Oberflaeche
/// bereits gesperrt, das hier ist die zweite Sicherung.
class ReadOnlyMemberWriteRepository implements MemberWriteRepository {
  static const String message =
      'Im Demo-Modus können keine Daten geändert werden.';

  @override
  Future<Mitglied> fetchRemoteMember({
    required String accessToken,
    required int personId,
  }) async {
    throw const MemberWriteRejectedException(message);
  }

  @override
  Future<Mitglied> updateMember({
    required String accessToken,
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
  }) async {
    throw const MemberWriteRejectedException(message);
  }
}

/// Eigene Installation fuer den Mock-Statistikserver, getrennt von den
/// Credentials der echten Installation.
class InMemoryInstallationCredentialsRepository
    implements InstallationCredentialsRepository {
  InMemoryInstallationCredentialsRepository({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;
  InstallationCredentials? _credentials;

  @override
  Future<InstallationCredentials> loadOrCreate() async {
    return _credentials ?? regenerate();
  }

  @override
  Future<InstallationCredentials> regenerate() async {
    final credentials = InstallationCredentials(
      id: _randomToken(16),
      secret: _randomToken(32),
    );
    _credentials = credentials;
    return credentials;
  }

  @override
  Future<void> clear() async {
    _credentials = null;
  }

  String _randomToken(int byteCount) {
    final bytes = List<int>.generate(byteCount, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

/// Im Demo hat das Demo-Profil bereits eingewilligt, damit der Bundesvergleich
/// mit dem Mock-Statistikserver sichtbar ist.
class InMemoryBundesstatistikTeilnahmeRepository
    implements BundesstatistikTeilnahmeRepository {
  InMemoryBundesstatistikTeilnahmeRepository({
    BundesstatistikTeilnahme initial = BundesstatistikTeilnahme.leer,
  }) : _teilnahme = initial;

  BundesstatistikTeilnahme _teilnahme;

  @override
  Future<BundesstatistikTeilnahme> load() async => _teilnahme;

  @override
  Future<void> save(BundesstatistikTeilnahme teilnahme) async {
    _teilnahme = teilnahme;
  }
}

/// Einstellungen der Qualifikationen im Demo-Modus, nur im Speicher.
class InMemoryQualifikationsEinstellungenRepository
    implements QualifikationsEinstellungenRepository {
  QualifikationsEinstellungen _einstellungen =
      const QualifikationsEinstellungen();

  @override
  Future<QualifikationsEinstellungen> load() async => _einstellungen;

  @override
  Future<void> save(QualifikationsEinstellungen einstellungen) async {
    _einstellungen = einstellungen;
  }
}

class InMemoryMemberFilterRepository implements MemberFilterRepository {
  final Map<int, MemberFilterLayerSettings> _values =
      <int, MemberFilterLayerSettings>{};

  @override
  Future<MemberFilterLayerSettings> loadForLayer(int layerId) async {
    return _values[layerId] ?? const MemberFilterLayerSettings();
  }

  @override
  Future<void> saveForLayer(
    int layerId,
    MemberFilterLayerSettings settings,
  ) async {
    _values[layerId] = settings;
  }
}
