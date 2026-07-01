import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'mitglied.dart';

class MemberAddressUtils {
  static String fingerprintFromText(String addressText) {
    final normalized = addressText.trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static String formatMultilineAddress(MitgliedKontaktAdresse address) {
    return _addressLines(address).join('\n');
  }

  static String formatSingleLineAddress(MitgliedKontaktAdresse address) {
    return _addressLines(address).join(', ');
  }

  static String formatCompactDisplayAddress(MitgliedKontaktAdresse address) {
    final streetLine = _joinParts(
      _trimToNull(address.street),
      _trimToNull(address.housenumber),
    );
    final cityLine = _joinParts(
      _trimToNull(address.zipCode),
      _trimToNull(address.town),
    );

    return [
      if (streetLine != null) streetLine,
      if (cityLine != null) cityLine,
    ].join(', ');
  }

  static String formatMapQueryAddress(MitgliedKontaktAdresse address) {
    final streetLine = _joinParts(
      _trimToNull(address.street),
      _trimToNull(address.housenumber),
    );
    final cityLine = _joinParts(
      _trimToNull(address.zipCode),
      _trimToNull(address.town),
    );
    final country = _trimToNull(address.country);

    return [
      if (streetLine != null) streetLine,
      if (cityLine != null) cityLine,
      if (country != null) country,
    ].join(', ');
  }

  static String fingerprint(MitgliedKontaktAdresse address) {
    final normalized = <String>[
      address.addressCareOf ?? '',
      address.street ?? '',
      address.housenumber ?? '',
      address.postbox ?? '',
      address.zipCode ?? '',
      address.town ?? '',
      address.country ?? '',
    ].map((part) => part.trim().toLowerCase()).join('|');
    return fingerprintFromText(normalized);
  }

  static List<String> _addressLines(MitgliedKontaktAdresse address) {
    final lines = <String>[];

    final careOf = _trimToNull(address.addressCareOf);
    if (careOf != null) {
      lines.add(careOf);
    }

    final streetLine = _joinParts(
      _trimToNull(address.street),
      _trimToNull(address.housenumber),
    );
    if (streetLine != null) {
      lines.add(streetLine);
    }

    final postbox = _trimToNull(address.postbox);
    if (postbox != null) {
      lines.add(postbox.startsWith('PF ') ? postbox : 'PF $postbox');
    }

    final cityLine = _joinParts(
      _trimToNull(address.zipCode),
      _trimToNull(address.town),
    );
    if (cityLine != null) {
      lines.add(cityLine);
    }

    final country = _trimToNull(address.country);
    if (country != null) {
      lines.add(country);
    }

    return lines;
  }

  static String? _joinParts(String? left, String? right) {
    if (left == null && right == null) {
      return null;
    }
    if (left == null) {
      return right;
    }
    if (right == null) {
      return left;
    }
    return '$left $right';
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
