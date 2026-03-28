import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../model/auth_session_model.dart';
import '../model/member_people_model.dart';

class MemberPeoplePage extends StatefulWidget {
  const MemberPeoplePage({super.key});

  @override
  State<MemberPeoplePage> createState() => _MemberPeoplePageState();
}

class _MemberPeoplePageState extends State<MemberPeoplePage> {
  int? _lastShownRefreshFailureCount;

  @override
  void initState() {
    super.initState();
    _lastShownRefreshFailureCount = context
        .read<MemberPeopleModel>()
        .refreshFailureCount;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authModel = context.read<AuthSessionModel>();
      final session = authModel.session;
      final peopleModel = context.read<MemberPeopleModel>();
      final shouldRefreshRemotely = authModel.isRefreshAttemptDue;
      if (shouldRefreshRemotely) {
        await authModel.markSensitiveDataSyncAttempted();
      }
      await peopleModel.load(
        accessToken: session?.accessToken,
        refreshRemotely: shouldRefreshRemotely,
      );

      if (!mounted) {
        return;
      }

      if (peopleModel.lastRemoteRefreshSucceeded) {
        await authModel.markSensitiveDataSynced();
        authModel.clearRemoteDataIssue();
        return;
      }

      final errorMessage = peopleModel.errorMessage;
      if (errorMessage != null && errorMessage != 'login_required') {
        authModel.reportRemoteDataIssue(
          errorMessage,
          requiresInteractiveLogin: _looksUnauthorized(errorMessage),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final authModel = context.watch<AuthSessionModel>();

    return Consumer<MemberPeopleModel>(
      builder: (context, peopleModel, _) {
        _scheduleIssueSnackbar(context, t, peopleModel);
        return Scaffold(
          appBar: AppBar(title: Text(t.t('nav_members'))),
          body: Column(
            children: [
              if (peopleModel.isRefreshing)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: _buildBody(
                  context,
                  t,
                  authModel: authModel,
                  peopleModel: peopleModel,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _scheduleIssueSnackbar(
    BuildContext context,
    AppLocalizations t,
    MemberPeopleModel peopleModel,
  ) {
    final shownCount = _lastShownRefreshFailureCount ?? 0;
    if (peopleModel.refreshFailureCount <= shownCount) {
      return;
    }

    _lastShownRefreshFailureCount = peopleModel.refreshFailureCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final issueKey = context.read<AuthSessionModel>().requiresInteractiveLogin
          ? 'members_sync_issue_relogin'
          : 'members_sync_issue_cached';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.t(issueKey))));
    });
  }

  bool _looksUnauthorized(String message) {
    return message.contains('(401)') || message.contains('401');
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations t, {
    required AuthSessionModel authModel,
    required MemberPeopleModel peopleModel,
  }) {
    if (peopleModel.isLoading && peopleModel.members.isEmpty) {
      return Center(child: Text(t.t('members_loading')));
    }

    if (peopleModel.members.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: peopleModel.members.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final member = peopleModel.members[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(member.vorname.characters.first.toUpperCase()),
            ),
            title: Text(member.fullName),
          );
        },
      );
    }

    if (authModel.session == null) {
      return Center(child: Text(t.t('members_login_required')));
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          peopleModel.errorMessage != null &&
                  peopleModel.errorMessage != 'login_required'
              ? t.t('members_error')
              : t.t('members_empty'),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
