import 'package:flutter/material.dart';

class LocaleModel extends ChangeNotifier {
  Locale _locale = const Locale('de');

  final Future<void> Function(String)? _persist;

  LocaleModel({Future<void> Function(String)? persist}) : _persist = persist;

  Locale get currentLocale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
    final persist = _persist;
    if (persist != null) {
      persist(locale.languageCode);
    }
  }
}
