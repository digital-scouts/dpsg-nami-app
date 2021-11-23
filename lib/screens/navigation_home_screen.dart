import 'package:flutter/material.dart';
import 'package:nami/screens/dashboard.dart';
import 'package:nami/utilities/app_theme.dart';
import 'package:nami/utilities/custom_drawer/drawer_user_controller.dart';
import 'package:nami/utilities/custom_drawer/home_drawer.dart';

import 'feedback_screen.dart';
import 'help_screen.dart';
import 'invite_friend_screen.dart';

class NavigationHomeScreen extends StatefulWidget {
  const NavigationHomeScreen({Key? key}) : super(key: key);

  @override
  _NavigationHomeScreenState createState() => _NavigationHomeScreenState();
}

class _NavigationHomeScreenState extends State<NavigationHomeScreen> {
  Widget? screenView;
  DrawerIndex? drawerIndex;

  @override
  void initState() {
    drawerIndex = DrawerIndex.home;
    screenView = const DashboardScreen();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.nearlyWhite,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Scaffold(
          backgroundColor: AppTheme.nearlyWhite,
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
      if (drawerIndex == DrawerIndex.home) {
        setState(() {
          screenView = const DashboardScreen();
        });
      } else if (drawerIndex == DrawerIndex.help) {
        setState(() {
          screenView = const HelpScreen();
        });
      } else if (drawerIndex == DrawerIndex.feedback) {
        setState(() {
          screenView = const FeedbackScreen();
        });
      } else if (drawerIndex == DrawerIndex.invite) {
        setState(() {
          screenView = const InviteFriend();
        });
      } else {
        //do in your way......
      }
    }
  }
}
