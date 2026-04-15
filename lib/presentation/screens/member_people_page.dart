import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/member/member_list_preferences.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/member_filters/usecases/ermittle_member_filter_treffer_usecase.dart';
import '../../domain/stufe/usecases/ermittle_stufen_im_arbeitskontext_usecase.dart';
import '../../domain/taetigkeit/stufe.dart';
import '../../l10n/app_localizations.dart';
import '../model/app_settings_model.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';
import '../model/member_edit_model.dart';
import '../model/member_filters_model.dart';
import '../navigation/app_router.dart';
import '../notifications/app_snackbar.dart';
import '../widgets/member_filter_sort_sheet.dart';
import '../widgets/member_list_directory.dart';
import 'member_detail_page.dart';

class MemberPeoplePage extends StatefulWidget {
  const MemberPeoplePage({super.key});

  @override
  State<MemberPeoplePage> createState() => _MemberPeoplePageState();
}

class _MemberPeoplePageState extends State<MemberPeoplePage> {
  static const String _biberGruppenTyp = 'Group::Biber';
  static const ErmittleStufenImArbeitskontextUseCase
  _ermittleStufenImArbeitskontextUseCase =
      ErmittleStufenImArbeitskontextUseCase();
  static const ErmittleMemberFilterTrefferUseCase
  _ermittleMemberFilterTrefferUseCase = ErmittleMemberFilterTrefferUseCase();

  String? _lastShownIssueKey;
  String? _lastShownResolutionKey;
  int? _lastMemberFiltersLayerId;

  Mitglied? _findMemberById(List<Mitglied> members, String memberId) {
    for (final member in members) {
      if (member.mitgliedsnummer == memberId) {
        return member;
      }
    }

    return null;
  }

  Future<void> _openMemberDetails(BuildContext context, Mitglied member) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: AppRoutes.memberDetail,
          arguments: member.mitgliedsnummer,
        ),
        builder: (_) => MemberDetailPage(mitglied: member),
      ),
    );
  }

  String? _buildPrimaryGroupRole(
    Mitglied member,
    ArbeitskontextModel arbeitskontextModel,
  ) {
    final readModel = arbeitskontextModel.readModel;
    if (readModel == null) {
      return null;
    }

    final zuordnungen = readModel.findeMitgliedsZuordnungen(
      member.mitgliedsnummer,
    );
    if (zuordnungen.isEmpty) {
      return null;
    }

    final ersteZuordnung = zuordnungen.first;
    final gruppe = readModel.findeGruppe(ersteZuordnung.gruppenId);
    if (gruppe == null) {
      return null;
    }

    final rollenLabel = ersteZuordnung.displayRollenLabel;
    if (rollenLabel == null || rollenLabel.isEmpty) {
      return gruppe.anzeigename;
    }

    return '${gruppe.anzeigename} - $rollenLabel';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final authModel = context.watch<AuthSessionModel>();
    final arbeitskontextModel = context.watch<ArbeitskontextModel>();
    final memberEditModel = context.watch<MemberEditModel?>();
    final appSettingsModel = context.watch<AppSettingsModel?>();
    final memberFiltersModel = context.watch<MemberFiltersModel?>();
    final highlightSearchMatches =
        appSettingsModel?.memberListSearchResultHighlightEnabled ?? false;
    final layerId =
        arbeitskontextModel.readModel?.arbeitskontext.aktiverLayer.id;
    _ensureMemberFiltersLoaded(memberFiltersModel, layerId);
    final showBiberFilter = _hatMitgliedInGruppenTyp(
      arbeitskontextModel,
      _biberGruppenTyp,
    );
    final mitgliedsStufen = arbeitskontextModel.readModel == null
        ? const <String, Set<Stufe>>{}
        : _ermittleStufenImArbeitskontextUseCase(
            arbeitskontextModel.readModel!,
          );
    final mitgliedsFilterKeys = arbeitskontextModel.readModel == null
        ? const <String, Set<String>>{}
        : _ermittleMemberFilterTrefferUseCase(
            arbeitskontextModel.readModel!,
            customGroups: memberFiltersModel?.customGroups ?? const [],
          );
    final members =
        arbeitskontextModel.readModel?.mitglieder ?? const <Mitglied>[];
    final sortKey = memberFiltersModel?.sortKey ?? MemberSortKey.name;
    final subtitleMode =
        memberFiltersModel?.subtitleMode ?? MemberSubtitleMode.mitgliedsnummer;

    _scheduleIssueSnackbar(context, t, authModel);
    _scheduleResolutionSnackbar(context, memberEditModel);

    return Column(
      children: [
        if (authModel.isSyncingHitobitoData || arbeitskontextModel.isLoading)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _buildBody(
            context,
            t,
            authModel: authModel,
            arbeitskontextModel: arbeitskontextModel,
            highlightSearchMatches: highlightSearchMatches,
            showBiberFilter: showBiberFilter,
            mitgliedsStufen: mitgliedsStufen,
            mitgliedsFilterKeys: mitgliedsFilterKeys,
            memberFiltersModel: memberFiltersModel,
            sortKey: sortKey,
            subtitleMode: subtitleMode,
            members: members,
            memberEditModel: memberEditModel,
          ),
        ),
      ],
    );
  }

  void _ensureMemberFiltersLoaded(MemberFiltersModel? model, int? layerId) {
    if (model == null ||
        layerId == null ||
        _lastMemberFiltersLayerId == layerId) {
      return;
    }
    _lastMemberFiltersLayerId = layerId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      model.ensureLoadedForLayer(layerId);
    });
  }

  void _scheduleIssueSnackbar(
    BuildContext context,
    AppLocalizations t,
    AuthSessionModel authModel,
  ) {
    final issueMessage = authModel.remoteAccessIssueMessage;
    if (issueMessage == null || issueMessage.isEmpty) {
      return;
    }

    final issueKey = '${authModel.requiresInteractiveLogin}|$issueMessage';
    if (_lastShownIssueKey == issueKey) {
      return;
    }

    _lastShownIssueKey = issueKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final snackbarKey =
          context.read<AuthSessionModel>().requiresInteractiveLogin
          ? 'members_sync_issue_relogin'
          : 'members_sync_issue_cached';
      AppSnackbar.show(
        context,
        message: t.t(snackbarKey),
        type: AppSnackbarType.warning,
        replaceCurrent: true,
      );
    });
  }

  void _scheduleResolutionSnackbar(
    BuildContext context,
    MemberEditModel? memberEditModel,
  ) {
    final resolutionCount = memberEditModel?.openResolutionCount ?? 0;
    if (resolutionCount <= 0) {
      _lastShownResolutionKey = null;
      return;
    }

    final issueKey = 'resolution:$resolutionCount';
    if (_lastShownResolutionKey == issueKey) {
      return;
    }

    _lastShownResolutionKey = issueKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      memberEditModel?.logResolutionHintShown(
        entryPoint: 'people_list',
        openResolutionCount: resolutionCount,
      );

      AppSnackbar.show(
        context,
        message:
            'Es gibt $resolutionCount offene Problemfaelle bei Mitglieds-Aenderungen.',
        type: AppSnackbarType.warning,
        replaceCurrent: true,
      );
    });
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations t, {
    required AuthSessionModel authModel,
    required ArbeitskontextModel arbeitskontextModel,
    required bool highlightSearchMatches,
    required bool showBiberFilter,
    required Map<String, Set<Stufe>> mitgliedsStufen,
    required Map<String, Set<String>> mitgliedsFilterKeys,
    required MemberFiltersModel? memberFiltersModel,
    required MemberSortKey sortKey,
    required MemberSubtitleMode subtitleMode,
    required List<Mitglied> members,
    required MemberEditModel? memberEditModel,
  }) {
    if ((arbeitskontextModel.isLoading || authModel.isSyncingHitobitoData) &&
        members.isEmpty) {
      return Center(child: Text(t.t('members_loading')));
    }

    if (members.isNotEmpty) {
      return MemberDirectory(
        mitglieder: members,
        sortKey: sortKey,
        subtitleMode: subtitleMode,
        highlightSearchMatches: highlightSearchMatches,
        warningBuilder: (member) =>
            memberEditModel?.hasResolutionForMitglied(member.mitgliedsnummer) ??
            false,
        trailingTextBuilder: (member) =>
            _buildPrimaryGroupRole(member, arbeitskontextModel),
        mitgliedsFilterKeys: mitgliedsFilterKeys,
        customFilterGroups: memberFiltersModel?.customGroups ?? const [],
        showBiberFilter: showBiberFilter,
        enableGroupFilter: true,
        onOpenFilterOptions:
            memberFiltersModel == null || arbeitskontextModel.readModel == null
            ? null
            : () {
                showMemberFilterSortSheet(
                  context,
                  model: memberFiltersModel,
                  readModel: arbeitskontextModel.readModel!,
                );
              },
        onTapMember: (memberId) {
          final selectedMember = _findMemberById(members, memberId);
          if (selectedMember == null) {
            return;
          }
          _openMemberDetails(context, selectedMember);
        },
      );
    }

    if (authModel.session == null) {
      return Center(child: Text(t.t('members_login_required')));
    }

    if (arbeitskontextModel.hasError || authModel.hasRemoteAccessIssue) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.t('members_error'), textAlign: TextAlign.center),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(t.t('members_empty'), textAlign: TextAlign.center),
      ),
    );
  }

  bool _hatMitgliedInGruppenTyp(
    ArbeitskontextModel arbeitskontextModel,
    String gruppenTyp,
  ) {
    final readModel = arbeitskontextModel.readModel;
    if (readModel == null) {
      return false;
    }

    for (final zuordnung in readModel.mitgliedsZuordnungen) {
      final gruppe = readModel.findeGruppe(zuordnung.gruppenId);
      if (gruppe?.gruppenTyp == gruppenTyp) {
        return true;
      }
    }

    return false;
  }
}
