import 'package:flutter/material.dart';
import 'package:nami/domain/member/member_people_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/member_people_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/member_people_page.dart';
import 'package:nami/presentation/screens/settings_page.dart';
import 'package:nami/presentation/widgets/app_bottom_navigation.dart';
import 'package:provider/provider.dart';

import '../../services/logger_service.dart';

class NavigationHomeScreen extends StatefulWidget {
  const NavigationHomeScreen({super.key});

  @override
  State<NavigationHomeScreen> createState() => _NavigationHomeScreenState();
}

class _NavigationHomeScreenState extends State<NavigationHomeScreen> {
  int _index = 0;
  late final MemberPeopleModel _memberPeopleModel;

  @override
  void initState() {
    super.initState();
    final logger = context.read<LoggerService>();
    final repository = context.read<MemberPeopleRepository>();
    _memberPeopleModel = MemberPeopleModel(
      repository: repository,
      logger: logger,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    Widget body;
    switch (_index) {
      case 0:
        body = Scaffold(
          appBar: AppBar(title: Text(t.t('nav_my_stage'))),
          body: Center(child: Text(t.t('nav_my_stage'))),
        );
        break;
      case 1:
        body = ChangeNotifierProvider<MemberPeopleModel>.value(
          value: _memberPeopleModel,
          child: const MemberPeoplePage(),
        );
        break;
      case 2:
        body = Scaffold(
          appBar: AppBar(title: Text(t.t('nav_statistics'))),
          body: Center(child: Text(t.t('nav_statistics'))),
        );
        break;
      case 3:
        body = SettingsPage(
          onStammSettings: () =>
              Navigator.pushNamed(context, AppRoutes.settingsStamm),
          onAppSettings: () =>
              Navigator.pushNamed(context, AppRoutes.settingsApp),
          onProfile: () => Navigator.pushNamed(context, AppRoutes.profile),
          onDebugTools: () =>
              Navigator.pushNamed(context, AppRoutes.debugTools),
          onNotificationSettings: () =>
              Navigator.pushNamed(context, AppRoutes.settingsNotification),
        );
        break;
      default:
        body = Center(child: Text(t.t('nav_my_stage')));
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
