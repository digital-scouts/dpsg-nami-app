import 'package:flutter/material.dart';

class LocaleModel extends ChangeNotifier {
  Locale _locale = const Locale('de');

  Locale get currentLocale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}
