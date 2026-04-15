import 'package:flutter/foundation.dart';

@immutable
class MemberPhoneCountryOption {
  const MemberPhoneCountryOption({
    required this.id,
    required this.flag,
    required this.label,
    this.dialCode,
    this.isOther = false,
  });

  final String id;
  final String flag;
  final String label;
  final String? dialCode;
  final bool isOther;

  String get displayLabel => isOther ? '$flag $label' : '$flag $dialCode';
}

@immutable
class MemberPhoneSplitResult {
  const MemberPhoneSplitResult({
    required this.countryId,
    required this.localNumber,
  });

  final String countryId;
  final String localNumber;
}

class MemberPhoneInput {
  static const String defaultCountryId = 'de';
  static const String otherCountryId = 'other';
  static const int minDigits = 6;
  static const int maxDigits = 15;

  static const List<MemberPhoneCountryOption> options =
      <MemberPhoneCountryOption>[
        MemberPhoneCountryOption(
          id: 'de',
          flag: '🇩🇪',
          label: 'Deutschland',
          dialCode: '+49',
        ),
        MemberPhoneCountryOption(
          id: 'at',
          flag: '🇦🇹',
          label: 'Österreich',
          dialCode: '+43',
        ),
        MemberPhoneCountryOption(
          id: 'ch',
          flag: '🇨🇭',
          label: 'Schweiz',
          dialCode: '+41',
        ),
        MemberPhoneCountryOption(
          id: 'fr',
          flag: '🇫🇷',
          label: 'Frankreich',
          dialCode: '+33',
        ),
        MemberPhoneCountryOption(
          id: 'be',
          flag: '🇧🇪',
          label: 'Belgien',
          dialCode: '+32',
        ),
        MemberPhoneCountryOption(
          id: 'nl',
          flag: '🇳🇱',
          label: 'Niederlande',
          dialCode: '+31',
        ),
        MemberPhoneCountryOption(
          id: 'lu',
          flag: '🇱🇺',
          label: 'Luxemburg',
          dialCode: '+352',
        ),
        MemberPhoneCountryOption(
          id: 'dk',
          flag: '🇩🇰',
          label: 'Dänemark',
          dialCode: '+45',
        ),
        MemberPhoneCountryOption(
          id: 'pl',
          flag: '🇵🇱',
          label: 'Polen',
          dialCode: '+48',
        ),
        MemberPhoneCountryOption(
          id: 'cz',
          flag: '🇨🇿',
          label: 'Tschechien',
          dialCode: '+420',
        ),
        MemberPhoneCountryOption(
          id: otherCountryId,
          flag: '🌍',
          label: 'Sonstige',
          isOther: true,
        ),
      ];

  static MemberPhoneCountryOption optionById(String? id) {
    return options.firstWhere(
      (option) => option.id == id,
      orElse: () => options.first,
    );
  }

  static MemberPhoneSplitResult split(String? value) {
    final normalized = normalizeInternational(value);
    if (normalized == null) {
      return const MemberPhoneSplitResult(
        countryId: defaultCountryId,
        localNumber: '',
      );
    }

    final knownOptions =
        options
            .where((option) => !option.isOther && option.dialCode != null)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.dialCode!.length.compareTo(left.dialCode!.length),
          );

    for (final option in knownOptions) {
      if (normalized.startsWith(option.dialCode!)) {
        return MemberPhoneSplitResult(
          countryId: option.id,
          localNumber: normalized.substring(option.dialCode!.length),
        );
      }
    }

    return MemberPhoneSplitResult(
      countryId: otherCountryId,
      localNumber: normalized,
    );
  }

  static String? validate({
    required String countryId,
    required String? localNumber,
    bool required = false,
  }) {
    final trimmed = localNumber?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Telefon darf nicht leer sein.' : null;
    }

    final option = optionById(countryId);
    if (option.isOther) {
      final normalized = normalizeInternational(trimmed);
      if (normalized == null) {
        return 'Bitte bei Sonstige die vollständige Telefonnummer mit +XX angeben.';
      }
      if (!_hasValidLength(normalized)) {
        return 'Bitte eine gültige Telefonnummer eingeben.';
      }
      return null;
    }

    if (_looksInternational(trimmed)) {
      final normalized = normalizeInternational(trimmed);
      if (normalized == null || !_hasValidLength(normalized)) {
        return 'Bitte eine gültige Telefonnummer eingeben.';
      }
      return null;
    }

    final allowedPattern = RegExp(r'^[0-9\-() /]+$');
    if (!allowedPattern.hasMatch(trimmed) ||
        !RegExp(r'[0-9]').hasMatch(trimmed)) {
      return 'Bitte eine gültige Telefonnummer eingeben.';
    }

    final normalized = '${option.dialCode}${_digitsOnly(trimmed)}';
    if (!_hasValidLength(normalized)) {
      return 'Bitte eine gültige Telefonnummer eingeben.';
    }

    return null;
  }

  static String? compose({
    required String countryId,
    required String? localNumber,
  }) {
    final trimmed = localNumber?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }

    final option = optionById(countryId);
    if (option.isOther) {
      return normalizeInternational(trimmed);
    }

    if (_looksInternational(trimmed)) {
      return normalizeInternational(trimmed);
    }

    final digits = _digitsOnly(trimmed);
    if (digits.isEmpty) {
      return null;
    }
    return '${option.dialCode}$digits';
  }

  static String? normalizeInternational(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }

    final normalizedPrefix = trimmed.startsWith('00')
        ? '+${trimmed.substring(2)}'
        : trimmed;
    if (!normalizedPrefix.startsWith('+')) {
      return null;
    }

    final digits = _digitsOnly(normalizedPrefix.substring(1));
    if (digits.isEmpty) {
      return null;
    }

    return '+$digits';
  }

  static bool _looksInternational(String value) {
    return value.startsWith('+') || value.startsWith('00');
  }

  static bool _hasValidLength(String normalizedValue) {
    final digitCount = _digitsOnly(normalizedValue).length;
    return digitCount >= minDigits && digitCount <= maxDigits;
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
