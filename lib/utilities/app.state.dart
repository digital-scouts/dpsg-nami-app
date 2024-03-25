import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:nami/screens/app_locked_screen.dart';
import 'package:nami/screens/loading_info_screen.dart';
import 'package:nami/utilities/hive/hive.handler.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/nami/nami-login.service.dart';
import 'package:nami/utilities/nami/nami-member.service.dart';
import 'package:nami/utilities/nami/nami.service.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';

class AppStateHandler extends ChangeNotifier {
  static final AppStateHandler _instance = AppStateHandler._internal();
  AppState _currentState = AppState.closed;

  factory AppStateHandler() {
    return _instance;
  }

  AppStateHandler._internal();

  AppState get currentState => _currentState;

  set currentState(AppState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      notifyListeners();
    }
  }

  /// App is locked | User loggin unclear
  /// Hive is closed
  void setClosedState(BuildContext context) {
    if (currentState == AppState.closed) return;
    // lock hive
    closeHive();

    currentState = AppState.closed;
  }

  void setInactiveState(BuildContext context) {
    if (currentState == AppState.inactive) return;

    // push locked screen with door-like transition
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppLockedScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateY((1 - animation.value) * pi / 2),
                alignment: Alignment.centerRight,
                child: child,
              );
            },
            child: child,
          );
        },
      ),
    );

    currentState = AppState.inactive;
  }

  /// App is authenticated | User loggin unclear
  void setResumeState(BuildContext context) {
    if (currentState == AppState.resume) return;
    Navigator.maybePop(context);
    // TODO: is app password enabled
    // -> yes, is user authenticated
    //    -> yes, setAuthenticatedState
    //    -> no, show reset Option -> setLoggedOutState
    // -> no, setAuthenticatedState

    currentState = AppState.resume;
    setAuthenticatedState(context);
  }

  /// App is authenticated | User is locked
  /// Hive is closed
  void setLoggedOutState(BuildContext context) {
    if (currentState == AppState.loggedOut) return;
    // clear AppLoggin | clear hive
    logout();
    currentState = AppState.loggedOut;
  }

  /// App is authenticated | User is logged in
  /// Hive is open
  Future<void> setLoadDataState(BuildContext context,
      {bool loadAll = false}) async {
    if (currentState == AppState.loadData) return;
    ValueNotifier<bool?> loginProgressNotifier = ValueNotifier(null);
    ValueNotifier<List<AllowedFeatures>> rechteProgressNotifier =
        ValueNotifier([]);
    ValueNotifier<String?> gruppierungProgressNotifier = ValueNotifier(null);
    ValueNotifier<bool?> metaProgressNotifier = ValueNotifier(null);
    ValueNotifier<bool?> memberOverviewProgressNotifier = ValueNotifier(null);
    ValueNotifier<double> memberAllProgressNotifier = ValueNotifier(0.0);
    ValueNotifier<bool> statusGreenNotifier = ValueNotifier(true);

    currentState = AppState.loadData;

    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return LoadingInfoScreen(
        loginProgressNotifier: loginProgressNotifier,
        rechteProgressNotifier: rechteProgressNotifier,
        gruppierungProgressNotifier: gruppierungProgressNotifier,
        metaProgressNotifier: metaProgressNotifier,
        memberOverviewProgressNotifier: memberOverviewProgressNotifier,
        memberAllProgressNotifier: memberAllProgressNotifier,
        statusGreenNotifier: statusGreenNotifier,
        loadAll: loadAll,
      );
    })).then((value) {
      if (statusGreenNotifier.value == true) {
        setReadyState();
      } else {
        setLoggedOutState(context);
      }
    });

    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      if (getLastLoginCheck().isAfter(oneHourAgo) || await updateLoginData()) {
        loginProgressNotifier.value = true;
      } else {
        loginProgressNotifier.value = false;
        statusGreenNotifier.value = false;
        debugPrint('Login failed and could not be updated.');
        return;
      }

      if (loadAll) {
        gruppierungProgressNotifier.value = await loadGruppierung();
        await reloadMetadataFromServer();
        metaProgressNotifier.value = true;
        await syncMember(
            memberAllProgressNotifier, memberOverviewProgressNotifier,
            forceUpdate: true);
      } else {
        await syncMember(
            memberAllProgressNotifier, memberOverviewProgressNotifier);
      }
      rechteProgressNotifier.value = await getRechte();
    } catch (e) {
      statusGreenNotifier.value = false;
      debugPrint(e.toString());
    }
  }

  /// App is authenticated | User loggin unclear
  /// Hive is open
  Future<void> setAuthenticatedState(BuildContext context) async {
    if (currentState == AppState.authenticated) return;

    await registerAdapter();
    await openHive();

    currentState = AppState.authenticated;

    // check if data is available -> Logout if not
    List<Mitglied> mitglieder =
        Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    if (mitglieder.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setLoggedOutState(context);
      });
      return;
    }

    // login check or data is older than 30 days -> load data
    if (getLastLoginCheck().isBefore(thirtyDaysAgo) ||
        getLastNamiSync().isBefore(thirtyDaysAgo)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setLoadDataState(context);
      });
      return;
    }

    setReadyState();
  }

  /// App is authenticated | User is logged in
  /// Hive is open
  /// Data is available and up to date
  void setReadyState() {
    if (currentState == AppState.ready) return;
    // show AppLoggin (with biometrics) Hint when not set

    currentState = AppState.ready;
  }
}

enum AppState {
  closed,
  inactive,
  resume,
  loggedOut,
  loadData,
  authenticated,
  ready
}
