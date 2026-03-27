import 'package:flutter_dotenv/flutter_dotenv.dart';

class HitobitoAuthConfig {
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

  final String clientId;
  final String clientSecret;
  final String authorizationUrl;
  final String tokenUrl;
  final String redirectUri;
  final String scopeString;
  final String discoveryUrl;
  final String profileUrl;

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
    return HitobitoAuthConfig(
      clientId: _env('HITOBITO_OAUTH_CLIENT_ID') ?? '',
      clientSecret: _env('HITOBITO_OAUTH_CLIENT_SECRET') ?? '',
      authorizationUrl: _env('HITOBITO_OAUTH_AUTHORIZATION_URL') ?? '',
      tokenUrl: _env('HITOBITO_OAUTH_TOKEN_URL') ?? '',
      redirectUri: _env('HITOBITO_OAUTH_REDIRECT_URI') ?? '',
      scopeString: _env('HITOBITO_OAUTH_SCOPES') ?? 'openid name email api',
      discoveryUrl: _env('HITOBITO_OAUTH_DISCOVERY_URL') ?? '',
      profileUrl: _env('HITOBITO_OAUTH_PROFILE_URL') ?? '',
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
