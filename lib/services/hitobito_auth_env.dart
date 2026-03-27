import 'package:flutter_dotenv/flutter_dotenv.dart';

class HitobitoAuthConfig {
  static const String defaultScopeString = 'openid name email api with_roles';

  const HitobitoAuthConfig({
    required this.clientId,
    required this.clientSecret,
    required this.authorizationUrl,
    required this.tokenUrl,
    required this.redirectUri,
    required this.scopeString,
    required this.discoveryUrl,
    required this.profileUrl,
  });

  factory HitobitoAuthConfig.fromBaseUrl({
    required String clientId,
    required String clientSecret,
    required String baseUrl,
    required String redirectUri,
    String scopeString = defaultScopeString,
  }) {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final baseUri = Uri.tryParse(normalizedBaseUrl);

    return HitobitoAuthConfig(
      clientId: clientId,
      clientSecret: clientSecret,
      authorizationUrl: _deriveUrl(baseUri, '/oauth/authorize'),
      tokenUrl: _deriveUrl(baseUri, '/oauth/token'),
      redirectUri: redirectUri,
      scopeString: scopeString,
      discoveryUrl: _deriveUrl(baseUri, '/.well-known/openid-configuration'),
      profileUrl: _deriveUrl(baseUri, '/de/oauth/profile'),
    );
  }

  final String clientId;
  final String clientSecret;
  final String authorizationUrl;
  final String tokenUrl;
  final String redirectUri;
  final String scopeString;
  final String discoveryUrl;
  final String profileUrl;

  static String _normalizeBaseUrl(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static String _deriveUrl(Uri? baseUri, String path) {
    if (baseUri == null) {
      return '';
    }

    return baseUri.replace(path: path, queryParameters: null).toString();
  }

  Uri? get peopleUri {
    final base = Uri.tryParse(
      profileUrl.isNotEmpty ? profileUrl : authorizationUrl,
    );
    if (base == null) {
      return null;
    }

    return base.replace(path: '/api/people', queryParameters: null);
  }

  List<String> get scopes => scopeString
      .split(RegExp(r'\s+'))
      .where((scope) => scope.isNotEmpty)
      .toList();

  Uri? get redirectUriValue => Uri.tryParse(redirectUri);

  String get callbackScheme => redirectUriValue?.scheme ?? '';

  bool get isConfigured =>
      clientId.isNotEmpty &&
      clientSecret.isNotEmpty &&
      authorizationUrl.isNotEmpty &&
      tokenUrl.isNotEmpty &&
      profileUrl.isNotEmpty &&
      redirectUri.isNotEmpty &&
      callbackScheme.isNotEmpty;
}

class HitobitoAuthEnv {
  static HitobitoAuthConfig get authConfig {
    return HitobitoAuthConfig.fromBaseUrl(
      clientId: _env('HITOBITO_OAUTH_CLIENT_ID') ?? '',
      clientSecret: _env('HITOBITO_OAUTH_CLIENT_SECRET') ?? '',
      baseUrl: _env('HITOBITO_BASE_URL') ?? '',
      redirectUri: _env('HITOBITO_OAUTH_REDIRECT_URI') ?? '',
    );
  }

  static Duration get maxDataAge {
    final daysRaw = _env('HITOBITO_DATA_MAX_AGE_DAYS');
    final days = int.tryParse(daysRaw ?? '');
    if (days == null || days <= 0) {
      return const Duration(days: 90);
    }
    return Duration(days: days);
  }

  static Duration get refreshInterval {
    final hoursRaw = _env('HITOBITO_REFRESH_INTERVAL_HOURS');
    final hours = int.tryParse(hoursRaw ?? '');
    if (hours == null || hours <= 0) {
      return const Duration(hours: 24);
    }
    return Duration(hours: hours);
  }

  static String? _env(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}
