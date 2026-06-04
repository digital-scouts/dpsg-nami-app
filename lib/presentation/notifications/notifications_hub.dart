import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:nami/services/network_access_policy.dart';

enum AppNotificationSource { internal, external }

enum AppNotificationSeverity { info, warn, urgent }

@immutable
class AppHubNotification {
  const AppHubNotification({
    required this.id,
    required this.source,
    required this.severity,
    required this.title,
    required this.body,
    this.createdAt,
    this.updatedAt,
    this.externalLink,
    this.deepLink,
    this.ackable = false,
    this.acknowledged = false,
  });

  final String id;
  final AppNotificationSource source;
  final AppNotificationSeverity severity;
  final LocalizedString title;
  final LocalizedString body;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? externalLink;
  final String? deepLink;
  final bool ackable;
  final bool acknowledged;
}

class NotificationsHub {
  const NotificationsHub._();

  static List<AppHubNotification> buildInternal({
    required AuthSessionModel authModel,
    required int unresolvedCount,
    required AppUpdateInfo? updateInfo,
  }) {
    final messages = <AppHubNotification>[];

    if (authModel.hasRemoteAccessIssue) {
      messages.add(_buildHitobitoIssueNotification(authModel));

      final remaining = authModel.remainingUntilRelogin;
      if (remaining != null &&
          remaining > Duration.zero &&
          remaining <= const Duration(days: 3)) {
        messages.add(_buildDataExpirySoonNotification(remaining));
      }
    }

    if (unresolvedCount > 0) {
      messages.add(_buildMemberResolutionNotification(unresolvedCount));
    }

    if (updateInfo != null) {
      messages.add(_buildUpdateNotification(updateInfo));
    }

    return messages;
  }

  static List<AppHubNotification> mapUnreadExternal({
    required List<PullNotification> notifications,
    required Set<String> acknowledged,
  }) {
    return mapVisibleExternal(
      notifications: notifications,
      acknowledged: acknowledged,
    );
  }

  static List<AppHubNotification> mapVisibleExternal({
    required List<PullNotification> notifications,
    required Set<String> acknowledged,
    bool includeAcknowledged = false,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final currentPlatform = _currentPlatform();

    return notifications
        .where(
          (notification) =>
              _isVisibleForPlatform(notification.platform, currentPlatform) &&
              !_isNotStarted(notification, currentTime) &&
              !_isExpired(notification, currentTime),
        )
        .where((notification) {
          final isAcknowledged = acknowledged.contains(notification.id);
          if (includeAcknowledged) {
            return true;
          }

          // Ack should hide only notifications without expiry date.
          if (notification.endsAt == null) {
            return !isAcknowledged;
          }
          return true;
        })
        .map((notification) {
          final isAcknowledged = acknowledged.contains(notification.id);
          return AppHubNotification(
            id: notification.id,
            source: AppNotificationSource.external,
            severity: _severityFromType(notification.type),
            title: notification.title,
            body: notification.body,
            createdAt: notification.createdAt,
            updatedAt: notification.updatedAt,
            externalLink: notification.externalLink,
            deepLink: notification.deepLink,
            ackable: true,
            acknowledged: isAcknowledged,
          );
        })
        .toList(growable: false);
  }

  static List<AppHubNotification> mergeSorted({
    required List<AppHubNotification> internal,
    required List<AppHubNotification> external,
  }) {
    final merged = <AppHubNotification>[...internal, ...external]
      ..sort((left, right) {
        final severityCompare = severityRank(
          left.severity,
        ).compareTo(severityRank(right.severity));
        if (severityCompare != 0) {
          return severityCompare;
        }

        final leftDate = left.updatedAt ?? left.createdAt;
        final rightDate = right.updatedAt ?? right.createdAt;
        if (leftDate == null && rightDate == null) {
          return left.id.compareTo(right.id);
        }
        if (leftDate == null) {
          return 1;
        }
        if (rightDate == null) {
          return -1;
        }
        return rightDate.compareTo(leftDate);
      });
    return merged;
  }

  static int severityRank(AppNotificationSeverity severity) {
    switch (severity) {
      case AppNotificationSeverity.urgent:
        return 0;
      case AppNotificationSeverity.warn:
        return 1;
      case AppNotificationSeverity.info:
        return 2;
    }
  }

  static AppNotificationSeverity _severityFromType(String? type) {
    switch (type) {
      case 'urgent':
        return AppNotificationSeverity.urgent;
      case 'warn':
        return AppNotificationSeverity.warn;
      case 'info':
      default:
        return AppNotificationSeverity.info;
    }
  }

  static bool _isNotStarted(PullNotification notification, DateTime now) {
    final startsAt = notification.startsAt;
    return startsAt != null && startsAt.isAfter(now);
  }

  static bool _isExpired(PullNotification notification, DateTime now) {
    final endsAt = notification.endsAt;
    return endsAt != null && !endsAt.isAfter(now);
  }

  static String _currentPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'all';
    }
  }

  static bool _isVisibleForPlatform(String platform, String currentPlatform) {
    final normalized = platform.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'all') {
      return true;
    }
    return normalized == currentPlatform;
  }

  static AppHubNotification _buildUpdateNotification(AppUpdateInfo info) {
    final de = AppLocalizations(const Locale('de'));
    final en = AppLocalizations(const Locale('en'));
    final bodyDe = info.isRequired
        ? '${de.t('update_required_body')}\n${de.t('settings_version_details', {'versionLabel': de.t('version'), 'currentVersion': info.currentVersion, 'latestVersion': info.latestVersion})}'
        : '${de.t('update_available_body')}\n${de.t('settings_version_details', {'versionLabel': de.t('version'), 'currentVersion': info.currentVersion, 'latestVersion': info.latestVersion})}';
    final bodyEn = info.isRequired
        ? '${en.t('update_required_body')}\n${en.t('settings_version_details', {'versionLabel': en.t('version'), 'currentVersion': info.currentVersion, 'latestVersion': info.latestVersion})}'
        : '${en.t('update_available_body')}\n${en.t('settings_version_details', {'versionLabel': en.t('version'), 'currentVersion': info.currentVersion, 'latestVersion': info.latestVersion})}';

    return AppHubNotification(
      id: 'app-update-${info.latestVersion}-${info.currentVersion}',
      source: AppNotificationSource.internal,
      severity: info.isRequired
          ? AppNotificationSeverity.urgent
          : AppNotificationSeverity.warn,
      title: LocalizedString(
        de: info.isRequired
            ? de.t('update_required_title')
            : de.t('update_available_title'),
        en: info.isRequired
            ? en.t('update_required_title')
            : en.t('update_available_title'),
      ),
      body: LocalizedString(de: bodyDe, en: bodyEn),
      externalLink: info.storeUrl,
      ackable: false,
    );
  }

  static AppHubNotification _buildHitobitoIssueNotification(
    AuthSessionModel authModel,
  ) {
    final de = AppLocalizations(const Locale('de'));
    final en = AppLocalizations(const Locale('en'));
    String bodyKey;
    if (authModel.requiresInteractiveLogin) {
      bodyKey = 'settings_hitobito_issue_relogin_body';
    } else if (authModel.remoteAccessBlockedReason ==
        NetworkAccessBlockedReason.offline) {
      bodyKey = 'settings_hitobito_issue_offline_body';
    } else {
      bodyKey = 'settings_hitobito_issue_body';
    }

    return AppHubNotification(
      id: 'hitobito-issue',
      source: AppNotificationSource.internal,
      severity: authModel.requiresInteractiveLogin
          ? AppNotificationSeverity.urgent
          : AppNotificationSeverity.warn,
      title: LocalizedString(
        de: de.t('settings_hitobito_issue_title'),
        en: en.t('settings_hitobito_issue_title'),
      ),
      body: LocalizedString(de: de.t(bodyKey), en: en.t(bodyKey)),
      ackable: false,
    );
  }

  static AppHubNotification _buildMemberResolutionNotification(int count) {
    final de = AppLocalizations(const Locale('de'));
    final en = AppLocalizations(const Locale('en'));
    return AppHubNotification(
      id: 'member-resolution-$count',
      source: AppNotificationSource.internal,
      severity: AppNotificationSeverity.warn,
      title: LocalizedString(
        de: de.t('settings_member_resolution_title'),
        en: en.t('settings_member_resolution_title'),
      ),
      body: LocalizedString(
        de: de.t('settings_member_resolution_body', {'count': count}),
        en: en.t('settings_member_resolution_body', {'count': count}),
      ),
      ackable: false,
    );
  }

  static AppHubNotification _buildDataExpirySoonNotification(
    Duration remaining,
  ) {
    final de = AppLocalizations(const Locale('de'));
    final en = AppLocalizations(const Locale('en'));
    final daysRemaining = remaining.inHours <= 24
        ? 1
        : (remaining.inHours / 24).ceil();

    return AppHubNotification(
      id: 'data-expiry-soon',
      source: AppNotificationSource.internal,
      severity: AppNotificationSeverity.urgent,
      title: LocalizedString(
        de: de.t('settings_data_expiry_soon_title'),
        en: en.t('settings_data_expiry_soon_title'),
      ),
      body: LocalizedString(
        de: de.t('settings_data_expiry_soon_body', {'days': daysRemaining}),
        en: en.t('settings_data_expiry_soon_body', {'days': daysRemaining}),
      ),
      ackable: false,
    );
  }
}
