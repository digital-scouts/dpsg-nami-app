import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/member/mitglied.dart';
import '../../l10n/app_localizations.dart';
import '../model/app_settings_model.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';
import '../widgets/member_list.dart';
import '../widgets/member_list_directory.dart';
import '../widgets/member_list_tile.dart';
import 'member_detail_page.dart';

class MemberPeoplePage extends StatefulWidget {
  const MemberPeoplePage({super.key});

  @override
  State<MemberPeoplePage> createState() => _MemberPeoplePageState();
}

class _MemberPeoplePageState extends State<MemberPeoplePage> {
  String? _lastShownIssueKey;

  // TODO: Arbeitskontext liefert aktuell reduzierte People-List-Mitglieder; fuer alle Subtitle-Modi bei Bedarf auf ein vollstaendigeres Mitglied-Modell umstellen.
  static const MemberSubtitleMode _subtitleMode =
      MemberSubtitleMode.mitgliedsnummer;

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
      return gruppe.name;
    }

    return '${gruppe.name} - $rollenLabel';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final authModel = context.watch<AuthSessionModel>();
    final arbeitskontextModel = context.watch<ArbeitskontextModel>();
    final appSettingsModel = context.watch<AppSettingsModel?>();
    final highlightSearchMatches =
        appSettingsModel?.memberListSearchResultHighlightEnabled ?? false;
    final members =
        arbeitskontextModel.readModel?.mitglieder ?? const <Mitglied>[];

    _scheduleIssueSnackbar(context, t, authModel);

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
            members: members,
          ),
        ),
      ],
    );
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.t(snackbarKey))));
    });
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations t, {
    required AuthSessionModel authModel,
    required ArbeitskontextModel arbeitskontextModel,
    required bool highlightSearchMatches,
    required List<Mitglied> members,
  }) {
    if ((arbeitskontextModel.isLoading || authModel.isSyncingHitobitoData) &&
        members.isEmpty) {
      return Center(child: Text(t.t('members_loading')));
    }

    if (members.isNotEmpty) {
      return MemberDirectory(
        mitglieder: members,
        sortKey: MemberSortKey.name,
        subtitleMode: _subtitleMode,
        highlightSearchMatches: highlightSearchMatches,
        trailingTextBuilder: (member) =>
            _buildPrimaryGroupRole(member, arbeitskontextModel),
        enableGroupFilter: false,
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
}
