import 'package:flutter/material.dart';
import 'package:nami/screens/dashboard/dashboard.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_liste.dart';
import 'package:nami/screens/profil/profil.dart';
import 'package:nami/screens/settings/settings.dart';
import 'package:nami/screens/statistiken/statistiken_sceen.dart';
import 'package:nami/utilities/custom_drawer/drawer_user_controller.dart';
import 'package:nami/utilities/custom_drawer/home_drawer.dart';

class NavigationHomeScreen extends StatefulWidget {
  const NavigationHomeScreen({Key? key}) : super(key: key);

  @override
  NavigationHomeScreenState createState() => NavigationHomeScreenState();
}

class NavigationHomeScreenState extends State<NavigationHomeScreen> {
  Widget? screenView;
  DrawerIndex? drawerIndex;

  @override
  void initState() {
    drawerIndex = DrawerIndex.mitglieder;
    screenView = const MitgliedsListe();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.background,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          body: DrawerUserController(
            screenIndex: drawerIndex,
            drawerWidth: MediaQuery.of(context).size.width * 0.75,
            onDrawerCall: (DrawerIndex drawerIndexdata) {
              changeIndex(drawerIndexdata);
              //callback from drawer for replace screen as user need with passing DrawerIndex(Enum index)
            },
            screenView: screenView,
            //we replace screen view as we need on navigate starting screens like MyHomePage, HelpScreen, FeedbackScreen, etc...
          ),
        ),
      ),
    );
  }

  void changeIndex(DrawerIndex drawerIndexdata) {
    if (drawerIndex != drawerIndexdata) {
      drawerIndex = drawerIndexdata;
      if (drawerIndex == DrawerIndex.mitglieder) {
        setState(() {
          screenView = const MitgliedsListe();
        });
      } else if (drawerIndex == DrawerIndex.stats) {
        setState(() {
          screenView = const StatistikScreen();
        });
      } else if (drawerIndex == DrawerIndex.settings) {
        setState(() {
          screenView = const Settings();
        });
      } else if (drawerIndex == DrawerIndex.dashboard) {
        setState(() {
          screenView = const Dashboard();
        });
      } else if (drawerIndex == DrawerIndex.profil) {
        setState(() {
          screenView = const Profil();
        });
      } else {
        // Hier alle weiteren Naviagtionspunkte des Seitenmenüs definieren
      }
    }
  }
}
