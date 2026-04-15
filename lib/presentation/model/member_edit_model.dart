import 'package:flutter/foundation.dart';

import '../../domain/member/member_write_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/member/pending_person_update.dart';
import '../../domain/member/pending_person_update_repository.dart';
import '../../services/logger_service.dart';

enum PendingPersonUpdateRetryDisposition { success, retained, discarded }

class MemberEditSubmitResult {
  const MemberEditSubmitResult({
    required this.success,
    required this.wasQueued,
    this.message,
    this.updatedMember,
    this.pendingEntry,
  });

  final bool success;
  final bool wasQueued;
  final String? message;
  final Mitglied? updatedMember;
  final PendingPersonUpdate? pendingEntry;
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

  PendingPersonUpdate? pendingForMitglied(String mitgliedsnummer) {
    for (final entry in _pendingUpdates) {
      if (entry.mitgliedsnummer == mitgliedsnummer) {
        return entry;
      }
    }
    return null;
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
        outcome: 'local_pending',
        personId: pendingEntry.personId,
        track: true,
      );
      return MemberEditPrepareResult(
        success: true,
        member: pendingEntry.zielMitglied,
        message:
            'Lokaler Bearbeitungsstand fortgesetzt. Netzabgleich erfolgt spaeter erneut.',
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
      final entry = PendingPersonUpdate(
        entryId: 'person-$personId',
        personId: personId,
        mitgliedsnummer: zielMitglied.mitgliedsnummer,
        displayName: zielMitglied.fullName.isEmpty
            ? zielMitglied.mitgliedsnummer
            : zielMitglied.fullName,
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
        queuedAt: _now(),
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
    } catch (error) {
      final entry = PendingPersonUpdate(
        entryId: 'person-$personId',
        personId: personId,
        mitgliedsnummer: zielMitglied.mitgliedsnummer,
        displayName: zielMitglied.fullName.isEmpty
            ? zielMitglied.mitgliedsnummer
            : zielMitglied.fullName,
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
        queuedAt: _now(),
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
        ? _pendingUpdates
        : _pendingUpdates
              .where((entry) => requestedIds.contains(entry.entryId))
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
        } on MemberWriteAuthRequiredException catch (error) {
          results.add(
            PendingPersonUpdateRetryItemResult(
              entry: attemptedEntry,
              disposition: PendingPersonUpdateRetryDisposition.retained,
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
              summary.discardedCount == 0
          ? 'succeeded'
          : summary.successCount == 0 &&
                summary.retainedCount > 0 &&
                summary.discardedCount == 0
          ? 'retained'
          : summary.successCount == 0 &&
                summary.retainedCount == 0 &&
                summary.discardedCount > 0
          ? 'discarded'
          : 'mixed';
      await _logRetryEvent(
        trigger: trigger,
        action: 'retry_result',
        outcome: outcome,
        successCount: summary.successCount,
        retainedCount: summary.retainedCount,
        discardedCount: summary.discardedCount,
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
      'source': 'member_edit',
    });
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
