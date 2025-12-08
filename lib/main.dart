import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nami/presentation/navigation/navigation_home.page.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

import 'data/settings/shared_prefs_app_settings_repository.dart';
import 'domain/settings/app_settings.dart';
import 'domain/settings/app_settings_repository.dart';
import 'l10n/app_localizations.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/theme/locale_model.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting("de_DE", null);
  Intl.defaultLocale = "de_DE";

  // Settings laden und Provider initialisieren
  final AppSettingsRepository settingsRepo = SharedPrefsAppSettingsRepository();
  final AppSettings initial = await settingsRepo.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              ThemeModel(persist: (mode) => settingsRepo.saveThemeMode(mode))
                ..currentMode = initial.themeMode,
        ),
        ChangeNotifierProvider(
          create: (_) => LocaleModel(
            persist: (code) => settingsRepo.saveLanguageCode(code),
          )..setLocale(Locale(initial.languageCode)),
        ),
      ],
      child: const MyApp(),
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

    return Consumer<ThemeModel>(
      builder: (context, themeModel, _) {
        return MaterialApp(
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeModel.currentMode,
          navigatorKey: navigatorKey,
          onGenerateRoute: onGenerateRoute,
          initialRoute: '/',
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          locale: context.watch<LocaleModel>().currentLocale,
          home: Wiredash(
            projectId: projectId,
            secret: secret,
            child: const NavigationHomeScreen(),
          ),
        );
      },
    );
  }
}
