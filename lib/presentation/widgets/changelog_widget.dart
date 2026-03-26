import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ChangelogWidget extends StatefulWidget {
  const ChangelogWidget({super.key});

  @override
  State<ChangelogWidget> createState() => _ChangelogWidgetState();
}

class _ChangelogWidgetState extends State<ChangelogWidget> {
  late final Future<_ChangelogData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_ChangelogData> _loadData() async {
    final manifest = await AppUpdateService().loadVersionManifest();
    String? currentVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
    } catch (_) {}

    final platformKey = _platformKey();
    final platformTitle = _platformTitle(platformKey);
    final platformInfo = switch (platformKey) {
      'android' => manifest?.android,
      'ios' => manifest?.ios,
      _ => null,
    };

    final changelogRaw = await rootBundle.loadString('assets/changelog.json');
    final decoded = jsonDecode(changelogRaw) as Map<String, dynamic>;
    final versions = decoded['versions'] as List<dynamic>? ?? const [];
    final entries = versions
        .whereType<Map<String, dynamic>>()
        .map(_ChangelogEntry.fromJson)
        .toList()
        .reversed
        .toList();

    return _ChangelogData(
      currentVersion: currentVersion,
      platformTitle: platformTitle,
      platformInfo: platformInfo,
      entries: entries,
    );
  }

  String? _platformKey() {
    if (kIsWeb) {
      return null;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null;
    }
  }

  String? _platformTitle(String? platformKey) {
    return switch (platformKey) {
      'android' => 'Android',
      'ios' => 'iOS',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return FutureBuilder<_ChangelogData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text(t.t('changelog_load_error')));
        }

        final data = snapshot.data;
        if (data == null) {
          return Center(child: Text(t.t('changelog_load_error')));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _VersionSummaryCard(
                    title: t.t('changelog_installed_version'),
                    value: data.currentVersion ?? '-',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RemoteVersionSummaryCard(
                    title: t.t('changelog_available_version'),
                    info: data.platformInfo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...data.entries.map((entry) => _ChangelogEntryCard(entry: entry)),
          ],
        );
      },
    );
  }
}

class _VersionSummaryCard extends StatelessWidget {
  const _VersionSummaryCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _RemoteVersionSummaryCard extends StatelessWidget {
  const _RemoteVersionSummaryCard({required this.title, required this.info});

  final String title;
  final RemoteVersionPlatformInfo? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: info == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text('-', style: theme.textTheme.headlineSmall),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(
                    info!.latestVersion,
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ChangelogEntryCard extends StatelessWidget {
  const _ChangelogEntryCard({required this.entry});

  final _ChangelogEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(entry.version),
          subtitle: entry.dataReset ? Text(t.t('changelog_data_reset')) : null,
          children: [
            if (entry.features.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.t('changelog_features'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              ...entry.features.map((item) => _BulletText(text: item)),
              const SizedBox(height: 12),
            ],
            if (entry.bugFixes.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.t('changelog_bugfixes'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              ...entry.bugFixes.map((item) => _BulletText(text: item)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 6),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ChangelogData {
  const _ChangelogData({
    required this.currentVersion,
    required this.platformTitle,
    required this.platformInfo,
    required this.entries,
  });

  final String? currentVersion;
  final String? platformTitle;
  final RemoteVersionPlatformInfo? platformInfo;
  final List<_ChangelogEntry> entries;
}

class _ChangelogEntry {
  const _ChangelogEntry({
    required this.version,
    required this.dataReset,
    required this.features,
    required this.bugFixes,
  });

  final String version;
  final bool dataReset;
  final List<String> features;
  final List<String> bugFixes;

  factory _ChangelogEntry.fromJson(Map<String, dynamic> json) {
    return _ChangelogEntry(
      version: json['version']?.toString() ?? '-',
      dataReset: json['data_reset'] == true,
      features: (json['features'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      bugFixes: (json['bugFixes'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
