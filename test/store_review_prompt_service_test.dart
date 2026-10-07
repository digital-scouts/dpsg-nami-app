import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/store_review_client.dart';
import 'package:nami/services/store_review_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeStoreReviewClient client;
  late int delayCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _FakeStoreReviewClient();
    delayCalls = 0;
  });

  StoreReviewPromptService buildService({
    TargetPlatform platform = TargetPlatform.iOS,
    bool isDemo = false,
    Future<void> Function()? delay,
  }) => StoreReviewPromptService(
    client: client,
    platformProvider: () => platform,
    isDemo: isDemo,
    delay:
        delay ??
        () async {
          delayCalls++;
        },
  );

  Future<bool?> requestedFlag() async => (await SharedPreferences.getInstance())
      .getBool(StoreReviewPromptService.requestedKey);

  test(
    'fragt auf iOS nach dem Speichern einmal an und merkt es sich',
    () async {
      final service = buildService();

      expect(await service.requestAfterMemberSaved(), isTrue);

      expect(client.requestReviewCalls, 1);
      expect(delayCalls, 1);
      expect(await requestedFlag(), isTrue);
    },
  );

  test('fragt hoechstens einmal an, auch ueber App-Starts hinweg', () async {
    expect(await buildService().requestAfterMemberSaved(), isTrue);

    expect(await buildService().requestAfterMemberSaved(), isFalse);
    expect(client.requestReviewCalls, 1);
  });

  test(
    'Schluessel liegt unter feedback_prompt und faellt beim Reset weg',
    () async {
      expect(
        StoreReviewPromptService.requestedKey,
        startsWith('feedback_prompt.'),
      );
      await buildService().requestAfterMemberSaved();

      // AppResetService leert alle SharedPreferences.
      await (await SharedPreferences.getInstance()).clear();

      expect(await buildService().requestAfterMemberSaved(), isTrue);
      expect(client.requestReviewCalls, 2);
    },
  );

  test('fragt auf Android nie an', () async {
    final service = buildService(platform: TargetPlatform.android);

    expect(await service.requestAfterMemberSaved(), isFalse);

    expect(client.requestReviewCalls, 0);
    expect(delayCalls, 0);
    expect(await requestedFlag(), isNull);
  });

  test('fragt im Demo-Modus nie an', () async {
    final service = buildService(isDemo: true);

    expect(await service.requestAfterMemberSaved(), isFalse);

    expect(client.requestReviewCalls, 0);
    expect(await requestedFlag(), isNull);
  });

  test('nicht im selben App-Start wie der Feedback-Dialog', () async {
    final service = buildService()..markFeedbackPromptShown();

    expect(await service.requestAfterMemberSaved(), isFalse);
    expect(client.requestReviewCalls, 0);
    expect(await requestedFlag(), isNull);

    // Im naechsten App-Start ist die Anfrage wieder moeglich.
    expect(await buildService().requestAfterMemberSaved(), isTrue);
  });

  test(
    'Feedback-Dialog waehrend der Wartezeit verhindert die Anfrage',
    () async {
      late StoreReviewPromptService service;
      service = buildService(
        delay: () async => service.markFeedbackPromptShown(),
      );

      expect(await service.requestAfterMemberSaved(), isFalse);
      expect(client.requestReviewCalls, 0);
    },
  );

  test('ohne verfuegbaren Systemdialog bleibt die Anfrage offen', () async {
    client.available = false;
    final service = buildService();

    expect(await service.requestAfterMemberSaved(), isFalse);
    expect(await requestedFlag(), isNull);

    client.available = true;
    expect(await service.requestAfterMemberSaved(), isTrue);
    expect(client.requestReviewCalls, 1);
  });

  test('kurz nacheinander gespeichert fragt nur einmal an', () async {
    final gate = Completer<void>();
    final service = buildService(delay: () => gate.future);

    final first = service.requestAfterMemberSaved();
    final second = service.requestAfterMemberSaved();
    gate.complete();

    expect(await Future.wait([first, second]), unorderedEquals([true, false]));
    expect(client.requestReviewCalls, 1);
  });

  test('Fehler beim Anfragen fuehrt nicht zu Wiederholungen', () async {
    client.failRequest = true;
    final service = buildService();

    expect(await service.requestAfterMemberSaved(), isFalse);
    expect(await requestedFlag(), isTrue);

    client.failRequest = false;
    expect(await buildService().requestAfterMemberSaved(), isFalse);
  });
}

class _FakeStoreReviewClient implements StoreReviewClient {
  bool available = true;
  bool failRequest = false;
  int requestReviewCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    if (failRequest) {
      throw StateError('kein Systemdialog');
    }
    requestReviewCalls++;
  }

  @override
  Future<void> openStoreListing() async {}
}
