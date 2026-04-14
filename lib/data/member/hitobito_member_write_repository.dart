import '../../domain/auth/auth_session.dart';
import '../../domain/member/member_write_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../services/hitobito_api_exception.dart';
import '../../services/hitobito_people_service.dart';
import '../../services/logger_service.dart';
import '../../services/network_access_policy.dart';

typedef MemberWriteRemoteAccessExecutor =
    Future<T?> Function<T>({
      required String trigger,
      required Future<T> Function(AuthSession session) action,
      bool forceRefresh,
    });

class HitobitoMemberWriteRepository implements MemberWriteRepository {
  HitobitoMemberWriteRepository({
    required HitobitoPeopleService peopleService,
    MemberWriteRemoteAccessExecutor? remoteAccessExecutor,
    required LoggerService logger,
  }) : _peopleService = peopleService,
       _remoteAccessExecutor = remoteAccessExecutor,
       _logger = logger;

  final HitobitoPeopleService _peopleService;
  final MemberWriteRemoteAccessExecutor? _remoteAccessExecutor;
  final LoggerService _logger;

  static const String _authRequiredMessage =
      'Die Sitzung ist nicht mehr gueltig. Bitte erneut anmelden und danach den Vorgang wiederholen.';

  @override
  Future<Mitglied> fetchRemoteMember({
    required String accessToken,
    required int personId,
  }) async {
    try {
      final remoteMember = await _executeRemoteAccess<Mitglied>(
        trigger: 'member_fetch_remote',
        accessToken: accessToken,
        action: (effectiveAccessToken) => _fetchRemoteMemberDirect(
          accessToken: effectiveAccessToken,
          personId: personId,
        ),
      );
      return remoteMember;
    } on MemberWriteException {
      rethrow;
    } on NetworkAccessBlockedException catch (error) {
      throw MemberWriteNetworkBlockedException(error.message);
    } on HitobitoApiException catch (error) {
      await _logger.logWarn(
        'member_write',
        'Fetch verworfen reason=api_exception person_id=$personId status=${error.statusCode ?? 0} detail="${_compactLogValue(error.message)}"',
      );
      throw _mapApiException(error);
    }
  }

  @override
  Future<Mitglied> updateMember({
    required String accessToken,
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
  }) async {
    final personId = zielMitglied.personId ?? basisMitglied.personId;
    if (personId == null || personId <= 0) {
      throw const MemberWriteException(
        'Die Person kann ohne gueltige Person-ID nicht bearbeitet werden.',
      );
    }

    final basisUpdatedAt = basisMitglied.updatedAt;
    if (basisUpdatedAt == null) {
      await _logger.logWarn(
        'member_write',
        'Update verworfen reason=missing_local_updated_at person_id=$personId',
      );
      throw const MemberWriteUpdatedAtMissingException(
        'Die Person wurde lokal ohne updatedAt geladen. Bitte neu laden und erneut versuchen.',
      );
    }

    try {
      return await _executeRemoteAccess<Mitglied>(
        trigger: 'member_update',
        accessToken: accessToken,
        action: (effectiveAccessToken) async {
          final remoteMitglied = await _fetchRemoteMemberDirect(
            accessToken: effectiveAccessToken,
            personId: personId,
          );
          final remoteUpdatedAt = remoteMitglied.updatedAt;
          if (remoteUpdatedAt == null) {
            await _logger.logWarn(
              'member_write',
              'Update verworfen reason=missing_remote_updated_at person_id=$personId',
            );
            throw const MemberWriteUpdatedAtMissingException(
              'Die Person hat remote kein updatedAt. Bitte neu laden und erneut versuchen.',
            );
          }

          if (remoteUpdatedAt != basisUpdatedAt) {
            await _logger.logWarn(
              'member_write',
              'Update verworfen reason=updated_at_conflict person_id=$personId local=$basisUpdatedAt remote=$remoteUpdatedAt',
            );
            throw const MemberWriteConflictException(
              'Die Person wurde zwischenzeitlich geaendert. Bitte neu laden und erneut versuchen.',
            );
          }

          final normalizedTarget = zielMitglied.copyWith(personId: personId);
          await _peopleService.updatePerson(
            effectiveAccessToken,
            mitglied: normalizedTarget,
          );
          await _syncPhoneNumbers(
            accessToken: effectiveAccessToken,
            personId: personId,
            remoteMitglied: remoteMitglied,
            zielMitglied: normalizedTarget,
          );
          await _syncAdditionalEmails(
            accessToken: effectiveAccessToken,
            personId: personId,
            remoteMitglied: remoteMitglied,
            zielMitglied: normalizedTarget,
          );
          await _syncAdditionalAddresses(
            accessToken: effectiveAccessToken,
            personId: personId,
            remoteMitglied: remoteMitglied,
            zielMitglied: normalizedTarget,
          );

          return _fetchRemoteMemberDirect(
            accessToken: effectiveAccessToken,
            personId: personId,
          );
        },
      );
    } on MemberWriteException {
      rethrow;
    } on NetworkAccessBlockedException catch (error) {
      throw MemberWriteNetworkBlockedException(error.message);
    } on HitobitoApiException catch (error) {
      await _logger.logWarn(
        'member_write',
        'Update verworfen reason=api_exception person_id=$personId status=${error.statusCode ?? 0} detail="${_compactLogValue(error.message)}"',
      );
      throw _mapApiException(error);
    }
  }

  Future<Mitglied> _fetchRemoteMemberDirect({
    required String accessToken,
    required int personId,
  }) async {
    final resource = await _peopleService.fetchPersonResourceById(
      accessToken,
      personId,
    );
    return resource.toMitglied();
  }

  Future<T> _executeRemoteAccess<T>({
    required String trigger,
    required String accessToken,
    required Future<T> Function(String accessToken) action,
  }) async {
    final executor = _remoteAccessExecutor;
    if (executor == null) {
      return action(accessToken);
    }

    final result = await executor<T>(
      trigger: trigger,
      action: (session) => action(session.accessToken),
    );
    if (result == null) {
      throw const MemberWriteAuthRequiredException(_authRequiredMessage);
    }
    return result;
  }

  MemberWriteException _mapApiException(HitobitoApiException error) {
    switch (error.statusCode) {
      case 400:
      case 403:
      case 404:
      case 422:
        return const MemberWriteRejectedException(
          'Die Aenderung wurde von Hitobito abgelehnt und kann nicht automatisch erneut versucht werden.',
        );
      case 409:
        return const MemberWriteConflictException(
          'Die Person wurde zwischenzeitlich geaendert. Bitte neu laden und erneut versuchen.',
        );
      case 401:
        return const MemberWriteAuthRequiredException(_authRequiredMessage);
      default:
        return MemberWriteException(error.message);
    }
  }

  String _compactLogValue(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _syncPhoneNumbers({
    required String accessToken,
    required int personId,
    required Mitglied remoteMitglied,
    required Mitglied zielMitglied,
  }) async {
    final remoteById = <int, MitgliedKontaktTelefon>{
      for (final telefonnummer in remoteMitglied.telefonnummern)
        if ((telefonnummer.phoneNumberId ?? 0) > 0)
          telefonnummer.phoneNumberId!: telefonnummer,
    };
    final zielById = <int, MitgliedKontaktTelefon>{
      for (final telefonnummer in zielMitglied.telefonnummern)
        if ((telefonnummer.phoneNumberId ?? 0) > 0)
          telefonnummer.phoneNumberId!: telefonnummer,
    };

    for (final entry in remoteById.entries) {
      if (!zielById.containsKey(entry.key)) {
        await _peopleService.deletePhoneNumber(
          accessToken,
          phoneNumberId: entry.key,
        );
      }
    }

    for (final telefonnummer in zielMitglied.telefonnummern) {
      final phoneNumberId = telefonnummer.phoneNumberId;
      if (phoneNumberId == null || phoneNumberId <= 0) {
        await _peopleService.createPhoneNumber(
          accessToken,
          personId: personId,
          telefonnummer: telefonnummer,
        );
        continue;
      }

      final remote = remoteById[phoneNumberId];
      if (remote != null && remote == telefonnummer) {
        continue;
      }
      await _peopleService.updatePhoneNumber(
        accessToken,
        telefonnummer: telefonnummer,
      );
    }
  }

  Future<void> _syncAdditionalEmails({
    required String accessToken,
    required int personId,
    required Mitglied remoteMitglied,
    required Mitglied zielMitglied,
  }) async {
    final remoteEmails = remoteMitglied.emailAdressen
        .where((email) => !email.istPrimaer)
        .toList(growable: false);
    final zielEmails = zielMitglied.emailAdressen
        .where((email) => !email.istPrimaer)
        .toList(growable: false);
    final remoteById = <int, MitgliedKontaktEmail>{
      for (final email in remoteEmails)
        if ((email.additionalEmailId ?? 0) > 0) email.additionalEmailId!: email,
    };
    final zielById = <int, MitgliedKontaktEmail>{
      for (final email in zielEmails)
        if ((email.additionalEmailId ?? 0) > 0) email.additionalEmailId!: email,
    };

    for (final entry in remoteById.entries) {
      if (!zielById.containsKey(entry.key)) {
        await _peopleService.deleteAdditionalEmail(
          accessToken,
          additionalEmailId: entry.key,
        );
      }
    }

    for (final email in zielEmails) {
      final additionalEmailId = email.additionalEmailId;
      if (additionalEmailId == null || additionalEmailId <= 0) {
        await _peopleService.createAdditionalEmail(
          accessToken,
          personId: personId,
          email: email,
        );
        continue;
      }

      final remote = remoteById[additionalEmailId];
      if (remote != null && remote == email) {
        continue;
      }
      await _peopleService.updateAdditionalEmail(accessToken, email: email);
    }
  }

  Future<void> _syncAdditionalAddresses({
    required String accessToken,
    required int personId,
    required Mitglied remoteMitglied,
    required Mitglied zielMitglied,
  }) async {
    final remoteAdressen = remoteMitglied.adressen
        .where((adresse) => (adresse.additionalAddressId ?? 0) > 0)
        .toList(growable: false);
    final zielAdressen = zielMitglied.adressen
        .where(
          (adresse) => adresse.additionalAddressId != 0 && !adresse.istLeer,
        )
        .toList(growable: false);
    final remoteById = <int, MitgliedKontaktAdresse>{
      for (final adresse in remoteAdressen)
        if ((adresse.additionalAddressId ?? 0) > 0)
          adresse.additionalAddressId!: adresse,
    };
    final zielById = <int, MitgliedKontaktAdresse>{
      for (final adresse in zielAdressen)
        if ((adresse.additionalAddressId ?? 0) > 0)
          adresse.additionalAddressId!: adresse,
    };

    for (final entry in remoteById.entries) {
      if (!zielById.containsKey(entry.key)) {
        await _peopleService.deleteAdditionalAddress(
          accessToken,
          additionalAddressId: entry.key,
        );
      }
    }

    for (final adresse in zielAdressen) {
      final additionalAddressId = adresse.additionalAddressId;
      if ((additionalAddressId ?? 0) <= 0) {
        if (adresse.istLeer) {
          continue;
        }
        await _peopleService.createAdditionalAddress(
          accessToken,
          personId: personId,
          adresse: adresse.copyWith(additionalAddressIdLoeschen: true),
        );
        continue;
      }

      final remote = remoteById[additionalAddressId!];
      if (remote != null && remote == adresse) {
        continue;
      }
      await _peopleService.updateAdditionalAddress(
        accessToken,
        adresse: adresse,
      );
    }
  }
}
