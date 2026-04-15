import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/maps/address_map_location_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/settings/address_settings_repository.dart';
import '../../services/geoapify_address_map_service.dart';
import '../../services/map_tile_cache_service.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';
import '../model/member_edit_model.dart';
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
    String? initialNoticeMessage,
  }) async {
    final result = await Navigator.of(context).push<MemberEditSubmitResult>(
      MaterialPageRoute<MemberEditSubmitResult>(
        builder: (_) => MemberEditPage(
          mitglied: mitglied,
          initialNoticeMessage: initialNoticeMessage,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }

    final message = result.success
        ? 'Person erfolgreich aktualisiert.'
        : result.message;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _prepareAndOpenEditPage(Mitglied mitglied) async {
    if (_isPreparingEdit) {
      return;
    }

    final authModel = context.read<AuthSessionModel?>();
    final memberEditModel = context.read<MemberEditModel?>();
    final accessToken = authModel?.session?.accessToken;
    if (memberEditModel == null || accessToken == null || accessToken.isEmpty) {
      _showMessage(
        'Aktuell ist keine gueltige Sitzung zum Bearbeiten verfuegbar.',
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
          result.message ??
              'Die Person konnte nicht neu geladen werden. Bitte erneut versuchen.',
        );
        return;
      }
      await _openEditPage(
        refreshedMember,
        initialNoticeMessage: result.message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingEdit = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final isWritable =
        arbeitskontextModel?.istMitgliedSchreibbar(currentMitglied) ?? false;
    final title = currentMitglied.fullName.trim().isEmpty
        ? currentMitglied.mitgliedsnummer
        : currentMitglied.fullName;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (hasPending)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.schedule_outlined),
            ),
          if (isWritable)
            IconButton(
              tooltip: 'Person bearbeiten',
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
              content: const Text(
                'Für diese Person liegt eine ausstehende Änderung vor. Ein Retry ist in den Debug-Tools möglich.',
              ),
              actions: const <Widget>[SizedBox.shrink()],
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
