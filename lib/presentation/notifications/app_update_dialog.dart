import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/app_update_service.dart';

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateInfo info,
) async {
  final t = AppLocalizations.of(context);

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(
          info.isRequired
              ? t.t('update_required_title')
              : t.t('update_available_title'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.isRequired
                  ? t.t('update_required_body')
                  : t.t('update_available_body'),
            ),
            const SizedBox(height: 12),
            Text('${t.t('update_current_version')}: ${info.currentVersion}'),
            Text('${t.t('update_latest_version')}: ${info.latestVersion}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.t('ignore')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.tryParse(info.storeUrl);
              if (uri == null) {
                return;
              }
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Text(t.t('open_store')),
          ),
        ],
      );
    },
  );
}
