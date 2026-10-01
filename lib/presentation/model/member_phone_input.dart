import 'package:flutter/foundation.dart';

@immutable
class MemberPhoneCountryOption {
  const MemberPhoneCountryOption({
    required this.id,
    required this.flag,
    required this.label,
    this.dialCode,
    this.trunkPrefix,
    this.minNationalDigits = MemberPhoneInput.minDigits,
    this.isOther = false,
  });

  final String id;
  final String flag;
  final String label;
  final String? dialCode;

  /// Verkehrsausscheidungsziffer, die national vor der Nummer steht, nach der
  /// Laendervorwahl aber entfaellt (`0170 …` wird `+49 170 …`).
  final String? trunkPrefix;

  /// Mindestanzahl Ziffern der Nummer ohne Laendervorwahl und ohne
  /// [trunkPrefix].
  final int minNationalDigits;
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
          trunkPrefix: '0',
          minNationalDigits: 6,
        ),
        MemberPhoneCountryOption(
          id: 'at',
          flag: '🇦🇹',
          label: 'Österreich',
          dialCode: '+43',
          trunkPrefix: '0',
          minNationalDigits: 6,
        ),
        MemberPhoneCountryOption(
          id: 'ch',
          flag: '🇨🇭',
          label: 'Schweiz',
          dialCode: '+41',
          trunkPrefix: '0',
          minNationalDigits: 9,
        ),
        MemberPhoneCountryOption(
          id: 'fr',
          flag: '🇫🇷',
          label: 'Frankreich',
          dialCode: '+33',
          trunkPrefix: '0',
          minNationalDigits: 9,
        ),
        MemberPhoneCountryOption(
          id: 'be',
          flag: '🇧🇪',
          label: 'Belgien',
          dialCode: '+32',
          trunkPrefix: '0',
          minNationalDigits: 8,
        ),
        MemberPhoneCountryOption(
          id: 'nl',
          flag: '🇳🇱',
          label: 'Niederlande',
          dialCode: '+31',
          trunkPrefix: '0',
          minNationalDigits: 9,
        ),
        MemberPhoneCountryOption(
          id: 'lu',
          flag: '🇱🇺',
          label: 'Luxemburg',
          dialCode: '+352',
          minNationalDigits: 4,
        ),
        MemberPhoneCountryOption(
          id: 'dk',
          flag: '🇩🇰',
          label: 'Dänemark',
          dialCode: '+45',
          minNationalDigits: 8,
        ),
        MemberPhoneCountryOption(
          id: 'pl',
          flag: '🇵🇱',
          label: 'Polen',
          dialCode: '+48',
          minNationalDigits: 9,
        ),
        MemberPhoneCountryOption(
          id: 'cz',
          flag: '🇨🇿',
          label: 'Tschechien',
          dialCode: '+420',
          minNationalDigits: 9,
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

    final option = _knownOptionFor(normalized);
    if (option != null) {
      return MemberPhoneSplitResult(
        countryId: option.id,
        localNumber: normalized.substring(option.dialCode!.length),
      );
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

    final normalized = '${option.dialCode}${_nationalDigits(option, trimmed)}';
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

    final digits = _nationalDigits(option, trimmed);
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

    // `+49 (0) 170 …` und `+49 0170 …` meinen `+49 170 …`.
    final option = _knownOptionFor('+$digits');
    final trunkPrefix = option?.trunkPrefix;
    if (option != null && trunkPrefix != null) {
      final dialDigits = option.dialCode!.substring(1);
      final national = digits.substring(dialDigits.length);
      if (national.startsWith(trunkPrefix)) {
        return '+$dialDigits${national.substring(trunkPrefix.length)}';
      }
    }
    return '+$digits';
  }

  /// Ziffern einer national eingegebenen Nummer ohne [trunkPrefix].
  static String _nationalDigits(MemberPhoneCountryOption option, String value) {
    final digits = _digitsOnly(value);
    final trunkPrefix = option.trunkPrefix;
    if (trunkPrefix != null && digits.startsWith(trunkPrefix)) {
      return digits.substring(trunkPrefix.length);
    }
    return digits;
  }

  static MemberPhoneCountryOption? _knownOptionFor(String normalized) {
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
        return option;
      }
    }
    return null;
  }

  static bool _looksInternational(String value) {
    return value.startsWith('+') || value.startsWith('00');
  }

  /// Prueft eine normalisierte `+…`-Nummer. Bei bekannten Laendern zaehlt
  /// die Mindestlaenge ohne Laendervorwahl, sonst die gesamte Nummer.
  static bool _hasValidLength(String normalizedValue) {
    final digitCount = _digitsOnly(normalizedValue).length;
    if (digitCount > maxDigits) {
      return false;
    }
    final option = _knownOptionFor(normalizedValue);
    if (option == null) {
      return digitCount >= minDigits;
    }
    final dialDigits = option.dialCode!.length - 1;
    return digitCount - dialDigits >= option.minNationalDigits;
  }

  /// Ob [left] und [right] dieselbe Nummer meinen, unabhaengig von
  /// Formatierung wie Leerzeichen, Klammern oder `(0)`.
  static bool isSameNumber(String left, String right) {
    final normalizedLeft = normalizeInternational(left);
    return normalizedLeft != null &&
        normalizedLeft == normalizeInternational(right);
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
