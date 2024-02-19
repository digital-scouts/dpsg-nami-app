import 'package:flutter/material.dart';

const Color darkSecondary = Color(0xFF520081);

final darkTheme = ThemeData(
  primarySwatch: Colors.blue,
  primaryColor: const Color(0xFF1F1F1F),
  brightness: Brightness.dark,
  dividerColor: const Color(0xFFC9C9C9),
  colorScheme: const ColorScheme(
    primary: Color(0xff007bff),
    primaryContainer: Color(0xff000000),
    secondary: darkSecondary,
    secondaryContainer: Color(0xff00bfa5),
    surface: Color(0xff424242),
    background: Color(0xff616161),
    error: Color(0xffd32f2f),
    onPrimary: Color(0xffffffff),
    onSecondary: Color(0xff000000),
    onSurface: Color(0xffffffff),
    onBackground: Color(0xffffffff),
    onError: Color(0xff000000),
    brightness: Brightness.dark,
  ),
  iconTheme: const IconThemeData(
    color: Color(0xffffffff),
    opacity: 1,
    size: 24,
  ),
);

//################################################################

const Color lightSecondary = Color(0xFF3D7BFF);

final lightTheme = ThemeData(
  primarySwatch: Colors.blue,
  primaryColor: Colors.white,
  brightness: Brightness.light,
  dividerColor: const Color(0xFF616161),
  colorScheme: const ColorScheme(
    primary: Color(0xff007bff),
    primaryContainer: Color(0xff000000),
    secondary: lightSecondary,
    secondaryContainer: Color(0xff00bfa5),
    surface: Color(0xff424242),
    background: Color(0xff616161),
    error: Color(0xffd32f2f),
    onPrimary: Color(0xffffffff),
    onSecondary: Color(0xff000000),
    onSurface: Color(0xffffffff),
    onBackground: Color(0xffffffff),
    onError: Color(0xff000000),
    brightness: Brightness.light,
  ),
  iconTheme: const IconThemeData(
    color: Color(0xFF000000),
    opacity: 1,
    size: 24,
  ),
);

enum ThemeType { light, dark }

class ThemeModel extends ChangeNotifier {
  ThemeData currentTheme = darkTheme;

  setTheme(ThemeType type) {
    if (type == ThemeType.light) {
      currentTheme = lightTheme;
      return notifyListeners();
    }

    if (type == ThemeType.dark) {
      currentTheme = darkTheme;
      return notifyListeners();
    }
  }
}
