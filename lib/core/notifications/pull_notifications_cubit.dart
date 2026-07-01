import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'pull_notification.dart';
import 'pull_notifications_repository.dart';

part 'pull_notifications_state.dart';

class PullNotificationsCubit extends Cubit<PullNotificationsState> {
  final PullNotificationsRepository repository;
  PullNotificationsCubit(this.repository) : super(PullNotificationsInitial());

  Future<void> load({bool force = false}) async {
    emit(PullNotificationsLoading());
    try {
      final notifications = await repository.fetchNotifications(
        forceRefresh: force,
      );
      final ack = await repository.getAcknowledgedIds();
      emit(PullNotificationsLoaded(notifications, ack));
    } catch (e) {
      emit(PullNotificationsError(e.toString()));
    }
  }

  Future<void> acknowledge(String id) async {
    await repository.acknowledgeNotification(id);
    await load();
  }

  Future<void> resetAcknowledged() async {
    await repository.resetAcknowledgedNotifications();
    await load();
  }
}
