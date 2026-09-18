import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/nami_ai/nami_ai_access_service.dart';
import 'package:nami/services/nami_ai/nami_ai_service.dart';

class _FakeMembershipService extends NamiAiMembershipService {
  _FakeMembershipService(this._hasPremium);

  final bool _hasPremium;

  @override
  Future<bool> hasPremiumAccess() async => _hasPremium;
}

class _FakeAvailabilityService extends NamiAiAvailabilityService {
  _FakeAvailabilityService(this._availability);

  final NamiAiAvailability _availability;

  @override
  Future<NamiAiAvailability> check() async => _availability;
}

void main() {
  NamiAiAccessService buildService({
    bool isIos = true,
    String osVersion = '26.0',
    NamiAiAvailability availability = const NamiAiAvailability(available: true),
    bool hasPremium = true,
  }) {
    return NamiAiAccessService(
      isIosPlatform: () => isIos,
      osVersionProvider: () => osVersion,
      availabilityService: _FakeAvailabilityService(availability),
      membershipService: _FakeMembershipService(hasPremium),
    );
  }

  setUp(() {
    dotenv.loadFromString(envString: 'NAMI_AI_ENABLED=true\n');
  });

  test('envDisabled when the feature flag is off', () async {
    dotenv.loadFromString(envString: 'NAMI_AI_ENABLED=false\n');

    final decision = await buildService().evaluate();

    expect(decision.state, NamiAiAccessState.hidden);
    expect(decision.reason, NamiAiBlockReason.envDisabled);
  });

  test('unsupportedPlatform when not on iOS', () async {
    final decision = await buildService(isIos: false).evaluate();

    expect(decision.state, NamiAiAccessState.hidden);
    expect(decision.reason, NamiAiBlockReason.unsupportedPlatform);
  });

  test('unsupportedIosVersion when below minIosMajorVersion', () async {
    final decision = await buildService(osVersion: '17.0').evaluate();

    expect(decision.state, NamiAiAccessState.hidden);
    expect(decision.reason, NamiAiBlockReason.unsupportedIosVersion);
  });

  test('unsupportedDevice when native availability check fails', () async {
    final decision = await buildService(
      availability: const NamiAiAvailability(
        available: false,
        reason: 'ai_device_not_eligible',
      ),
    ).evaluate();

    expect(decision.state, NamiAiAccessState.hidden);
    expect(decision.reason, NamiAiBlockReason.unsupportedDevice);
  });

  test('lockedByMembership when premium is required but missing', () async {
    final decision = await buildService(hasPremium: false).evaluate();

    expect(decision.state, NamiAiAccessState.lockedByMembership);
    expect(decision.reason, NamiAiBlockReason.membershipRequired);
  });

  test('enabled when all gates pass', () async {
    final decision = await buildService().evaluate();

    expect(decision.state, NamiAiAccessState.enabled);
    expect(decision.reason, isNull);
  });
}
