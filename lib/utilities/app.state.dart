import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nami/screens/app_locked.screen.dart';
import 'package:nami/utilities/hive/hive.handler.dart';
import 'package:nami/utilities/hive/settings.dart';

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
    // twoSideVorhangAnimation(context, animation, secondaryAnimation, child) {
    //       var curvedAnimation = CurvedAnimation(
    //         parent: animation,
    //         curve: Curves.elasticOut,
    //       );

    //       return Stack(
    //         children: <Widget>[
    //           SlideTransition(
    //             position: Tween<Offset>(
    //               begin: Offset(-1.0, 0.0),
    //               end: Offset(-.4, 0.0),
    //             ).animate(curvedAnimation),
    //             child: AppLockedScreen(),
    //           ),
    //           SlideTransition(
    //             position: Tween<Offset>(
    //               begin: Offset(1.0, 0.0),
    //               end: Offset(.4, 0.0),
    //             ).animate(curvedAnimation),
    //             child: AppLockedScreen(),
    //           ),
    //         ],
    //       );
    //     }

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
    // is app password enabled
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
    // show login screen -> main.dart
    currentState = AppState.loggedOut;
  }

  /// App is authenticated | User is logged in
  /// Hive is open
  void setLoadDataState({bool loadAll = false}) {
    if (currentState == AppState.loadData) return;
    // show loading info screen
    // on error -> setLoggedOutState
    // on success -> setReadyState

    // update token
    // update rechte
    // if loadAll
    // -> update gruppierung
    // -> loadAll: update metadata
    // -> loadAll: update mitglieder komplett
    // else
    // -> update mitglieder änderung
    currentState = AppState.loadData;
  }

  /// App is authenticated | User loggin unclear
  /// Hive is open
  Future<void> setAuthenticatedState(BuildContext context) async {
    if (currentState == AppState.authenticated) return;
    await registerAdapter();
    await openHive();

    currentState = AppState.authenticated;

    // TODO: check if data is available -> no, setLoggedOutState

    //login check is older than 30 days
    DateTime thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    if (getLastNamiSync().isBefore(thirtyDaysAgo)) {
      setLoadDataState();
    } else {
      setReadyState();
    }
  }

  /// App is authenticated | User is logged in
  /// Hive is open
  /// Data is available and up to date
  void setReadyState() {
    if (currentState == AppState.ready) return;
    // show AppLoggin Hint when not set
    // show main screen -> main.dart

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
