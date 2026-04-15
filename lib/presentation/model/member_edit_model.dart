import 'package:flutter/foundation.dart';

import '../../domain/member/member_resolution.dart';
import '../../domain/member/member_write_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/member/pending_person_update.dart';
import '../../domain/member/pending_person_update_repository.dart';
import '../../services/logger_service.dart';

enum PendingPersonUpdateRetryDisposition {
  success,
  retained,
  discarded,
  needsResolution,
}

class MemberEditSubmitResult {
  const MemberEditSubmitResult({
    required this.success,
    required this.wasQueued,
    this.requiresResolution = false,
    this.message,
    this.updatedMember,
    this.pendingEntry,
    this.validationErrors = const <MemberWriteFieldValidationError>[],
  });

  final bool success;
  final bool wasQueued;
  final bool requiresResolution;
  final String? message;
  final Mitglied? updatedMember;
  final PendingPersonUpdate? pendingEntry;
  final List<MemberWriteFieldValidationError> validationErrors;
}

class MemberEditPrepareResult {
  const MemberEditPrepareResult({
    required this.success,
    this.member,
    this.message,
  });

  final bool success;
  final Mitglied? member;
  final String? message;
}

class PendingPersonUpdateRetryItemResult {
  const PendingPersonUpdateRetryItemResult({
    required this.entry,
    required this.disposition,
    this.message,
    this.updatedMember,
  });

  final PendingPersonUpdate entry;
  final PendingPersonUpdateRetryDisposition disposition;
  final String? message;
  final Mitglied? updatedMember;
}

class PendingPersonUpdateRetrySummary {
  const PendingPersonUpdateRetrySummary({required this.results});

  final List<PendingPersonUpdateRetryItemResult> results;

  int get successCount => results
      .where(
        (result) =>
            result.disposition == PendingPersonUpdateRetryDisposition.success,
      )
      .length;
  int get discardedCount => results
      .where(
        (result) =>
            result.disposition == PendingPersonUpdateRetryDisposition.discarded,
      )
      .length;
  int get retainedCount => results
      .where(
        (result) =>
            result.disposition == PendingPersonUpdateRetryDisposition.retained,
      )
      .length;
  int get needsResolutionCount => results
      .where(
        (result) =>
            result.disposition ==
            PendingPersonUpdateRetryDisposition.needsResolution,
      )
      .length;
}

class MemberEditModel extends ChangeNotifier {
  MemberEditModel({
    required MemberWriteRepository memberWriteRepository,
    required PendingPersonUpdateRepository pendingRepository,
    required LoggerService logger,
    required Future<void> Function(Mitglied member) onMemberUpdated,
    DateTime Function()? nowProvider,
  }) : _memberWriteRepository = memberWriteRepository,
       _pendingRepository = pendingRepository,
       _logger = logger,
       _onMemberUpdated = onMemberUpdated,
       _now = nowProvider ?? DateTime.now;

  final MemberWriteRepository _memberWriteRepository;
  final PendingPersonUpdateRepository _pendingRepository;
  final LoggerService _logger;
  final Future<void> Function(Mitglied member) _onMemberUpdated;
  final DateTime Function() _now;

  List<PendingPersonUpdate> _pendingUpdates = const <PendingPersonUpdate>[];
  bool _isBusy = false;

  List<PendingPersonUpdate> get pendingUpdates => _pendingUpdates;
  bool get isBusy => _isBusy;

  bool hasPendingForMitglied(String mitgliedsnummer) {
    return _pendingUpdates.any(
      (entry) => entry.mitgliedsnummer == mitgliedsnummer,
    );
  }

  bool hasResolutionForMitglied(String mitgliedsnummer) {
    return _pendingUpdates.any(
      (entry) =>
          entry.mitgliedsnummer == mitgliedsnummer && entry.needsResolution,
    );
  }

  int get openResolutionCount =>
      _pendingUpdates.where((entry) => entry.needsResolution).length;

  PendingPersonUpdate? get firstResolutionEntry {
    for (final entry in _pendingUpdates) {
      if (entry.needsResolution) {
        return entry;
      }
    }
    return null;
  }

  PendingPersonUpdate? pendingForMitglied(String mitgliedsnummer) {
    for (final entry in _pendingUpdates) {
      if (entry.mitgliedsnummer == mitgliedsnummer) {
        return entry;
      }
    }
    return null;
  }

  Future<void> logResolutionOpened({
    required PendingPersonUpdate entry,
    required String entryPoint,
  }) async {
    final resolutionCase = entry.resolutionCase;
    if (resolutionCase == null) {
      return;
    }
    await _logResolutionEvent(
      eventName: 'member_resolution_opened',
      personId: entry.personId,
      properties: <String, Object?>{
        'entry_point': entryPoint,
        ..._resolutionProperties(resolutionCase),
      },
      track: true,
    );
  }

  Future<void> logResolutionChoice({
    required PendingPersonUpdate entry,
    required MemberResolutionItem item,
    required String choice,
  }) async {
    final resolutionCase = entry.resolutionCase;
    if (resolutionCase == null) {
      return;
    }
    await _logResolutionEvent(
      eventName: 'member_resolution_choice',
      personId: entry.personId,
      properties: <String, Object?>{
        'choice': choice,
        'target_type': item.target.type.name,
        'item_cause': _resolutionCauseName(item.effectiveCause),
        'item_problem_type': item.problemType.name,
        ..._resolutionProperties(resolutionCase),
      },
      track: true,
    );
  }

  Future<void> logResolutionHintShown({
    required String entryPoint,
    required int openResolutionCount,
  }) async {
    await _logResolutionEvent(
      eventName: 'member_resolution_hint_shown',
      properties: <String, Object?>{
        'entry_point': entryPoint,
        'open_resolution_count': openResolutionCount,
      },
      track: true,
    );
  }

  Future<void> loadPending() async {
    _pendingUpdates = await _pendingRepository.loadAll();
    notifyListeners();
  }

  Future<MemberEditPrepareResult> prepareForEdit({
    required String accessToken,
    required Mitglied mitglied,
    String trigger = 'detail_edit',
  }) async {
    final pendingEntry = pendingForMitglied(mitglied.mitgliedsnummer);
    if (pendingEntry != null) {
      await _logMemberEditEvent(
        action: 'prepare_result',
        trigger: trigger,
        outcome: pendingEntry.needsResolution
            ? 'needs_resolution'
            : 'local_pending',
        personId: pendingEntry.personId,
        track: true,
      );
      return MemberEditPrepareResult(
        success: true,
        member: pendingEntry.zielMitglied,
        message: pendingEntry.needsResolution
            ? 'Fuer diese Person ist eine Problemloesung noetig, bevor die Aenderung gesendet werden kann.'
            : 'Lokaler Bearbeitungsstand fortgesetzt. Netzabgleich erfolgt spaeter erneut.',
      );
    }

    final personId = mitglied.personId;
    if (personId == null || personId <= 0) {
      return const MemberEditPrepareResult(
        success: false,
        message:
            'Die Person kann ohne gueltige Person-ID nicht bearbeitet werden.',
      );
    }

    _setBusy(true);
    try {
      await _logMemberEditEvent(
        action: 'prepare_started',
        trigger: trigger,
        personId: personId,
      );
      final refreshedMember = await _memberWriteRepository.fetchRemoteMember(
        accessToken: accessToken,
        personId: personId,
      );
      await _onMemberUpdated(refreshedMember);
      await _logMemberEditEvent(
        action: 'prepare_result',
        trigger: trigger,
        outcome: 'succeeded',
        personId: personId,
        track: true,
      );
      return MemberEditPrepareResult(success: true, member: refreshedMember);
    } on MemberWriteUpdatedAtMissingException catch (error) {
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'discarded_missing_updated_at',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'prepare_result',
        trigger: trigger,
        outcome: 'discarded_missing_updated_at',
        personId: personId,
      );
      return MemberEditPrepareResult(success: false, message: error.message);
    } on MemberWriteConflictException catch (error) {
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'discarded_conflict',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'prepare_result',
        trigger: trigger,
        outcome: 'discarded_conflict',
        personId: personId,
      );
      return MemberEditPrepareResult(success: false, message: error.message);
    } on MemberWriteAuthRequiredException catch (error) {
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'auth_required',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'prepare_result',
        trigger: trigger,
        outcome: 'auth_required',
        personId: personId,
      );
      return MemberEditPrepareResult(success: false, message: error.message);
    } on MemberWriteNetworkBlockedException catch (error) {
      await _logMemberEditEvent(
        action: 'prepare_result',
        trigger: trigger,
        outcome: 'network_blocked_local_fallback',
        personId: personId,
        track: true,
      );
      await _logMemberEditEvent(
        action: 'prepare_notice',
        trigger: trigger,
        outcome: 'network_blocked_local_fallback',
        personId: personId,
      );
      return MemberEditPrepareResult(
        success: true,
        member: mitglied,
        message:
            'Bearbeitung erfolgt mit lokal gespeicherten Daten. ${error.message}',
      );
    } on MemberWriteRejectedException catch (error) {
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'discarded_rejected',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'prepare_result',
        trigger: trigger,
        outcome: 'discarded_rejected',
        personId: personId,
      );
      return MemberEditPrepareResult(success: false, message: error.message);
    } on MemberWriteException catch (error) {
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'failed',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'prepare_result',
        trigger: trigger,
        outcome: 'failed',
        personId: personId,
      );
      return MemberEditPrepareResult(success: false, message: error.message);
    } catch (error) {
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'failed',
        message: error.toString(),
      );
      await _logMemberEditEvent(
        action: 'prepare_result',
        trigger: trigger,
        outcome: 'failed',
        personId: personId,
      );
      return const MemberEditPrepareResult(
        success: false,
        message:
            'Die Person konnte nicht neu geladen werden. Bitte erneut versuchen.',
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<MemberEditSubmitResult> submitUpdate({
    required String accessToken,
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
    String trigger = 'manual_edit',
    MemberResolutionCase? existingResolutionCase,
  }) async {
    final personId = zielMitglied.personId ?? basisMitglied.personId;
    if (personId == null || personId <= 0) {
      return const MemberEditSubmitResult(
        success: false,
        wasQueued: false,
        message:
            'Die Person kann ohne gueltige Person-ID nicht bearbeitet werden.',
      );
    }

    _setBusy(true);
    try {
      if (existingResolutionCase != null) {
        await _logResolutionEvent(
          eventName: 'member_resolution_resend_started',
          personId: personId,
          properties: <String, Object?>{
            'trigger': trigger,
            ..._resolutionProperties(existingResolutionCase),
          },
          track: true,
        );
      }
      await _logMemberEditEvent(
        action: 'submit_started',
        trigger: trigger,
        personId: personId,
      );
      final updated = await _memberWriteRepository.updateMember(
        accessToken: accessToken,
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
      );
      await _onMemberUpdated(updated);
      await _removePendingForPerson(personId);
      await _logMemberEditEvent(
        action: 'submit_result',
        trigger: trigger,
        outcome: 'succeeded',
        personId: personId,
        track: true,
      );
      if (existingResolutionCase != null) {
        await _logResolutionEvent(
          eventName: 'member_resolution_resend_result',
          personId: personId,
          properties: <String, Object?>{
            'trigger': trigger,
            'outcome': 'success',
            'remaining_item_count': 0,
            ..._resolutionProperties(existingResolutionCase),
          },
          track: true,
        );
      }
      return MemberEditSubmitResult(
        success: true,
        wasQueued: false,
        updatedMember: updated,
      );
    } on MemberWriteUpdatedAtMissingException catch (error) {
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'discarded_missing_updated_at',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'submit_result',
        trigger: trigger,
        outcome: 'discarded_missing_updated_at',
        personId: personId,
      );
      return MemberEditSubmitResult(
        success: false,
        wasQueued: false,
        message: error.message,
      );
    } on MemberWriteConflictException catch (error) {
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'discarded_conflict',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'submit_result',
        trigger: trigger,
        outcome: 'discarded_conflict',
        personId: personId,
      );
      return MemberEditSubmitResult(
        success: false,
        wasQueued: false,
        message: error.message,
      );
    } on MemberWriteNeedsResolutionException catch (error) {
      final entry = _buildPendingEntry(
        personId: personId,
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
        status: PendingPersonUpdateStatus.needsResolution,
        resolutionCase: MemberResolutionCase(
          remoteMitglied: error.resolutionCase.remoteMitglied,
          items: error.resolutionCase.items,
          source: MemberResolutionSource.manualSave,
        ),
      );
      await _pendingRepository.save(entry);
      await _logResolutionCreated(
        trigger: trigger,
        entry: entry,
        outcome: 'needs_resolution',
      );
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'needs_resolution',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'submit_result',
        trigger: trigger,
        outcome: 'needs_resolution',
        personId: personId,
        track: true,
      );
      if (existingResolutionCase != null) {
        await _logResolutionEvent(
          eventName: 'member_resolution_resend_result',
          personId: personId,
          properties: <String, Object?>{
            'trigger': trigger,
            'outcome': 'still_open',
            'remaining_item_count': entry.resolutionCase?.items.length ?? 0,
            ..._resolutionProperties(entry.resolutionCase),
          },
          track: true,
        );
      }
      await loadPending();
      return MemberEditSubmitResult(
        success: false,
        wasQueued: false,
        requiresResolution: true,
        pendingEntry: entry,
        message: error.message,
      );
    } on MemberWriteAuthRequiredException catch (error) {
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'auth_required',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'submit_result',
        trigger: trigger,
        outcome: 'auth_required',
        personId: personId,
      );
      return MemberEditSubmitResult(
        success: false,
        wasQueued: false,
        message: error.message,
      );
    } on MemberWriteNetworkBlockedException catch (error) {
      final entry = _buildPendingEntry(
        personId: personId,
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
      );
      await _pendingRepository.save(entry);
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'queued_network_blocked',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'submit_result',
        trigger: trigger,
        outcome: 'queued_network_blocked',
        personId: personId,
        track: true,
      );
      if (existingResolutionCase != null) {
        await _logResolutionEvent(
          eventName: 'member_resolution_resend_result',
          personId: personId,
          properties: <String, Object?>{
            'trigger': trigger,
            'outcome': 'queued_network_blocked',
            ..._resolutionProperties(existingResolutionCase),
          },
          track: true,
        );
      }
      await loadPending();
      return MemberEditSubmitResult(
        success: false,
        wasQueued: true,
        pendingEntry: entry,
        message: 'Die Aenderung wurde lokal gespeichert. ${error.message}',
      );
    } on MemberWriteRejectedException catch (error) {
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'discarded_rejected',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'submit_result',
        trigger: trigger,
        outcome: 'discarded_rejected',
        personId: personId,
      );
      return MemberEditSubmitResult(
        success: false,
        wasQueued: false,
        message: error.message,
      );
    } on MemberWriteValidationException catch (error) {
      if (existingResolutionCase != null) {
        final validationCase = _buildValidationResolutionCase(
          zielMitglied: zielMitglied,
          errors: error.errors,
        );
        await _logResolutionEvent(
          eventName: 'member_resolution_resend_result',
          personId: personId,
          properties: <String, Object?>{
            'trigger': trigger,
            'outcome': 'validation_failed',
            'remaining_item_count': validationCase.items.length,
            ..._resolutionProperties(validationCase),
          },
          track: true,
        );
      }
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'discarded_validation',
        message: error.message,
      );
      await _logMemberEditEvent(
        action: 'submit_result',
        trigger: trigger,
        outcome: 'discarded_validation',
        personId: personId,
      );
      return MemberEditSubmitResult(
        success: false,
        wasQueued: false,
        message: error.message,
        validationErrors: error.errors,
      );
    } catch (error) {
      final entry = _buildPendingEntry(
        personId: personId,
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
      );
      await _pendingRepository.save(entry);
      await _logMemberEditFailure(
        trigger: trigger,
        personId: personId,
        outcome: 'queued',
        message: error.toString(),
      );
      await _logMemberEditEvent(
        action: 'submit_result',
        trigger: trigger,
        outcome: 'queued',
        personId: personId,
        track: true,
      );
      if (existingResolutionCase != null) {
        await _logResolutionEvent(
          eventName: 'member_resolution_resend_result',
          personId: personId,
          properties: <String, Object?>{
            'trigger': trigger,
            'outcome': 'queued',
            ..._resolutionProperties(existingResolutionCase),
          },
          track: true,
        );
      }
      await loadPending();
      return MemberEditSubmitResult(
        success: false,
        wasQueued: true,
        pendingEntry: entry,
        message:
            'Die Aenderung konnte nicht direkt gesendet werden und wurde fuer einen spaeteren Retry gespeichert.',
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<PendingPersonUpdateRetrySummary> retryPending({
    required String accessToken,
    Iterable<String>? entryIds,
    String trigger = 'manual_retry',
  }) async {
    final requestedIds = entryIds?.toSet();
    final entries = requestedIds == null
        ? _pendingUpdates.where((entry) => !entry.needsResolution).toList()
        : _pendingUpdates
              .where(
                (entry) =>
                    requestedIds.contains(entry.entryId) &&
                    !entry.needsResolution,
              )
              .toList(growable: false);
    final results = <PendingPersonUpdateRetryItemResult>[];
    if (entries.isEmpty) {
      return const PendingPersonUpdateRetrySummary(
        results: <PendingPersonUpdateRetryItemResult>[],
      );
    }

    _setBusy(true);
    try {
      await _logRetryEvent(
        trigger: trigger,
        action: 'retry_started',
        batchSize: entries.length,
        track: true,
      );
      for (final entry in entries) {
        final attemptedEntry = entry.markAttempted(_now());
        await _pendingRepository.save(attemptedEntry);
        try {
          final updated = await _memberWriteRepository.updateMember(
            accessToken: accessToken,
            basisMitglied: attemptedEntry.basisMitglied,
            zielMitglied: attemptedEntry.zielMitglied,
          );
          await _onMemberUpdated(updated);
          await _pendingRepository.remove(attemptedEntry.entryId);
          results.add(
            PendingPersonUpdateRetryItemResult(
              entry: attemptedEntry,
              disposition: PendingPersonUpdateRetryDisposition.success,
              updatedMember: updated,
            ),
          );
        } on MemberWriteUpdatedAtMissingException catch (error) {
          await _pendingRepository.remove(attemptedEntry.entryId);
          results.add(
            PendingPersonUpdateRetryItemResult(
              entry: attemptedEntry,
              disposition: PendingPersonUpdateRetryDisposition.discarded,
              message: error.message,
            ),
          );
        } on MemberWriteConflictException catch (error) {
          await _pendingRepository.remove(attemptedEntry.entryId);
          results.add(
            PendingPersonUpdateRetryItemResult(
              entry: attemptedEntry,
              disposition: PendingPersonUpdateRetryDisposition.discarded,
              message: error.message,
            ),
          );
        } on MemberWriteNeedsResolutionException catch (error) {
          final resolutionEntry = attemptedEntry.copyWith(
            status: PendingPersonUpdateStatus.needsResolution,
            resolutionCase: MemberResolutionCase(
              remoteMitglied: error.resolutionCase.remoteMitglied,
              items: error.resolutionCase.items,
              source: MemberResolutionSource.pendingRetry,
            ),
          );
          await _pendingRepository.save(resolutionEntry);
          await _logResolutionCreated(
            trigger: trigger,
            entry: resolutionEntry,
            outcome: 'needs_resolution',
          );
          results.add(
            PendingPersonUpdateRetryItemResult(
              entry: resolutionEntry,
              disposition: PendingPersonUpdateRetryDisposition.needsResolution,
              message: error.message,
            ),
          );
        } on MemberWriteAuthRequiredException catch (error) {
          results.add(
            PendingPersonUpdateRetryItemResult(
              entry: attemptedEntry,
              disposition: PendingPersonUpdateRetryDisposition.retained,
              message: error.message,
            ),
          );
        } on MemberWriteValidationException catch (error) {
          final resolutionEntry = attemptedEntry.copyWith(
            status: PendingPersonUpdateStatus.needsResolution,
            resolutionCase: _buildValidationResolutionCase(
              zielMitglied: attemptedEntry.zielMitglied,
              errors: error.errors,
            ),
          );
          await _pendingRepository.save(resolutionEntry);
          await _logResolutionCreated(
            trigger: trigger,
            entry: resolutionEntry,
            outcome: 'validation_needs_resolution',
          );
          results.add(
            PendingPersonUpdateRetryItemResult(
              entry: resolutionEntry,
              disposition: PendingPersonUpdateRetryDisposition.needsResolution,
              message: error.message,
            ),
          );
        } on MemberWriteRejectedException catch (error) {
          await _pendingRepository.remove(attemptedEntry.entryId);
          results.add(
            PendingPersonUpdateRetryItemResult(
              entry: attemptedEntry,
              disposition: PendingPersonUpdateRetryDisposition.discarded,
              message: error.message,
            ),
          );
        } catch (error) {
          results.add(
            PendingPersonUpdateRetryItemResult(
              entry: attemptedEntry,
              disposition: PendingPersonUpdateRetryDisposition.retained,
              message: 'Retry fehlgeschlagen. Der Eintrag bleibt in der Queue.',
            ),
          );
        }
      }
      await loadPending();
      final summary = PendingPersonUpdateRetrySummary(results: results);
      final outcome =
          summary.successCount > 0 &&
              summary.retainedCount == 0 &&
              summary.discardedCount == 0 &&
              summary.needsResolutionCount == 0
          ? 'succeeded'
          : summary.successCount == 0 &&
                summary.retainedCount > 0 &&
                summary.discardedCount == 0 &&
                summary.needsResolutionCount == 0
          ? 'retained'
          : summary.successCount == 0 &&
                summary.retainedCount == 0 &&
                summary.discardedCount == 0 &&
                summary.needsResolutionCount > 0
          ? 'needs_resolution'
          : summary.successCount == 0 &&
                summary.retainedCount == 0 &&
                summary.discardedCount > 0 &&
                summary.needsResolutionCount == 0
          ? 'discarded'
          : 'mixed';
      await _logRetryEvent(
        trigger: trigger,
        action: 'retry_result',
        outcome: outcome,
        successCount: summary.successCount,
        retainedCount: summary.retainedCount,
        discardedCount: summary.discardedCount,
        needsResolutionCount: summary.needsResolutionCount,
        track: true,
      );
      return summary;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _removePendingForPerson(int personId) async {
    final current = await _pendingRepository.loadAll();
    for (final entry in current.where((entry) => entry.personId == personId)) {
      await _pendingRepository.remove(entry.entryId);
    }
    _pendingUpdates = await _pendingRepository.loadAll();
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_isBusy == value) {
      return;
    }
    _isBusy = value;
    notifyListeners();
  }

  Future<void> _logMemberEditEvent({
    required String action,
    required String trigger,
    required int personId,
    String? outcome,
    bool track = false,
  }) async {
    final message = [
      action,
      'trigger=$trigger',
      'person_id=$personId',
      if (outcome != null) 'outcome=$outcome',
    ].join(' ');
    await _logger.logInfo('member_edit', message);
    if (!track) {
      return;
    }
    await _logger.trackEvent('member_edit', <String, Object?>{
      'action': action,
      'trigger': trigger,
      if (outcome != null) 'outcome': outcome,
      'source': 'member_edit',
    });
  }

  Future<void> _logRetryEvent({
    required String trigger,
    required String action,
    String? outcome,
    int? batchSize,
    int? successCount,
    int? retainedCount,
    int? discardedCount,
    int? needsResolutionCount,
    bool track = false,
  }) async {
    final message = [
      action,
      'trigger=$trigger',
      if (batchSize != null) 'batch_size=$batchSize',
      if (outcome != null) 'outcome=$outcome',
      if (successCount != null) 'success_count=$successCount',
      if (retainedCount != null) 'retained_count=$retainedCount',
      if (discardedCount != null) 'discarded_count=$discardedCount',
      if (needsResolutionCount != null)
        'needs_resolution_count=$needsResolutionCount',
    ].join(' ');
    await _logger.logInfo('member_edit', message);
    if (!track) {
      return;
    }
    await _logger.trackEvent('member_edit', <String, Object?>{
      'action': action,
      'trigger': trigger,
      if (batchSize != null) 'batch_size': batchSize,
      if (outcome != null) 'outcome': outcome,
      if (successCount != null) 'success_count': successCount,
      if (retainedCount != null) 'retained_count': retainedCount,
      if (discardedCount != null) 'discarded_count': discardedCount,
      if (needsResolutionCount != null)
        'needs_resolution_count': needsResolutionCount,
      'source': 'member_edit',
    });
  }

  Future<void> _logResolutionCreated({
    required String trigger,
    required PendingPersonUpdate entry,
    required String outcome,
  }) async {
    final resolutionCase = entry.resolutionCase;
    if (resolutionCase == null) {
      return;
    }
    await _logResolutionEvent(
      eventName: 'member_resolution_created',
      personId: entry.personId,
      properties: <String, Object?>{
        'trigger': trigger,
        'outcome': outcome,
        ..._resolutionProperties(resolutionCase),
      },
      track: true,
    );
  }

  Future<void> _logResolutionEvent({
    required String eventName,
    int? personId,
    required Map<String, Object?> properties,
    bool track = false,
  }) async {
    final logProperties = <String, Object?>{
      if (personId != null) 'person_id': personId,
      ...properties,
    };
    await _logger.logInfo(
      'member_resolution',
      _composeTelemetryMessage(eventName, logProperties),
    );
    if (!track) {
      return;
    }
    await _logger.trackEvent(eventName, properties);
  }

  Map<String, Object?> _resolutionProperties(MemberResolutionCase? resolution) {
    if (resolution == null) {
      return const <String, Object?>{};
    }
    final causeCounts = <MemberResolutionCause, int>{};
    final targetTypes = <String>{};
    var conflictCount = 0;
    var validationCount = 0;
    for (final item in resolution.items) {
      targetTypes.add(item.target.type.name);
      causeCounts.update(
        item.effectiveCause,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      switch (item.problemType) {
        case MemberResolutionProblemType.conflict:
          conflictCount++;
        case MemberResolutionProblemType.validation:
          validationCount++;
      }
    }
    return <String, Object?>{
      'resolution_source': resolution.source.name,
      'resolution_category': _resolutionCategoryName(resolution.category),
      'resolution_causes': _joinOrdered(
        resolution.causes.map(_resolutionCauseName),
      ),
      'item_count': resolution.items.length,
      'conflict_count': conflictCount,
      'validation_count': validationCount,
      'non_merge_count': resolution.items
          .where(
            (item) =>
                item.effectiveCause != MemberResolutionCause.overlappingChange,
          )
          .length,
      'address_validation_count':
          causeCounts[MemberResolutionCause.addressValidation] ?? 0,
      'server_validation_count':
          causeCounts[MemberResolutionCause.serverValidation] ?? 0,
      'target_types': _joinOrdered(targetTypes),
    };
  }

  String _composeTelemetryMessage(
    String eventName,
    Map<String, Object?> properties,
  ) {
    final details = properties.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    return details.isEmpty ? eventName : '$eventName $details';
  }

  String _joinOrdered(Iterable<String> values) {
    final sorted = values.toSet().toList(growable: false)..sort();
    return sorted.join(',');
  }

  String _resolutionCategoryName(MemberResolutionCategory category) {
    return switch (category) {
      MemberResolutionCategory.mergeConflict => 'merge_conflict',
      MemberResolutionCategory.nonMergeProblem => 'non_merge_problem',
      MemberResolutionCategory.mixed => 'mixed',
    };
  }

  String _resolutionCauseName(MemberResolutionCause cause) {
    return switch (cause) {
      MemberResolutionCause.overlappingChange => 'overlapping_change',
      MemberResolutionCause.serverValidation => 'server_validation',
      MemberResolutionCause.addressValidation => 'address_validation',
      MemberResolutionCause.remoteDeletedLocalEdited =>
        'remote_deleted_local_edited',
      MemberResolutionCause.unknown => 'unknown',
    };
  }

  PendingPersonUpdate _buildPendingEntry({
    required int personId,
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
    PendingPersonUpdateStatus status = PendingPersonUpdateStatus.queued,
    MemberResolutionCase? resolutionCase,
  }) {
    return PendingPersonUpdate(
      entryId: 'person-$personId',
      personId: personId,
      mitgliedsnummer: zielMitglied.mitgliedsnummer,
      displayName: zielMitglied.fullName.isEmpty
          ? zielMitglied.mitgliedsnummer
          : zielMitglied.fullName,
      basisMitglied: basisMitglied,
      zielMitglied: zielMitglied,
      queuedAt: _now(),
      status: status,
      resolutionCase: resolutionCase,
    );
  }

  MemberResolutionCase _buildValidationResolutionCase({
    required Mitglied zielMitglied,
    required List<MemberWriteFieldValidationError> errors,
  }) {
    return MemberResolutionCase(
      remoteMitglied: zielMitglied,
      source: MemberResolutionSource.pendingRetry,
      items: errors
          .map(
            (error) => MemberResolutionItem(
              problemType: MemberResolutionProblemType.validation,
              target: _mapValidationTarget(error),
              message: error.message,
              code: error.code,
            ),
          )
          .toList(growable: false),
    );
  }

  MemberResolutionTarget _mapValidationTarget(
    MemberWriteFieldValidationError error,
  ) {
    if (error.relationshipName == 'phone_numbers') {
      return MemberResolutionTarget(
        type: MemberResolutionTargetType.phone,
        relationshipId: error.relationshipId,
      );
    }
    if (error.relationshipName == 'additional_emails') {
      return MemberResolutionTarget(
        type: MemberResolutionTargetType.additionalEmail,
        relationshipId: error.relationshipId,
      );
    }
    if (error.relationshipName == 'additional_addresses') {
      return MemberResolutionTarget(
        type: MemberResolutionTargetType.additionalAddress,
        relationshipId: error.relationshipId,
      );
    }
    switch (error.effectiveAttribute) {
      case 'first_name':
        return const MemberResolutionTarget(
          type: MemberResolutionTargetType.firstName,
        );
      case 'last_name':
        return const MemberResolutionTarget(
          type: MemberResolutionTargetType.lastName,
        );
      case 'nickname':
        return const MemberResolutionTarget(
          type: MemberResolutionTargetType.nickname,
        );
      case 'gender':
        return const MemberResolutionTarget(
          type: MemberResolutionTargetType.gender,
        );
      case 'birthday':
        return const MemberResolutionTarget(
          type: MemberResolutionTargetType.birthday,
        );
      case 'email':
        return const MemberResolutionTarget(
          type: MemberResolutionTargetType.primaryEmail,
        );
      case 'street':
      case 'housenumber':
      case 'postbox':
      case 'zip_code':
      case 'town':
      case 'country':
      case 'address_care_of':
        return const MemberResolutionTarget(
          type: MemberResolutionTargetType.primaryAddress,
        );
      default:
        return const MemberResolutionTarget(
          type: MemberResolutionTargetType.firstName,
        );
    }
  }

  Future<void> _logMemberEditFailure({
    required String trigger,
    required int personId,
    required String outcome,
    required String message,
  }) async {
    final compactMessage = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    await _logger.logWarn(
      'member_edit',
      'submit_failure trigger=$trigger person_id=$personId outcome=$outcome detail="$compactMessage"',
    );
  }
}
