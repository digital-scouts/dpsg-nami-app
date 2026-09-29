import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/appearance/appearance_catalog.dart';

/// Wechselt das App-Icon ueber die native Bruecke `com.namiapp/app_icon`.
/// iOS nutzt alternative Icons (Icon Composer), Android `activity-alias`.
abstract class AppIconService {
  /// Nur iOS kann dem Hell/Dunkel-Modus des Systems folgen.
  bool get supportsAutomaticVariant;

  Future<bool> isSupported();

  /// `null` setzt das Standard-Icon.
  Future<void> apply(AppIconChoice? choice);
}

class MethodChannelAppIconService implements AppIconService {
  MethodChannelAppIconService({
    MethodChannel channel = const MethodChannel('com.namiapp/app_icon'),
    bool? isIOS,
  }) : _channel = channel,
       _isIOS = isIOS ?? Platform.isIOS;

  final MethodChannel _channel;
  final bool _isIOS;

  @override
  bool get supportsAutomaticVariant => _isIOS;

  @override
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> apply(AppIconChoice? choice) async {
    final effective = choice?.variant == AppIconVariant.automatisch && !_isIOS
        ? null
        : choice;
    await _channel.invokeMethod<void>('setIcon', {'name': effective?.key});
  }
}

/// Fuer Tests und Storybook: merkt sich nur den letzten Aufruf.
class FakeAppIconService implements AppIconService {
  FakeAppIconService({this.supportsAutomaticVariant = true});

  @override
  final bool supportsAutomaticVariant;

  AppIconChoice? applied;
  int applyCount = 0;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> apply(AppIconChoice? choice) async {
    applied = choice;
    applyCount++;
  }
}
