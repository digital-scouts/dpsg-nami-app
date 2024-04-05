import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nami/main.dart';
import 'package:nami/screens/loading_info_screen.dart';
import 'package:nami/screens/login_screen.dart';
import 'package:nami/utilities/hive/hive.handler.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/nami-member.service.dart';
import 'package:nami/utilities/nami/nami.service.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'package:nami/utilities/notifications.dart';
import 'package:nami/utilities/types.dart';

class AppStateHandler extends ChangeNotifier {
  static final AppStateHandler _instance = AppStateHandler._internal();
  AppState _currentState = AppState.closed;
  SyncState _syncRunning = SyncState.notStarted;
  Timer? syncTimer;

  factory AppStateHandler() {
    return _instance;
  }

  AppStateHandler._internal();

  AppState get currentState => _currentState;

  set currentState(AppState newState) {
    if (_currentState != newState) {
      sensLog.i("AppStateHandler: $newState");
      _currentState = newState;
      notifyListeners();
    }
  }

  SyncState get syncState => _syncRunning;

  set syncState(SyncState newState) {
    if (_syncRunning != newState) {
      sensLog.i("SyncState: $newState");
      _syncRunning = newState;
      notifyListeners();
    }
  }

  /// App is authenticated | User loggin unclear
  void setResumeState(BuildContext context) async {
    /// Prevent changing state while relogin when app comes from background
    if (currentState == AppState.relogin) {
      return;
    }
    sensLog.i("in ResumeState");
    // TODO: is app password enabled
    // -> yes, is user authenticated
    //    -> yes, setAuthenticatedState
    //    -> no, show reset Option -> setLoggedOutState
    // -> no, setAuthenticatedState

    await registerAdapter();
    await openHive();
    if (getNamiApiCookie().isNotEmpty) {
      // ignore: use_build_context_synchronously
      setAuthenticatedState();
    } else {
      setLoggedOutState();
    }
  }

  /// App is authenticated | User is logged out
  void setLoggedOutState() {
    if (currentState == AppState.loggedOut) return;
    syncTimer?.cancel();
    // clear AppLoggin | clear hive
    logout();
    currentState = AppState.loggedOut;
  }

  bool isTooLongOffline() {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final tooLongOffline = getLastLoginCheck().isBefore(thirtyDaysAgo) ||
        getLastNamiSync().isBefore(thirtyDaysAgo);
    return tooLongOffline;
  }

  void showTooLongOfflineNotification() {
    showSnackBar(navigatorKey.currentContext!,
        "Du warst zu lange offline. Bitte melde dich erneut an.");
  }

  /// Returns true when relogin was successful
  ///
  /// See [AppState.relogin] for more information
  Future<bool> setReloginState() async {
    sensLog.i('Start relogin');
    var showLogin = true;
    final tooLongOffline = isTooLongOffline();
    if (tooLongOffline) {
      sensLog.i('too long offline, show too long offline notification');
      showTooLongOfflineNotification();
    } else {
      showLogin = await showConfirmationDialog(
        "Sitzung abgelaufen",
        "Deine Sitzung ist abgelaufen. Bitte melden dich erneut an.",
      );
    }
    if (showLogin) {
      currentState = AppState.relogin;
      sensLog.i('show login screen');
      final reloginSuccessful = await navigatorKey.currentState!.push<bool?>(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      setReadyState();
      return reloginSuccessful ?? false;
    } else {
      sensLog.i('relogin canceled');
      return false;
    }
  }

  /// App is authenticated | User is logged in
  Future<void> setLoadDataState({
    bool loadAll = false,
    background = false,
  }) async {
    sensLog.i(
        'Start loading data with loadAll: $loadAll and background: $background');
    ValueNotifier<List<AllowedFeatures>> rechteProgressNotifier =
        ValueNotifier([]);
    ValueNotifier<String?> gruppierungProgressNotifier = ValueNotifier(null);
    ValueNotifier<bool?> metaProgressNotifier = ValueNotifier(null);
    ValueNotifier<bool?> memberOverviewProgressNotifier = ValueNotifier(null);
    ValueNotifier<double> memberAllProgressNotifier = ValueNotifier(0.0);

    syncState = SyncState.loading;
    if (background) {
      showSnackBar(navigatorKey.currentContext!, "Daten werden synchronisiert");
    } else {
      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (context) {
          return LoadingInfoScreen(
            rechteProgressNotifier: rechteProgressNotifier,
            gruppierungProgressNotifier: gruppierungProgressNotifier,
            metaProgressNotifier: metaProgressNotifier,
            memberOverviewProgressNotifier: memberOverviewProgressNotifier,
            memberAllProgressNotifier: memberAllProgressNotifier,
            loadAll: loadAll,
          );
        }),
      );
    }

    try {
      if (loadAll) {
        gruppierungProgressNotifier.value = await loadGruppierung();
        await reloadMetadataFromServer();
        metaProgressNotifier.value = true;
      }
      await syncMember(
        memberAllProgressNotifier,
        memberOverviewProgressNotifier,
        forceUpdate: loadAll,
      );
      rechteProgressNotifier.value = await getRechte();
      syncState = SyncState.successful;
      if (background) {
        sensLog.i('sync successful in background');
        showSnackBar(navigatorKey.currentContext!,
            "Daten wurden erfolgreich synchronisiert");
      }
      setReadyState();
    } on SessionExpired catch (_) {
      sensLog.i('sync failed with session expired');
      syncState = SyncState.relogin;
      if (await setReloginState()) {
        if (!background) {
          /// pop with false to prevent going to ready or loggedOut state
          navigatorKey.currentState!.pop();
        }
        setLoadDataState(loadAll: loadAll, background: background);
      } else {
        if (isTooLongOffline()) {
          syncState = SyncState.error;
          sensLog.i('sync failed with too long offline');
          if (background) {
            showSnackBar(navigatorKey.currentContext!,
                'Du wirst ausgeloggt, da du zu lange offline warst.');
            setLoggedOutState();
          }
          // if not [background] the user will be logged out in
          // [LoadingInfoScreen] when pressing the button
          return;
        }
        if (background) {
          showSnackBar(navigatorKey.currentContext!,
              'Kein Sync möglich ohne erneute Anmeldung.');
        }
        syncState = SyncState.relogin;
        setReadyState();
      }
    } catch (e, st) {
      if (e is http.ClientException || e is TimeoutException) {
        sensLog.i('sync failed with no internet connection');
        syncState = SyncState.offline;
        setReadyState();
      } else {
        sensLog.e('sync failed with error:', error: e, stackTrace: st);
        syncState = SyncState.error;
      }
    }
  }

  /// App is authenticated | User loggin unclear
  ///
  /// Called from [setResumeState]
  Future<void> setAuthenticatedState() async {
    // TODO: Ask for app authentication here

    currentState = AppState.authenticated;

    /// Usually checking the too long offline state can be ckecked via the
    /// daily sync, which may call [setReloginState] and [checkTooLongOffline]
    /// but in offline mode [setReloginState] is not called in [setLoadState].
    if (isTooLongOffline()) {
      sensLog.i('too long offline, set relogin state');
      final success = await setReloginState();

      if (!success) setLoggedOutState();
      return;
    }
    setReadyState();
  }

  /// App is authenticated | User is logged in
  /// Data is available and up to date
  void setReadyState() {
    // Using [getLastNamiSyncTry] to prevent from instant retry after a failed
    // sync when offline
    final nextSync = getLastNamiSyncTry()
        .add(const Duration(days: 1))
        .difference(DateTime.now());
    if (nextSync < const Duration()) {
      sensLog.i(
          "Last sync try is ${DateTime.now().difference(getLastNamiSyncTry())} ago. Sync data in background now");
      setSyncTimer(const Duration());
    } else {
      setSyncTimer(nextSync);
    }
    currentState = AppState.ready;

    // show AppLoggin (with biometrics) Hint when not set
  }

  void setSyncTimer(Duration nextSync) {
    sensLog.i("Scheduled sync data in $nextSync in background");
    syncTimer?.cancel();
    syncTimer = Timer(nextSync, () async {
      if (getSyncOverWifiOnly() && !(await isWifi())) {
        sensLog.i("Don't sync data now, because not in wifi");
        setSyncTimer(const Duration(days: 1));
      } else {
        sensLog.i("Sync data from timer now");
        setLoadDataState(background: true);
      }
    });
  }

  Future<bool> isWifi() async {
    final res = await Connectivity().checkConnectivity();
    return res.contains(ConnectivityResult.wifi);
  }
}

enum SyncState { notStarted, loading, successful, offline, error, relogin }

enum AppState {
  /// Only used for initial state
  closed,

  loggedOut,

  /// App is authenticated, cookie is outdated and password isn't saved.
  /// Therefore user needs to enter credentials again
  relogin,

  /// App is authenticated, user is logged in
  authenticated,

  /// App is authenticated, user is logged in, data is available and up to date
  ready,
}
