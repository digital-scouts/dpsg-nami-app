import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nami/data/datasource/hive/boxes.dart';
import 'package:nami/data/datasource/hive/user/hive_user_data_source.dart';
import 'package:nami/data/datasource/nami/login.api.dart';
import 'package:nami/data/repositories/auth_repository_impl.dart';
import 'package:nami/domain/repositories/auth_repository.dart';
import 'package:nami/presentation/app/app_cubit.dart';
import 'package:nami/presentation/navigation/navigation_home.page.dart';
import 'package:nami/utilities/custom_wiredash_translations_delegate.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/hive/hive_service.dart';
import 'package:nami/utilities/hive/settings_service.dart' hide settingsBox;
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/notifications/birthday_notifications.dart';
import 'package:nami/utilities/theme.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

import 'presentation/login/login.page.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initLogger();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting("de_DE", null);
  Intl.defaultLocale = "de_DE";

  await initHiveBoxes();

  final loginApi = LoginApi();
  final userData = HiveUserDataSource(settingsBox);
  final authRepo = AuthRepositoryImpl(loginApi, userData);

  // Initialisiere die Services
  initializeSettingsService();
  initializeHiveService();

  try {
    await FMTCObjectBoxBackend().initialise();
    const FMTCStore('mapStore').manage.create();
    enableMapTileCaching();
  } catch (e) {
    sensLog.e(
      'Error while initalice objectbox for flutter_map_tile_caching: $e',
    );
  }

  await BirthdayNotificationService.init();

  runApp(
    RepositoryProvider<AuthRepository>.value(
      value: authRepo,
      child: MultiProvider(
        providers: [
          BlocProvider(create: (context) => AppCubit(authRepo)),
          ChangeNotifierProvider(create: (_) => ThemeModel()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final projectId = dotenv.env['WIREDASH_PROJECT_ID'];
    final secret = dotenv.env['WIREDASH_SECRET'];

    if (projectId == null ||
        secret == null ||
        projectId.isEmpty ||
        secret.isEmpty) {
      throw Exception('Wiredash-Konfiguration fehlt in .env');
    }

    return Wiredash(
      projectId: projectId,
      secret: secret,
      options: const WiredashOptionsData(
        localizationDelegate: CustomWiredashTranslationsDelegate(),
        locale: Locale('de', 'DE'),
      ),
      feedbackOptions: const WiredashFeedbackOptions(
        labels: [
          Label(id: 'label-u26353u60f', title: 'Fehler'),
          Label(id: 'label-mtl2xk4esi', title: 'Verbesserung'),
          Label(id: 'label-p792odog4e', title: 'Lob'),
        ],
      ),
      child: Consumer<ThemeModel>(
        builder: (context, themeModel, _) {
          return MaterialApp(
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeModel.currentMode,
            navigatorKey: navigatorKey,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('de', 'DE')],
            home: const _AppRoot(),
            builder: (context, child) {
              return Stack(
                children: [
                  child!,
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: () => openWiredash(context, 'Feedback FAB'),
                      child: const Icon(Icons.feedback),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, AppStatus>(
      builder: (context, state) {
        switch (state) {
          case AppStatus.loading:
            print('App is loading...');
            return const Center(child: CircularProgressIndicator());
          case AppStatus.unauthenticated:
            print('User is unauthenticated');
            return const LoginPage();
          case AppStatus.authenticated:
            print('User is authenticated');
            return const NavigationHomeScreen();
        }
      },
    );
  }
}
