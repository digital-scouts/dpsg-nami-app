import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/member/mitglied.dart';
import '../../l10n/app_localizations.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';

class MemberPeoplePage extends StatefulWidget {
  const MemberPeoplePage({super.key});

  @override
  State<MemberPeoplePage> createState() => _MemberPeoplePageState();
}

class _MemberPeoplePageState extends State<MemberPeoplePage> {
  String? _lastShownIssueKey;

  String _buildAvatarLabel(Mitglied member) {
    final trimmedVorname = member.vorname.trim();
    if (trimmedVorname.isNotEmpty) {
      return trimmedVorname.characters.first.toUpperCase();
    }

    final trimmedNachname = member.nachname.trim();
    if (trimmedNachname.isNotEmpty) {
      return trimmedNachname.characters.first.toUpperCase();
    }

    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final authModel = context.watch<AuthSessionModel>();
    final arbeitskontextModel = context.watch<ArbeitskontextModel>();
    final members =
        arbeitskontextModel.readModel?.mitglieder ?? const <Mitglied>[];

    _scheduleIssueSnackbar(context, t, authModel);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('nav_members'))),
      body: Column(
        children: [
          if (authModel.isSyncingHitobitoData || arbeitskontextModel.isLoading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _buildBody(
              context,
              t,
              authModel: authModel,
              arbeitskontextModel: arbeitskontextModel,
              members: members,
            ),
          ),
        ],
      ),
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
    required List<Mitglied> members,
  }) {
    if ((arbeitskontextModel.isLoading || authModel.isSyncingHitobitoData) &&
        members.isEmpty) {
      return Center(child: Text(t.t('members_loading')));
    }

    if (members.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: members.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final member = members[index];
          return ListTile(
            leading: CircleAvatar(child: Text(_buildAvatarLabel(member))),
            title: Text(member.fullName),
          );
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
