import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_update_env.dart';

enum AppUpdateAvailability { available, required }

class RemoteVersionPlatformInfo {
  const RemoteVersionPlatformInfo({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.storeUrl,
  });

  final String latestVersion;
  final String minSupportedVersion;
  final String storeUrl;
}

class RemoteVersionManifest {
  const RemoteVersionManifest({this.android, this.ios});

  final RemoteVersionPlatformInfo? android;
  final RemoteVersionPlatformInfo? ios;
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.availability,
    required this.currentVersion,
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.storeUrl,
  });

  final AppUpdateAvailability availability;
  final String currentVersion;
  final String latestVersion;
  final String minSupportedVersion;
  final String storeUrl;

  bool get isRequired => availability == AppUpdateAvailability.required;
}

typedef AppVersionProvider = Future<String> Function();
typedef VersionManifestProvider = Future<Map<String, dynamic>> Function();
typedef VersionManifestBodyFetcher =
    Future<String> Function(String url, Duration timeout);
typedef PreferencesProvider = Future<SharedPreferences> Function();

class AppUpdateService {
  static const String _manifestCacheKey = 'app_update_manifest_cache';
  static const String _lastFetchAtKey = 'app_update_manifest_last_fetch_at';

  AppUpdateService({
    AppVersionProvider? currentVersionProvider,
    VersionManifestProvider? manifestProvider,
    VersionManifestBodyFetcher? manifestBodyFetcher,
    PreferencesProvider? preferencesProvider,
    DateTime Function()? nowProvider,
    String? manifestUrl,
    Duration? minFetchInterval,
    Duration? fetchTimeout,
    this.platformOverride,
  }) : _currentVersionProvider =
           currentVersionProvider ?? _defaultCurrentVersionProvider,
       _manifestProvider = manifestProvider,
       _manifestBodyFetcher =
           manifestBodyFetcher ?? _defaultManifestBodyFetcher,
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _nowProvider = nowProvider ?? DateTime.now,
       _manifestUrl = manifestUrl ?? AppUpdateEnv.url,
       _minFetchInterval = minFetchInterval ?? AppUpdateEnv.minFetchInterval,
       _fetchTimeout = fetchTimeout ?? AppUpdateEnv.fetchTimeout;

  final AppVersionProvider _currentVersionProvider;
  final VersionManifestProvider? _manifestProvider;
  final VersionManifestBodyFetcher _manifestBodyFetcher;
  final PreferencesProvider _preferencesProvider;
  final DateTime Function() _nowProvider;
  final String _manifestUrl;
  final Duration _minFetchInterval;
  final Duration _fetchTimeout;
  final String? platformOverride;

  Future<RemoteVersionManifest?> loadVersionManifest() async {
    final manifest = await _loadManifest();
    if (manifest.isEmpty) {
      return null;
    }

    return RemoteVersionManifest(
      android: _parsePlatformInfo(manifest['android']),
      ios: _parsePlatformInfo(manifest['ios']),
    );
  }

  Future<AppUpdateInfo?> checkForUpdate() async {
    final platformKey = platformOverride ?? _resolvePlatformKey();
    if (platformKey == null) {
      return null;
    }

    final currentVersionRaw = await _currentVersionProvider();
    final versionManifest = await loadVersionManifest();
    final platformInfo = switch (platformKey) {
      'android' => versionManifest?.android,
      'ios' => versionManifest?.ios,
      _ => null,
    };

    if (platformInfo == null) {
      return null;
    }

    final currentVersion = _SemVer.tryParse(currentVersionRaw);
    final latestVersion = _SemVer.tryParse(platformInfo.latestVersion);
    final minSupportedVersion = _SemVer.tryParse(
      platformInfo.minSupportedVersion,
    );
    final storeUrl = platformInfo.storeUrl;

    if (currentVersion == null ||
        latestVersion == null ||
        minSupportedVersion == null ||
        storeUrl.isEmpty) {
      return null;
    }

    if (currentVersion.compareTo(minSupportedVersion) < 0) {
      return AppUpdateInfo(
        availability: AppUpdateAvailability.required,
        currentVersion: currentVersion.release,
        latestVersion: latestVersion.release,
        minSupportedVersion: minSupportedVersion.release,
        storeUrl: storeUrl,
      );
    }

    if (currentVersion.compareTo(latestVersion) < 0) {
      return AppUpdateInfo(
        availability: AppUpdateAvailability.available,
        currentVersion: currentVersion.release,
        latestVersion: latestVersion.release,
        minSupportedVersion: minSupportedVersion.release,
        storeUrl: storeUrl,
      );
    }

    return null;
  }

  static Future<String> _defaultCurrentVersionProvider() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<Map<String, dynamic>> _loadManifest() async {
    if (_manifestProvider != null) {
      return _manifestProvider();
    }

    if (_manifestUrl.isEmpty) {
      return {};
    }

    final prefs = await _preferencesProvider();
    final cachedRaw = prefs.getString(_manifestCacheKey);
    final lastFetchAtRaw = prefs.getString(_lastFetchAtKey);
    final lastFetchAt = DateTime.tryParse(lastFetchAtRaw ?? '');
    final now = _nowProvider();

    final isCacheFresh =
        cachedRaw != null &&
        lastFetchAt != null &&
        now.difference(lastFetchAt) < _minFetchInterval;

    if (isCacheFresh) {
      return _decodeManifest(cachedRaw);
    }

    try {
      final responseBody = await _manifestBodyFetcher(
        _manifestUrl,
        _fetchTimeout,
      );
      await prefs.setString(_manifestCacheKey, responseBody);
      await prefs.setString(_lastFetchAtKey, now.toIso8601String());
      return _decodeManifest(responseBody);
    } catch (_) {
      if (cachedRaw != null) {
        return _decodeManifest(cachedRaw);
      }
      rethrow;
    }
  }

  static Future<String> _defaultManifestBodyFetcher(
    String url,
    Duration timeout,
  ) async {
    final response = await http.get(Uri.parse(url)).timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Version Manifest konnte nicht geladen werden.');
    }

    return response.body;
  }

  static Map<String, dynamic> _decodeManifest(String rawBody) {
    final decoded = jsonDecode(rawBody);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Version Manifest hat ein ungueltiges Format.');
    }

    return decoded;
  }

  static RemoteVersionPlatformInfo? _parsePlatformInfo(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final latestVersion = raw['latest']?.toString();
    final minSupportedVersion = raw['min_supported']?.toString();
    final storeUrl = raw['store_url']?.toString();

    if (latestVersion == null ||
        latestVersion.isEmpty ||
        minSupportedVersion == null ||
        minSupportedVersion.isEmpty ||
        storeUrl == null ||
        storeUrl.isEmpty) {
      return null;
    }

    return RemoteVersionPlatformInfo(
      latestVersion: latestVersion,
      minSupportedVersion: minSupportedVersion,
      storeUrl: storeUrl,
    );
  }

  static String? _resolvePlatformKey() {
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
}

class _SemVer implements Comparable<_SemVer> {
  const _SemVer(this.major, this.minor, this.patch);

  static final RegExp _pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$');

  final int major;
  final int minor;
  final int patch;

  String get release => '$major.$minor.$patch';

  static _SemVer? tryParse(String input) {
    final match = _pattern.firstMatch(input.trim());
    if (match == null) {
      return null;
    }

    return _SemVer(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(_SemVer other) {
    final majorCompare = major.compareTo(other.major);
    if (majorCompare != 0) {
      return majorCompare;
    }

    final minorCompare = minor.compareTo(other.minor);
    if (minorCompare != 0) {
      return minorCompare;
    }

    return patch.compareTo(other.patch);
  }
}
