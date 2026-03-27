import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_people_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/model/member_people_model.dart';
import 'package:nami/services/logger_service.dart';

void main() {
  test(
    'zeigt zuerst Cache und ueberschreibt danach mit Remote-Daten',
    () async {
      final repository = _FakeMemberPeopleRepository(
        cached: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1',
            vorname: 'Cache',
            nachname: 'Name',
          ),
        ],
        refreshed: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '2',
            vorname: 'Remote',
            nachname: 'Name',
          ),
        ],
        refreshDelay: const Duration(milliseconds: 10),
      );
      final model = MemberPeopleModel(
        repository: repository,
        logger: _FakeLoggerService(),
      );

      final future = model.load(accessToken: 'token-123');
      await Future<void>.delayed(Duration.zero);

      expect(model.members.single.fullName, 'Cache Name');

      await future;

      expect(model.members.single.fullName, 'Remote Name');
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );
}

class _FakeMemberPeopleRepository implements MemberPeopleRepository {
  _FakeMemberPeopleRepository({
    required this.cached,
    required this.refreshed,
    this.refreshDelay = Duration.zero,
  });

  final List<Mitglied> cached;
  final List<Mitglied> refreshed;
  final Duration refreshDelay;

  @override
  Future<List<Mitglied>> loadCached() async => cached;

  @override
  Future<List<Mitglied>> refresh(String accessToken) async {
    if (refreshDelay > Duration.zero) {
      await Future<void>.delayed(refreshDelay);
    }
    return refreshed;
  }
}

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  @override
  Future<void> log(String service, String message) async {}
}

class _FakeAppSettingsRepository implements AppSettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings(
    themeMode: ThemeMode.system,
    languageCode: 'de',
    analyticsEnabled: false,
  );

  @override
  Future<void> saveAnalyticsEnabled(bool enabled) async {}

  @override
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
