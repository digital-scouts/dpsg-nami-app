import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:nami/main.dart';
import 'package:nami/screens/login_screen.dart';
import 'package:nami/screens/utilities/loading_info_screen.dart';
import 'package:nami/screens/utilities/new_version_info_screen.dart';
import 'package:nami/screens/utilities/welcome_screen.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/hive/hive.handler.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/nami.service.dart';
import 'package:nami/utilities/nami/nami_member.service.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'package:nami/utilities/notifications.dart';
import 'package:nami/utilities/types.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wiredash/wiredash.dart';

class AppStateHandler extends ChangeNotifier {
  static final AppStateHandler _instance = AppStateHandler._internal();
  AppState _currentState = AppState.closed;
  SyncState _syncRunning = SyncState.notStarted;
  Timer? syncTimer;
  DateTime lastAuthenticated = DateTime(1970);
  bool _paused = false;

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

  void onPause() {
    sensLog.i("in onPause");
    if (!_paused && currentState == AppState.ready) {
      lastAuthenticated = DateTime.now();
      _paused = true;
    }
  }

  void onResume(BuildContext context) async {
    _paused = false;
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;
    // first open with new version
    if (getLastAppVersion() != appVersion) {
      setNewVersionInfoShown(false);
      setLastAppVersion(appVersion);
      // show version info only when user is not new / welcome message was shown before
      if (!isNewVersionInfoShown()) {
        await Navigator.push(
          navigatorKey.currentContext!,
          MaterialPageRoute(
              builder: (context) =>
                  NewVersionInfoScreen(currentVersion: appVersion)),
        );
        setNewVersionInfoShown(true);
      }
    }

    /// Prevent changing state while relogin when app comes from background
    if (currentState == AppState.relogin) {
      return;
    }
    sensLog.i("in onResume");

    if (getNamiApiCookie().isNotEmpty) {
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
  ///
  /// Setting [showDialog] to false prevents the dialog to ask for relogin.
  /// Instead it will directly show the login screen.
  Future<bool> setReloginState({showDialog = true}) async {
    sensLog.i('Start relogin');
    var showLogin = true;
    final tooLongOffline = isTooLongOffline();
    if (tooLongOffline) {
      sensLog.i('too long offline, show too long offline notification');
      showTooLongOfflineNotification();
    } else if (showDialog) {
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
    Wiredash.trackEvent('Data sync startet');
    sensLog.i(
        'Start loading data with loadAll: $loadAll and background: $background');
    ValueNotifier<List<AllowedFeatures>> rechteProgressNotifier =
        ValueNotifier([]);
    ValueNotifier<String> gruppierungProgressNotifier = ValueNotifier('');
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
      await syncMembers(
        memberAllProgressNotifier,
        memberOverviewProgressNotifier,
        rechteProgressNotifier,
        forceUpdate: loadAll,
      );
      syncState = SyncState.successful;
      if (background) {
        sensLog.i('sync successful in background');
        Wiredash.trackEvent('Data sync successful');
        showSnackBar(navigatorKey.currentContext!,
            "Daten wurden erfolgreich synchronisiert");
      }
      setReadyState();
    } on InvalidNumberOfGruppierungException catch (_) {
      sensLog.i('sync failed with invalid number of gruppierungen');
      Wiredash.trackEvent('Data sync failed', data: {
        'error': 'Invalid number of gruppierungen',
      });

      memberAllProgressNotifier.value = 0;
      rechteProgressNotifier.value = [AllowedFeatures.noPermission];
      gruppierungProgressNotifier.value = 'null';
      gruppierungProgressNotifier.value =
          'Keine oder mehrere Gruppierung(en) gefunden';
      metaProgressNotifier.value = false;
      memberOverviewProgressNotifier.value = false;

      syncState = SyncState.noPermission;
    } on SessionExpiredException catch (_) {
      sensLog.i('sync failed with session expired');
      Wiredash.trackEvent('Data sync failed', data: {
        'error': 'Session expired',
      });
      syncState = SyncState.relogin;
      if (!background) {
        // not setting relogin state when in background as it's done by [ReloginBanner]
        if (await setReloginState()) {
          /// pop with false to prevent going to ready or loggedOut state
          navigatorKey.currentState!.pop();
          setLoadDataState(loadAll: loadAll, background: background);
        }
      }
      if (isTooLongOffline()) {
        syncState = SyncState.error;
        sensLog.i('sync failed with too long offline');
        Wiredash.trackEvent('Data sync failed', data: {
          'error': 'Too long offline',
        });
        if (background) {
          showSnackBar(navigatorKey.currentContext!,
              'Du wirst ausgeloggt, da du zu lange offline warst.');
          setLoggedOutState();
        }
        // if not [background] the user will be logged out in
        // [LoadingInfoScreen] when pressing the button
        return;
      }
      showSnackBar(navigatorKey.currentContext!,
          'Tägliche Aktualisierung nicht möglich. Deine Sitzung ist abgelaufen.');
      syncState = SyncState.relogin;
      setReadyState();
    } catch (e, st) {
      if (e is http.ClientException || e is TimeoutException) {
        sensLog.i('sync failed with no internet connection');
        Wiredash.trackEvent('Data sync failed', data: {
          'error': 'No internet connection',
        });
        syncState = SyncState.offline;
        setReadyState();
      } else {
        sensLog.e('sync failed with error:', error: e, stackTrace: st);
        Wiredash.trackEvent('Data sync failed', data: {
          'error': e.toString(),
          'stackTrace': st.toString(),
        });
        syncState = SyncState.error;
      }
    }
  }

  bool get authenticationStillValid =>
      DateTime.now().difference(lastAuthenticated) < const Duration(minutes: 2);

  /// App is authenticated | User loggin unclear
  ///
  /// Called from [onResume]
  Future<void> setAuthenticatedState([forceAuthentication = false]) async {
    if (!forceAuthentication && currentState == AppState.retryAuthentication) {
      return;
    }
    if (getBiometricAuthenticationEnabled() &&
        (forceAuthentication || (!authenticationStillValid))) {
      final LocalAuthentication auth = LocalAuthentication();
      final canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      if (canAuthenticate) {
        try {
          final isAuthenticated = await auth.authenticate(
            localizedReason: 'Bitte bestätige deine Identität',
          );
          if (isAuthenticated) {
            lastAuthenticated = DateTime.now();
          } else {
            currentState = AppState.retryAuthentication;
            return;
          }
        } on PlatformException catch (e, st) {
          sensLog.e('Exception in biometric authentication:',
              error: e, stackTrace: st);
          currentState = AppState.retryAuthentication;
          return;
        }
      }
    }

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
  Future<void> setReadyState() async {
    if (!getWelcomeMessageShown()) {
      await Navigator.push(
        navigatorKey.currentContext!,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
      setWelcomeMessageShown(true);
    }
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
      if (getDataLoadingOverWifiOnly() && !(await isWifi())) {
        sensLog.i("Don't sync data now, because not in wifi");
        setSyncTimer(const Duration(days: 1));
      } else {
        sensLog.i("Sync data from timer now");
        setLoadDataState(background: true);
      }
    });
  }
}

enum SyncState {
  notStarted,
  loading,
  successful,
  offline,
  error,
  relogin,
  noPermission
}

enum AppState {
  /// Only used for initial state
  closed,

  loggedOut,

  retryAuthentication,

  /// App is authenticated, cookie is outdated and password isn't saved.
  /// Therefore user needs to enter credentials again
  relogin,

  /// App is authenticated, user is logged in
  ready,
}
