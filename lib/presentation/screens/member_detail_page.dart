import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/maps/address_map_location_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/member/pending_person_update.dart';
import '../../domain/settings/address_settings_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/geoapify_address_map_service.dart';
import '../../services/map_tile_cache_service.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';
import '../model/member_edit_model.dart';
import '../notifications/app_snackbar.dart';
import '../widgets/member_basis.dart';
import 'member_edit_page.dart';

class MemberDetailPage extends StatefulWidget {
  const MemberDetailPage({
    super.key,
    required this.mitglied,
    this.addressLocationRepository,
    this.mapService,
    this.addressSettingsRepository,
    this.tileCacheService,
    this.previewTimeout,
  });

  final Mitglied mitglied;
  final AddressMapLocationRepository? addressLocationRepository;
  final GeoapifyAddressMapService? mapService;
  final AddressSettingsRepository? addressSettingsRepository;
  final MapTileCacheService? tileCacheService;
  final Duration? previewTimeout;

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  bool _isPreparingEdit = false;

  Future<void> _openEditPage(
    Mitglied mitglied, {
    PendingPersonUpdate? pendingEntry,
    String? initialNoticeMessage,
    String? resolutionEntryPoint,
  }) async {
    final result = await Navigator.of(context).push<MemberEditSubmitResult>(
      MaterialPageRoute<MemberEditSubmitResult>(
        builder: (_) => MemberEditPage(
          mitglied: mitglied,
          pendingEntry: pendingEntry,
          initialNoticeMessage: initialNoticeMessage,
          resolutionEntryPoint: resolutionEntryPoint,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }

    final t = AppLocalizations.of(context);
    final message = result.success
        ? t.t('member_detail_updated_success')
        : result.resolveMessage(t);
    if (message != null && message.isNotEmpty) {
      final type = switch (result.notice) {
        MemberEditSubmitNotice.success => AppSnackbarType.success,
        MemberEditSubmitNotice.warning => AppSnackbarType.warning,
        MemberEditSubmitNotice.error => AppSnackbarType.error,
      };
      AppSnackbar.show(context, message: message, type: type);
    }
  }

  Future<void> _prepareAndOpenEditPage(Mitglied mitglied) async {
    if (_isPreparingEdit) {
      return;
    }

    final authModel = context.read<AuthSessionModel?>();
    final memberEditModel = context.read<MemberEditModel?>();
    final pendingEntry = memberEditModel?.pendingForMitglied(
      mitglied.mitgliedsnummer,
    );
    if (pendingEntry?.needsResolution ?? false) {
      await _openEditPage(
        pendingEntry!.zielMitglied,
        pendingEntry: pendingEntry,
        initialNoticeMessage: AppLocalizations.of(
          context,
        ).t('member_detail_resolution_required_notice'),
        resolutionEntryPoint: 'detail',
      );
      return;
    }
    final accessToken = authModel?.session?.accessToken;
    if (memberEditModel == null || accessToken == null || accessToken.isEmpty) {
      _showMessage(
        AppLocalizations.of(context).t('member_detail_session_missing'),
        type: AppSnackbarType.warning,
      );
      return;
    }

    setState(() {
      _isPreparingEdit = true;
    });

    try {
      final result = await memberEditModel.prepareForEdit(
        accessToken: accessToken,
        mitglied: mitglied,
        trigger: 'detail_edit',
      );
      if (!mounted) {
        return;
      }
      final refreshedMember = result.member;
      if (!result.success || refreshedMember == null) {
        _showMessage(
          result.resolveMessage(AppLocalizations.of(context)) ??
              AppLocalizations.of(context).t('member_detail_reload_failed'),
          type: AppSnackbarType.warning,
        );
        return;
      }
      await _openEditPage(
        refreshedMember,
        initialNoticeMessage: result.resolveMessage(
          AppLocalizations.of(context),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingEdit = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
  }) {
    AppSnackbar.show(context, message: message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final currentMitglied = _resolveCurrentMitglied(context);
    final memberEditModel = _maybeWatch<MemberEditModel>(context);
    final arbeitskontextModel = _maybeWatch<ArbeitskontextModel>(context);
    final hasPending =
        memberEditModel?.hasPendingForMitglied(
          currentMitglied.mitgliedsnummer,
        ) ??
        false;
    final pendingEntry = memberEditModel?.pendingForMitglied(
      currentMitglied.mitgliedsnummer,
    );
    final needsResolution = pendingEntry?.needsResolution ?? false;
    final isWritable =
        arbeitskontextModel?.istMitgliedSchreibbar(currentMitglied) ?? false;
    final title = currentMitglied.fullName.trim().isEmpty
        ? currentMitglied.mitgliedsnummer
        : currentMitglied.fullName;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (hasPending)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                needsResolution
                    ? Icons.warning_amber_rounded
                    : Icons.schedule_outlined,
              ),
            ),
          if (isWritable)
            IconButton(
              tooltip: t.t('member_detail_edit_tooltip'),
              onPressed: _isPreparingEdit
                  ? null
                  : () => _prepareAndOpenEditPage(currentMitglied),
              icon: _isPreparingEdit
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          if (hasPending)
            MaterialBanner(
              content: Text(
                needsResolution
                    ? t.t('member_detail_pending_resolution_banner')
                    : t.t('member_detail_pending_retry_banner'),
              ),
              actions: <Widget>[
                if (needsResolution && pendingEntry != null)
                  TextButton(
                    onPressed: () => _openEditPage(
                      pendingEntry.zielMitglied,
                      pendingEntry: pendingEntry,
                      resolutionEntryPoint: 'detail',
                    ),
                    child: Text(t.t('member_detail_resolve_action')),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          Expanded(
            child: MemberDetails(
              mitglied: currentMitglied,
              addressLocationRepository: widget.addressLocationRepository,
              mapService: widget.mapService,
              addressSettingsRepository: widget.addressSettingsRepository,
              tileCacheService: widget.tileCacheService,
              previewTimeout: widget.previewTimeout,
            ),
          ),
        ],
      ),
    );
  }

  Mitglied _resolveCurrentMitglied(BuildContext context) {
    final arbeitskontextModel = _maybeWatch<ArbeitskontextModel>(context);
    return arbeitskontextModel?.readModel?.findeMitglied(
          widget.mitglied.mitgliedsnummer,
        ) ??
        widget.mitglied;
  }

  T? _maybeWatch<T>(BuildContext context) {
    try {
      return context.watch<T>();
    } catch (_) {
      return null;
    }
  }
}
