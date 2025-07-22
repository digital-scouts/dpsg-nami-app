import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nami/presentation/mitglieder/mitglieder.page.dart';
import 'package:nami/presentation/navigation/navigation_cubit.dart';
import 'package:nami/presentation/navigation/navigation_home.widgets.dart';
import 'package:nami/presentation/profile/profile.page.dart';
import 'package:nami/presentation/settings/settings.page.dart';
import 'package:nami/presentation/statistiken/stats.page.dart';
import 'package:nami/presentation/stufe/stufe.page.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/hive/hive_service.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings_service.dart';

class NavigationHomeScreen extends StatelessWidget {
  const NavigationHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NavigationCubit(),
      child: const _NavigationScaffold(),
    );
  }
}

class _NavigationScaffold extends StatelessWidget {
  const _NavigationScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationCubit, NavigationTab>(
      builder: (context, currentTab) {
        return Scaffold(
          appBar: AppBar(title: Text(_titleForTab(currentTab))),
          drawer: _buildDrawer(context, currentTab),
          body: _bodyForTab(currentTab),
        );
      },
    );
  }

  Drawer _buildDrawer(BuildContext context, NavigationTab currentTab) {
    final gruppierungName = settingsService.getGruppierungName();

    Mitglied? user;
    try {
      user = hiveService.getAllMembers().firstWhere(
        (member) => member.mitgliedsNummer == settingsService.getNamiLoginId(),
      );
    } catch (_) {}

    return Drawer(
      child: Column(
        children: <Widget>[
          // Header mit Benutzerinfos
          CustomDrawerHeader(
            userName: '${user?.vorname} ${user?.nachname}',
            gruppierungName: gruppierungName,
            mitgliedsnummer: user?.mitgliedsNummer.toString(),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),

          // Navigation Items
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(0.0),
              children: [
                DrawerItem(
                  icon: Icons.group,
                  label: 'Meine Stufe',
                  tab: NavigationTab.meineStufe,
                  selectedTab: currentTab,
                ),
                DrawerItem(
                  icon: Icons.groups,
                  label: 'Mitglieder',
                  tab: NavigationTab.mitglieder,
                  selectedTab: currentTab,
                ),
                DrawerItem(
                  icon: Icons.analytics,
                  label: 'Statistiken',
                  tab: NavigationTab.stats,
                  selectedTab: currentTab,
                ),
                DrawerItem(
                  icon: Icons.person,
                  label: 'Profil',
                  tab: NavigationTab.profil,
                  selectedTab: currentTab,
                ),
                DrawerItem(
                  icon: Icons.settings,
                  label: 'Einstellungen',
                  tab: NavigationTab.settings,
                  selectedTab: currentTab,
                ),
              ],
            ),
          ),

          // Support Section
          const DrawerSupportSection(),

          // Logout Section
          DrawerLogoutSection(
            onLogoutTap: () {
              AppStateHandler().setLoggedOutState();
            },
          ),
        ],
      ),
    );
  }

  String _titleForTab(NavigationTab tab) {
    switch (tab) {
      case NavigationTab.meineStufe:
        return 'Meine Stufe';
      case NavigationTab.mitglieder:
        return 'Mitglieder';
      case NavigationTab.stats:
        return 'Statistik';
      case NavigationTab.settings:
        return 'Einstellungen';
      case NavigationTab.profil:
        return 'Profil';
    }
  }

  Widget _bodyForTab(NavigationTab tab) {
    switch (tab) {
      case NavigationTab.meineStufe:
        return const StufePage();
      case NavigationTab.mitglieder:
        return const MitgliederPage();
      case NavigationTab.stats:
        return const StatsPage();
      case NavigationTab.settings:
        return const SettingsPage();
      case NavigationTab.profil:
        return const ProfilePage();
    }
  }
}
