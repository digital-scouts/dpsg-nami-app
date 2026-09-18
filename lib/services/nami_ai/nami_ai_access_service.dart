import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import 'nami_ai_env.dart';

enum NamiAiAccessState { hidden, lockedByMembership, enabled }

enum NamiAiBlockReason {
  envDisabled,
  unsupportedPlatform,
  unsupportedIosVersion,
  unsupportedDevice,
  membershipRequired,
}

class NamiAiAccessDecision {
  const NamiAiAccessDecision({required this.state, this.reason});

  final NamiAiAccessState state;
  final NamiAiBlockReason? reason;

  bool get isHidden => state == NamiAiAccessState.hidden;
  bool get isMembershipLocked => state == NamiAiAccessState.lockedByMembership;
  bool get isEnabled => state == NamiAiAccessState.enabled;
}

class NamiAiMembershipService {
  Future<bool> hasPremiumAccess() async {
    return NamiAiEnv.premiumActive;
  }
}

class NamiAiDeviceService {
  NamiAiDeviceService({DeviceInfoPlugin? plugin}) : _plugin = plugin;

  final DeviceInfoPlugin? _plugin;

  Future<String?> iosModelIdentifier() async {
    if (!Platform.isIOS) {
      return null;
    }
    final plugin = _plugin ?? DeviceInfoPlugin();
    final info = await plugin.iosInfo;
    return info.utsname.machine.trim();
  }
}

class NamiAiAccessService {
  NamiAiAccessService({
    NamiAiMembershipService? membershipService,
    NamiAiDeviceService? deviceService,
    bool Function()? isIosPlatform,
    String Function()? osVersionProvider,
  }) : _membershipService = membershipService,
       _deviceService = deviceService,
       _isIosPlatform = isIosPlatform,
       _osVersionProvider = osVersionProvider;

  final NamiAiMembershipService? _membershipService;
  final NamiAiDeviceService? _deviceService;
  final bool Function()? _isIosPlatform;
  final String Function()? _osVersionProvider;

  Future<NamiAiAccessDecision> evaluate() async {
    if (!NamiAiEnv.enabled) {
      return const NamiAiAccessDecision(
        state: NamiAiAccessState.hidden,
        reason: NamiAiBlockReason.envDisabled,
      );
    }

    final isIos = _isIosPlatform?.call() ?? Platform.isIOS;
    if (!isIos) {
      return const NamiAiAccessDecision(
        state: NamiAiAccessState.hidden,
        reason: NamiAiBlockReason.unsupportedPlatform,
      );
    }

    final iosMajorVersion = _resolveIosMajorVersion();
    if (iosMajorVersion == null ||
        iosMajorVersion < NamiAiEnv.minIosMajorVersion) {
      return const NamiAiAccessDecision(
        state: NamiAiAccessState.hidden,
        reason: NamiAiBlockReason.unsupportedIosVersion,
      );
    }

    final deviceGateMode = NamiAiEnv.deviceGateMode;
    if (deviceGateMode != 'off') {
      final modelIdentifier = await (_deviceService ?? NamiAiDeviceService())
          .iosModelIdentifier();
      final allowed = _isAllowedDevice(modelIdentifier, mode: deviceGateMode);
      if (!allowed) {
        return const NamiAiAccessDecision(
          state: NamiAiAccessState.hidden,
          reason: NamiAiBlockReason.unsupportedDevice,
        );
      }
    }

    final requiresPremium = NamiAiEnv.requirePremium;
    if (requiresPremium) {
      final hasPremium = await (_membershipService ?? NamiAiMembershipService())
          .hasPremiumAccess();
      if (!hasPremium) {
        return const NamiAiAccessDecision(
          state: NamiAiAccessState.lockedByMembership,
          reason: NamiAiBlockReason.membershipRequired,
        );
      }
    }

    return const NamiAiAccessDecision(state: NamiAiAccessState.enabled);
  }

  int? _resolveIosMajorVersion() {
    final versionString =
        _osVersionProvider?.call() ?? Platform.operatingSystemVersion;
    final match = RegExp(r'(\d+)').firstMatch(versionString);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  bool _isAllowedDevice(String? modelIdentifier, {required String mode}) {
    final model = (modelIdentifier ?? '').trim();
    if (model.isEmpty) {
      return false;
    }

    final patterns = switch (mode) {
      'apple_intelligence' => NamiAiEnv.appleIntelligenceWhitelist,
      'whitelist' => NamiAiEnv.deviceWhitelist,
      _ => NamiAiEnv.deviceWhitelist,
    };

    for (final pattern in patterns) {
      if (_matchesPattern(model, pattern)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesPattern(String value, String pattern) {
    final normalized = pattern.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (!normalized.contains('*')) {
      return value == normalized;
    }
    final escaped = RegExp.escape(normalized).replaceAll('\\*', '.*');
    return RegExp('^$escaped\$').hasMatch(value);
  }
}
