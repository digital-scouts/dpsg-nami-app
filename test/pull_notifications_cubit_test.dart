import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/core/notifications/pull_notifications_cubit.dart';
import 'package:nami/core/notifications/pull_notifications_repository.dart';

class _FakePullNotificationsRepository implements PullNotificationsRepository {
  List<PullNotification> notifications = const [];
  Set<String> acknowledged = const {};
  Object? fetchError;
  bool? lastForceRefresh;
  String? acknowledgedId;
  bool resetCalled = false;

  @override
  Future<void> acknowledgeNotification(String id) async {
    acknowledgedId = id;
  }

  @override
  Future<List<PullNotification>> fetchNotifications({
    bool forceRefresh = false,
  }) async {
    lastForceRefresh = forceRefresh;
    if (fetchError != null) {
      throw fetchError!;
    }
    return notifications;
  }

  @override
  Future<Set<String>> getAcknowledgedIds() async => acknowledged;

  @override
  Future<void> resetAcknowledgedNotifications() async {
    resetCalled = true;
  }
}

void main() {
  PullNotification buildNotification(String id) {
    return PullNotification(
      id: id,
      title: const LocalizedString(de: 'Titel', en: 'Title'),
      body: const LocalizedString(de: 'Text', en: 'Body'),
    );
  }

  test('emitiert loading und loaded beim erfolgreichen Laden', () async {
    final repo = _FakePullNotificationsRepository()
      ..notifications = [buildNotification('1')]
      ..acknowledged = {'1'};
    final cubit = PullNotificationsCubit(repo);

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<PullNotificationsLoading>(),
        predicate<PullNotificationsState>((state) {
          return state is PullNotificationsLoaded &&
              state.notifications.length == 1 &&
              state.acknowledged.contains('1');
        }),
      ]),
    );

    await cubit.load(force: true);
    await expectation;
    expect(repo.lastForceRefresh, isTrue);
    await cubit.close();
  });

  test('emitiert error wenn das Laden fehlschlaegt', () async {
    final repo = _FakePullNotificationsRepository()
      ..fetchError = Exception('kaputt');
    final cubit = PullNotificationsCubit(repo);

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<PullNotificationsLoading>(),
        predicate<PullNotificationsState>((state) {
          return state is PullNotificationsError &&
              state.message.contains('kaputt');
        }),
      ]),
    );

    await cubit.load();
    await expectation;
    await cubit.close();
  });

  test('acknowledge markiert und laedt neu', () async {
    final repo = _FakePullNotificationsRepository()
      ..notifications = [buildNotification('7')];
    final cubit = PullNotificationsCubit(repo);

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<PullNotificationsLoading>(),
        isA<PullNotificationsLoaded>(),
      ]),
    );

    await cubit.acknowledge('7');
    await expectation;
    expect(repo.acknowledgedId, '7');
    await cubit.close();
  });

  test('resetAcknowledged setzt zurueck und laedt neu', () async {
    final repo = _FakePullNotificationsRepository()
      ..notifications = [buildNotification('9')];
    final cubit = PullNotificationsCubit(repo);

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<PullNotificationsLoading>(),
        isA<PullNotificationsLoaded>(),
      ]),
    );

    await cubit.resetAcknowledged();
    await expectation;
    expect(repo.resetCalled, isTrue);
    await cubit.close();
  });
}
