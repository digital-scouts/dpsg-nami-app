import 'package:flutter/material.dart';

class LocaleModel extends ChangeNotifier {
  Locale _locale = const Locale('de');

  final Future<void> Function(String)? _persist;

  LocaleModel({Future<void> Function(String)? persist}) : _persist = persist;

  Locale get currentLocale => _locale;

  void setLocale(Locale locale, {bool persist = true}) {
    if (_locale == locale) {
      return;
    }

    _locale = locale;
    notifyListeners();
    final persistHandler = _persist;
    if (persistHandler != null && persist) {
      persistHandler(locale.languageCode);
    }
  }
}
