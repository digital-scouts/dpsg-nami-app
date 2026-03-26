import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';

void main() {
  test('meldet Refresh nach Ablauf des Intervalls', () {
    final policy = HitobitoDataRetentionPolicy(
      maxDataAge: const Duration(days: 90),
      refreshInterval: const Duration(hours: 24),
      nowProvider: () => DateTime(2026, 3, 26, 12),
    );

    expect(policy.isRefreshDue(DateTime(2026, 3, 25, 11, 59)), isTrue);
    expect(policy.isRefreshDue(DateTime(2026, 3, 25, 12, 30)), isFalse);
  });

  test('erzwingt Relogin nach 90 Tagen', () {
    final policy = HitobitoDataRetentionPolicy(
      maxDataAge: const Duration(days: 90),
      refreshInterval: const Duration(hours: 24),
      nowProvider: () => DateTime(2026, 3, 26, 12),
    );

    expect(policy.isReloginRequired(DateTime(2025, 12, 26, 12)), isTrue);
    expect(policy.isReloginRequired(DateTime(2025, 12, 27, 12)), isFalse);
  });

  test('liefert verbleibende Zeit bis zum Relogin', () {
    final policy = HitobitoDataRetentionPolicy(
      maxDataAge: const Duration(days: 90),
      refreshInterval: const Duration(hours: 24),
      nowProvider: () => DateTime(2026, 3, 26, 12),
    );

    expect(
      policy.remainingUntilRelogin(DateTime(2026, 3, 1, 12)),
      const Duration(days: 65),
    );
  });
}
