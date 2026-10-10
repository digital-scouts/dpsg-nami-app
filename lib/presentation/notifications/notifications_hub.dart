import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:nami/domain/qualifikation/plane_qualifikations_erinnerungen_usecase.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/notifications/qualifikations_meldung.dart';
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
    List<EigenerQualifikationsAblauf> eigeneQualifikationsAblaeufe =
        const <EigenerQualifikationsAblauf>[],
  }) {
    final messages = <AppHubNotification>[];

    if (authModel.hasRemoteAccessIssue) {
      messages.add(_buildHitobitoIssueNotification(authModel));
    }

    // Die Warnung kommt vorausschauend, auch ohne fehlgeschlagenen Abruf.
    final remaining = authModel.remainingUntilRelogin;
    if (authModel.isDataExpirySoon && remaining != null) {
      messages.add(_buildDataExpirySoonNotification(remaining));
    }

    if (unresolvedCount > 0) {
      messages.add(_buildMemberResolutionNotification(unresolvedCount));
    }

    if (updateInfo != null) {
      messages.add(_buildUpdateNotification(updateInfo));
    }

    if (eigeneQualifikationsAblaeufe.isNotEmpty) {
      messages.add(
        _buildQualifikationsNotification(eigeneQualifikationsAblaeufe),
      );
    }

    return messages;
  }

  /// Eigene Qualifikationen, die bald ablaufen oder abgelaufen sind.
  static AppHubNotification _buildQualifikationsNotification(
    List<EigenerQualifikationsAblauf> ablaeufe,
  ) {
    final de = AppLocalizations(const Locale('de'));
    final en = AppLocalizations(const Locale('en'));
    final datum = DateFormat('dd.MM.yyyy');
    String titel(AppLocalizations t) {
      if (ablaeufe.length > 1) {
        return t.t('quali_hub_titel_mehrere', {'n': ablaeufe.length});
      }
      final ablauf = ablaeufe.single;
      return t.t(
        ablauf.abgelaufen ? 'quali_hub_titel_abgelaufen' : 'quali_hub_titel',
        {'art': ablauf.artLabel},
      );
    }

    String text(AppLocalizations t) {
      if (ablaeufe.length > 1) {
        return t.t('quali_hub_text_mehrere', {
          'liste': ablaeufe
              .map((a) => '${a.artLabel} (${datum.format(a.gueltigBis)})')
              .join(', '),
        });
      }
      final ablauf = ablaeufe.single;
      return t.t(
        ablauf.abgelaufen ? 'quali_hub_text_abgelaufen' : 'quali_hub_text',
        {'datum': datum.format(ablauf.gueltigBis)},
      );
    }

    return AppHubNotification(
      id: qualifikationsMeldungId,
      source: AppNotificationSource.internal,
      severity: AppNotificationSeverity.warn,
      title: LocalizedString(de: titel(de), en: titel(en)),
      body: LocalizedString(de: text(de), en: text(en)),
      ackable: false,
    );
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

  /// Plattform und Zeitfenster filtert bereits das Repository; hier bleibt die
  /// Bestätigung: Bestätigte Meldungen verschwinden, außer sie werden
  /// ausdrücklich mit angezeigt.
  static List<AppHubNotification> mapVisibleExternal({
    required List<PullNotification> notifications,
    required Set<String> acknowledged,
    bool includeAcknowledged = false,
  }) {
    return notifications
        .where(
          (notification) =>
              includeAcknowledged || !acknowledged.contains(notification.id),
        )
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
    String titleKey;
    if (authModel.requiresInteractiveLogin) {
      titleKey = 'settings_hitobito_login_expired_title';
      bodyKey = 'settings_hitobito_login_expired_body';
    } else if (authModel.remoteAccessBlockedReason ==
        NetworkAccessBlockedReason.offline) {
      titleKey = 'settings_hitobito_issue_title';
      bodyKey = 'settings_hitobito_issue_offline_body';
    } else {
      titleKey = 'settings_hitobito_issue_title';
      bodyKey = 'settings_hitobito_issue_body';
    }

    return AppHubNotification(
      id: 'hitobito-issue',
      source: AppNotificationSource.internal,
      severity: authModel.requiresInteractiveLogin
          ? AppNotificationSeverity.urgent
          : AppNotificationSeverity.warn,
      title: LocalizedString(de: de.t(titleKey), en: en.t(titleKey)),
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

  static String _expiryBody(AppLocalizations t, int days) => days == 1
      ? t.t('ablauf_push_text_eins')
      : t.t('ablauf_push_text_mehr', {'n': days});

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
        de: _expiryBody(de, daysRemaining),
        en: _expiryBody(en, daysRemaining),
      ),
      ackable: false,
    );
  }
}
