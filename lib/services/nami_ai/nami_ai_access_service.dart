import 'dart:io';

import 'nami_ai_env.dart';
import 'nami_ai_service.dart';

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

class NamiAiAvailabilityService {
  NamiAiAvailabilityService({NamiAiService? service}) : _service = service;

  final NamiAiService? _service;

  Future<NamiAiAvailability> check() =>
      (_service ?? NamiAiService()).checkAvailability();
}

class NamiAiAccessService {
  /// Reale Mindestversion des FoundationModels-Frameworks (siehe specs/nami-ai-roadmap.md
  /// Abschnitt 2.3/2.6) - ein technisches API-Faktum, kein Rollout-Hebel, deshalb bewusst
  /// fest codiert statt per Env-Flag konfigurierbar.
  static const int _minIosMajorVersion = 26;

  NamiAiAccessService({
    NamiAiMembershipService? membershipService,
    NamiAiAvailabilityService? availabilityService,
    bool Function()? isIosPlatform,
    String Function()? osVersionProvider,
  }) : _membershipService = membershipService,
       _availabilityService = availabilityService,
       _isIosPlatform = isIosPlatform,
       _osVersionProvider = osVersionProvider;

  final NamiAiMembershipService? _membershipService;
  final NamiAiAvailabilityService? _availabilityService;
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
    if (iosMajorVersion == null || iosMajorVersion < _minIosMajorVersion) {
      return const NamiAiAccessDecision(
        state: NamiAiAccessState.hidden,
        reason: NamiAiBlockReason.unsupportedIosVersion,
      );
    }

    final availability =
        await (_availabilityService ?? NamiAiAvailabilityService()).check();
    if (!availability.available) {
      return const NamiAiAccessDecision(
        state: NamiAiAccessState.hidden,
        reason: NamiAiBlockReason.unsupportedDevice,
      );
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
}
