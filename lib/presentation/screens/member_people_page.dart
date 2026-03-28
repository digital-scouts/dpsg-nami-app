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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authModel = context.read<AuthSessionModel>();
      await authModel.prepareSessionForRemoteAccess(trigger: 'members_load');
      if (!mounted) {
        return;
      }

      final session = authModel.session;
      await context.read<MemberPeopleModel>().load(
        accessToken: session?.accessToken,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final authModel = context.watch<AuthSessionModel>();

    return Consumer<MemberPeopleModel>(
      builder: (context, peopleModel, _) {
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
