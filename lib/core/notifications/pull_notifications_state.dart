part of 'pull_notifications_cubit.dart';

@immutable
abstract class PullNotificationsState {}

class PullNotificationsInitial extends PullNotificationsState {}

class PullNotificationsLoading extends PullNotificationsState {}

class PullNotificationsError extends PullNotificationsState {
  final String message;
  PullNotificationsError(this.message);
}

class PullNotificationsLoaded extends PullNotificationsState {
  final List<PullNotification> notifications;
  final Set<String> acknowledged;
  PullNotificationsLoaded(this.notifications, this.acknowledged);
}
