import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nami/core/notifications/pull_notifications_repository_factory.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';

import '../../core/notifications/pull_notifications_cubit.dart';
import '../../services/logger_service.dart';
import '../../services/network_access_policy.dart';
import 'notifications_list.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  PullNotificationsCubit? cubit;
  bool _boxReady = false;

  @override
  void initState() {
    super.initState();
    _initHiveAndCubit();
  }

  Future<void> _initHiveAndCubit() async {
    final logger = context.read<LoggerService>();
    final repo = await createPullNotificationsRepository(
      logger: logger,
      networkAccessPolicy: _resolveNetworkAccessPolicy(),
    );
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

  NetworkAccessPolicy? _resolveNetworkAccessPolicy() {
    try {
      return context.read<NetworkAccessPolicy>();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (!_boxReady || cubit == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.t('pull_notifications_title'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return BlocProvider.value(
      value: cubit!,
      child: Scaffold(
        appBar: AppBar(title: Text(t.t('pull_notifications_title'))),
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
                      label: Text(t.t('notifications_refresh')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await cubit!.resetAcknowledged();
                        if (!context.mounted) return;
                        AppSnackbar.show(
                          context,
                          message: t.t('notifications_reset_done'),
                          type: AppSnackbarType.success,
                        );
                      },
                      icon: const Icon(Icons.restart_alt),
                      label: Text(t.t('notifications_reset_read')),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<PullNotificationsCubit, PullNotificationsState>(
                builder: (context, state) {
                  if (state is PullNotificationsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is PullNotificationsLoaded) {
                    return NotificationsList(
                      notifications: state.notifications,
                      acknowledged: state.acknowledged,
                      onTap: (n) {
                        // TODO(pull_notifications): Detailansicht sowie `deep_link`/`external_link` oeffnen.
                      },
                      onAcknowledge: (n) => cubit!.acknowledge(n.id),
                    );
                  }
                  if (state is PullNotificationsError) {
                    return Center(
                      child: Text(
                        t.t('notifications_error', {'message': state.message}),
                      ),
                    );
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
