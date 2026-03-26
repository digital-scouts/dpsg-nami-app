import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/core/notifications/pull_notification.dart';

import '../../core/notifications/local_notifications_data_source.dart';
import '../../core/notifications/pull_notifications_cubit.dart';
import '../../core/notifications/pull_notifications_env.dart';
import '../../core/notifications/pull_notifications_repository_impl.dart';
import '../../core/notifications/remote_notifications_data_source.dart';
import '../../services/logger_service.dart';
import 'notifications_list.dart';
import 'urgent_notification_modal.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  PullNotificationsCubit? cubit;
  bool _urgentShown = false;
  bool _boxReady = false;

  @override
  void initState() {
    super.initState();
    _initHiveAndCubit();
  }

  Future<void> _initHiveAndCubit() async {
    await Hive.openBox('notifications_box');
    final logger = context.read<LoggerService>();
    final remote = RemoteNotificationsDataSource(
      PullNotificationsEnv.url,
      logger: logger,
    );
    final box = Hive.box('notifications_box');
    final local = LocalNotificationsDataSource(box);
    final repo = PullNotificationsRepositoryImpl(remote: remote, local: local);
    final c = PullNotificationsCubit(repo);
    if (!mounted) {
      await c.close();
      return;
    }
    setState(() {
      cubit = c;
      _boxReady = true;
    });
    // Sofort Cache anzeigen, dann im Hintergrund laden
    c.load();
  }

  @override
  void dispose() {
    cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_boxReady || cubit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mitteilungen')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return BlocProvider.value(
      value: cubit!,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mitteilungen')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => cubit!.load(force: true),
                      icon: const Icon(Icons.sync),
                      label: const Text('Aktualisieren'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await cubit!.resetAcknowledged();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mitteilungsstatus zurückgesetzt'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Gelesen zurücksetzen'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  BlocConsumer<PullNotificationsCubit, PullNotificationsState>(
                    listener: (context, state) {
                      if (state is PullNotificationsLoaded && !_urgentShown) {
                        PullNotification? urgent;
                        try {
                          urgent = state.notifications.firstWhere(
                            (n) =>
                                n.type == 'urgent' &&
                                !state.acknowledged.contains(n.id),
                          );
                        } catch (e) {
                          urgent = null;
                        }
                        if (urgent == null) return;
                        _urgentShown = true;
                        showUrgentNotificationModal(context, urgent);
                      }
                    },
                    builder: (context, state) {
                      if (state is PullNotificationsLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is PullNotificationsLoaded) {
                        return NotificationsList(
                          notifications: state.notifications,
                          acknowledged: state.acknowledged,
                          onTap: (n) {},
                          onAcknowledge: (n) => cubit!.acknowledge(n.id),
                        );
                      }
                      if (state is PullNotificationsError) {
                        return Center(child: Text('Fehler: ${state.message}'));
                      }
                      // Default: Zeige leere Liste
                      return NotificationsList(
                        notifications: const [],
                        acknowledged: const {},
                        onTap: (_) {},
                        onAcknowledge: (_) {},
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
