import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/feedback_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late FeedbackPromptService service;
  final start = DateTime(2026, 1, 1, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = start;
    service = FeedbackPromptService(nowProvider: () => now);
  });

  test('erster Aufruf merkt ersten Start und zeigt noch nichts', () async {
    expect(await service.shouldShow(), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(FeedbackPromptService.firstSeenKey),
      start.toIso8601String(),
    );
  });

  test('recordFirstUse ueberschreibt vorhandenen Zeitpunkt nicht', () async {
    await service.recordFirstUse();
    now = start.add(const Duration(days: 3));
    await service.recordFirstUse();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(FeedbackPromptService.firstSeenKey),
      start.toIso8601String(),
    );
  });

  test('erscheint erst nach sieben Tagen', () async {
    await service.recordFirstUse();

    now = start.add(const Duration(days: 6, hours: 23));
    expect(await service.shouldShow(), isFalse);

    now = start.add(const Duration(days: 7));
    expect(await service.shouldShow(), isTrue);
  });

  test('Spaeter verschiebt um vierzehn Tage', () async {
    await service.recordFirstUse();
    now = start.add(const Duration(days: 7));
    await service.markShown();
    await service.markSnoozed();

    now = start.add(const Duration(days: 20));
    expect(await service.shouldShow(), isFalse);

    now = start.add(const Duration(days: 21));
    expect(await service.shouldShow(), isTrue);
  });

  test('nach zwei Anzeigen nie wieder', () async {
    await service.recordFirstUse();
    now = start.add(const Duration(days: 7));
    await service.markShown();
    await service.markSnoozed();
    now = start.add(const Duration(days: 21));
    await service.markShown();
    await service.markSnoozed();

    now = start.add(const Duration(days: 365));
    expect(await service.shouldShow(), isFalse);
  });

  test('nach Feedback oder Bewertung nie wieder', () async {
    await service.recordFirstUse();
    now = start.add(const Duration(days: 7));
    await service.markShown();
    await service.markCompleted();

    now = start.add(const Duration(days: 365));
    expect(await service.shouldShow(), isFalse);
  });
}
