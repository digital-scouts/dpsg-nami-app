import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/app_startup_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('merkt Welcome-Status und kann ihn wieder loeschen', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AppStartupStateService();

    expect(await service.hasSeenWelcome(), isFalse);

    await service.markWelcomeSeen();
    expect(await service.hasSeenWelcome(), isTrue);

    await service.clearStartupState();
    expect(await service.hasSeenWelcome(), isFalse);
  });

  test('merkt die Antwort zur Einführung bis zum Zurücksetzen', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AppStartupStateService();

    expect(await service.loadIntroWanted(), isNull);
    await service.saveIntroWanted(true);
    expect(await service.loadIntroWanted(), isTrue);

    await service.clearStartupState();
    expect(await service.loadIntroWanted(), isNull);
  });
}
