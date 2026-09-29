import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/appearance/appearance_catalog.dart';
import '../../domain/appearance/appearance_settings.dart';
import '../../domain/appearance/appearance_settings_repository.dart';
import '../../domain/appearance/support_access.dart';
import '../../services/app_icon_service.dart';

/// Haelt das gewaehlte Erscheinungsbild (Palette, Hintergrund, Badge,
/// App-Icon). Gesperrte Optionen werden beim Lesen auf den Standard
/// zurueckgesetzt, damit ein abgelaufener Kauf nichts mehr anzeigt.
class AppearanceModel extends ChangeNotifier {
  AppearanceModel({
    required AppearanceSettingsRepository repository,
    required AppIconService appIconService,
    SupportAccess access = const UnlockedSupportAccess(),
    AppearanceSettings initial = const AppearanceSettings(),
  }) : _repository = repository,
       _appIconService = appIconService,
       _access = access,
       _settings = initial;

  final AppearanceSettingsRepository _repository;
  final AppIconService _appIconService;
  SupportAccess _access;
  AppearanceSettings _settings;
  bool _iconChangeSupported = false;

  SupportAccess get access => _access;
  bool get supportsAutomaticIcon => _appIconService.supportsAutomaticVariant;

  /// Ob das Geraet alternative App-Icons erlaubt (erst nach [load] gesetzt).
  bool get iconChangeSupported => _iconChangeSupported;

  AppPaletteId get palette =>
      _unlocked(AppearanceCatalog.paletteTiers[_settings.palette]!)
      ? _settings.palette
      : AppPaletteId.standard;

  AppearanceBackgroundId? get background {
    final value = _settings.background;
    if (value == null) {
      return null;
    }
    return _unlocked(AppearanceCatalog.backgroundTiers[value]!) ? value : null;
  }

  SupporterBadgeId? get badge {
    final value = _settings.badge;
    if (value == null) {
      return null;
    }
    return _unlocked(AppearanceCatalog.badge(value).tier) ? value : null;
  }

  AppIconChoice? get appIcon {
    final value = _settings.appIcon;
    if (value == null || !_access.isIconPackageUnlocked(value.package)) {
      return null;
    }
    if (value.variant == AppIconVariant.automatisch && !supportsAutomaticIcon) {
      return null;
    }
    return value;
  }

  bool _unlocked(SupportTier tier) => _access.isTierUnlocked(tier);

  Future<void> load() async {
    _settings = await _repository.load();
    _iconChangeSupported = await _appIconService.isSupported();
    notifyListeners();
  }

  /// Wird nach einem App-Reset aufgerufen: Standard wiederherstellen.
  /// Der Icon-Wechsel wird nicht abgewartet: iOS meldet den Abschluss erst,
  /// wenn der Systemhinweis bestaetigt wurde, und der Reset soll nicht haengen.
  Future<void> reset() async {
    _settings = const AppearanceSettings();
    notifyListeners();
    await _repository.save(_settings);
    unawaited(_appIconService.apply(null).catchError((Object _) {}));
  }

  void updateAccess(SupportAccess access) {
    _access = access;
    notifyListeners();
  }

  Future<void> setPalette(AppPaletteId palette) =>
      _update(_settings.copyWith(palette: palette));

  Future<void> setBackground(AppearanceBackgroundId? background) =>
      _update(_settings.copyWith(background: () => background));

  Future<void> setBadge(SupporterBadgeId? badge) =>
      _update(_settings.copyWith(badge: () => badge));

  Future<void> setAppIcon(AppIconChoice? choice) async {
    await _update(_settings.copyWith(appIcon: () => choice));
    await _appIconService.apply(appIcon);
  }

  Future<void> _update(AppearanceSettings next) async {
    _settings = next;
    notifyListeners();
    await _repository.save(next);
  }
}
