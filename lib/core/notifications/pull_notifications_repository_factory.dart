import 'package:hive_ce/hive.dart';

import '../../services/logger_service.dart';
import '../../services/network_access_policy.dart';
import 'local_notifications_data_source.dart';
import 'pull_notifications_env.dart';
import 'pull_notifications_repository_impl.dart';
import 'remote_notifications_data_source.dart';

Future<PullNotificationsRepositoryImpl> createPullNotificationsRepository({
  required LoggerService logger,
  NetworkAccessPolicy? networkAccessPolicy,
}) async {
  await Hive.openBox('notifications_box');
  final box = Hive.box('notifications_box');
  final local = LocalNotificationsDataSource(box);
  // TODO(pull_notifications): Fuer Entwicklungszwecke optionalen Asset-Fallback statt Remote-Quelle ergaenzen.
  final remote = RemoteNotificationsDataSource(
    PullNotificationsEnv.url,
    logger: logger,
  );

  return PullNotificationsRepositoryImpl(
    remote: remote,
    local: local,
    minFetchInterval: PullNotificationsEnv.minFetchInterval,
    networkAccessPolicy: networkAccessPolicy,
  );
}
