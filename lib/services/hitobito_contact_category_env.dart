import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../domain/member/contact_category.dart';

class HitobitoContactCategoryEnv {
  /// Zuordnung der DPSG-Kategorie-Keys zu den IDs der Hitobito-Instanz, etwa
  /// `phone_number.mobile=12,phone_number.other=17`. Leer sperrt die Anlage
  /// neuer Telefonnummern, Zusatzmails und Zusatzadressen.
  static ContactCategoryCatalog get catalog =>
      ContactCategoryCatalog.parse(_env('HITOBITO_CONTACT_CATEGORY_IDS'));

  static String? _env(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}
