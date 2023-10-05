import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nami/screens/login.dart';
import 'package:nami/screens/navigation_home_screen.dart';
import 'package:nami/utilities/hive/logout.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:nami/utilities/nami/nami-login.service.dart';
import 'package:nami/utilities/theme.dart';
import 'package:provider/provider.dart';
import 'utilities/nami/nami.service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  runApp(ChangeNotifierProvider<ThemeModel>(
      create: (_) => ThemeModel(), child: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  Key key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MyHome());
  }
}

class MyHome extends StatefulWidget {
  const MyHome({Key? key}) : super(key: key);

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> with WidgetsBindingObserver {
  final LocalAuthentication auth = LocalAuthentication();
  _SupportState _supportState = _SupportState.unknown;
  bool? _canCheckBiometrics;
  List<BiometricType>? _availableBiometrics;
  String _authorized = "Not Authorized";
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  bool _appIsPaused = false;
  bool _hiveIsOpen = false;
  bool _dataIsReady = false;

  void openLoginPage() {
    Navigator.push(context,
            MaterialPageRoute(builder: (context) => const LoginScreen()))
        .then((value) async {
      await syncNamiData();
      setState(() {
        _dataIsReady = true;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    auth.isDeviceSupported().then(
          (bool isSupported) async => {
            if (isSupported)
              {
                setState(() => _supportState = _SupportState.supported),
                await Future.wait(
                    [_checkBiometrics(), _getAvailableBiometrics()]),
                await _authenticate(),
              }
            else
              {
                setState(() => _supportState = _SupportState.unsupported),
                throw Exception('Device not supported'),
              },
          },
        );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      setState(() {
        _appIsPaused = true;
      });
    } else if (state == AppLifecycleState.resumed && _appIsPaused) {
      await _authenticate();
      if (!_isAuthenticated) {
        // If the user is not authenticated, exit the app
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SystemNavigator.pop();
        });
        throw Exception('Not authenticated');
      }
    }
  }

  void afterAuthentication() async {
    if (!_isAuthenticated) return;
    await openHive();

    bool lastSyncShortly =
        DateTime.now().difference(getLastNamiSync()!).inDays < 30;
    Box<Mitglied> memberBox = Hive.box<Mitglied>('members');
    bool memberDataIsPresent = memberBox.length > 0;
    if (lastSyncShortly && memberDataIsPresent) {
      // dont need nami login, data is present and up to date
      setState(() {
        _dataIsReady = true;
      });
      return;
    } else {
      int? loginId = getNamiLoginId();
      String? password = getNamiPassword();
      if (loginId == null || password == null || !await updateLoginData()) {
        // loginData is not stored or login not successful: clear data push login page
        logout();
        openLoginPage();
        return;
      } else {
        await syncNamiData();
        setState(() {
          _dataIsReady = true;
        });
      }
    }
  }

  Future<void> openHive() async {
    if (_hiveIsOpen) return;
    const secureStorage = FlutterSecureStorage();
    var encryprionKey = await secureStorage.read(key: 'key');
    if (encryprionKey == null) {
      final key = Hive.generateSecureKey();
      await secureStorage.write(
        key: 'key',
        value: base64UrlEncode(key),
      );
    }
    final encryptionKey =
        base64Url.decode((await secureStorage.read(key: 'key'))!);

    Hive.registerAdapter(TaetigkeitAdapter());
    Hive.registerAdapter(MitgliedAdapter());
    await Future.wait([
      Hive.openBox<Taetigkeit>('taetigkeit',
          encryptionCipher: HiveAesCipher(encryptionKey)),
      Hive.openBox<Mitglied>('members',
          encryptionCipher: HiveAesCipher(encryptionKey)),
      Hive.openBox('settingsBox',
          encryptionCipher: HiveAesCipher(encryptionKey))
    ]);
    setState(() {
      _hiveIsOpen = true;
    });
  }

  Future<void> _checkBiometrics() async {
    late bool canCheckBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      canCheckBiometrics = false;
      print(e);
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _canCheckBiometrics = canCheckBiometrics;
    });
  }

  Future<void> _getAvailableBiometrics() async {
    late List<BiometricType> availableBiometrics;
    try {
      availableBiometrics = await auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      availableBiometrics = <BiometricType>[];
      print(e);
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _availableBiometrics = availableBiometrics;
    });
  }

  Future<void> _authenticate() async {
    setState(() {
      _appIsPaused = true;
    });
    bool authenticated = false;
    String localizedReason;
    AuthenticationOptions options;

    if (_availableBiometrics!.isNotEmpty && _canCheckBiometrics!) {
      localizedReason =
          'Scan your fingerprint (or face or whatever) to authenticate';
      options = const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      );
    } else {
      localizedReason = 'Please enter your password to authenticate';
      options = const AuthenticationOptions(stickyAuth: true);
    }

    try {
      setState(() {
        _isAuthenticating = true;
        _authorized = 'Authenticating';
        debugPrint(_authorized);
      });
      authenticated = await auth.authenticate(
        localizedReason: localizedReason,
        options: options,
      );
      setState(() {
        _isAuthenticating = false;
      });
    } on PlatformException catch (e) {
      print(e);
      setState(() {
        _isAuthenticating = false;
        _authorized = 'Error - ${e.message}';
        debugPrint(_authorized);
      });
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() => {
          _appIsPaused = !authenticated,
          _isAuthenticated = authenticated,
          _authorized = authenticated ? 'Authorized' : 'Not Authorized',
        });
    debugPrint(_authorized);
    afterAuthentication();
  }

  Widget _buildTryAuthenticationAgainWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_authorized),
          ElevatedButton(
              onPressed: _authenticate, child: const Text('Try again'))
        ],
      ),
    );
  }

  Widget _buildAppIsPausedWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 100),
            const SizedBox(width: 30),
            if (_availableBiometrics!.isNotEmpty && _canCheckBiometrics!)
              const Icon(Icons.fingerprint, size: 100)
            else
              const Icon(Icons.password, size: 100),
          ],
        ),
        const SizedBox(height: 30),
        const Center(
          child: Text(
            'Bitte authentifiziere dich, bevor du auf die sensiblen Daten zugreifst.',
            textScaleFactor: 1.4,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height / 2),
        _buildTryAuthenticationAgainWidget(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: Provider.of<ThemeModel>(context).currentTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            if (_appIsPaused) {
              return _buildAppIsPausedWidget();
            }
            if (_supportState != _SupportState.unknown &&
                !_isAuthenticating &&
                _hiveIsOpen &&
                _dataIsReady) {
              if (_isAuthenticated) {
                return const NavigationHomeScreen();
              } else {
                return const Text('Woops, something went wrong!');
              }
            } else if (_supportState != _SupportState.unknown &&
                !_isAuthenticating &&
                !_isAuthenticated) {
              return _buildTryAuthenticationAgainWidget();
            } else {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                  // todo give more information about loading status (show nami sync)
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

enum _SupportState {
  unknown,
  supported,
  unsupported,
}
