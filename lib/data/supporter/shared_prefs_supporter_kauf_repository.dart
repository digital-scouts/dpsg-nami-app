import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/supporter/supporter_kauf_repository.dart';
import '../../domain/supporter/supporter_produkt.dart';

class SharedPrefsSupporterKaufRepository implements SupporterKaufRepository {
  static const String _keyProdukte = 'supporterKaufProdukte';

  @override
  Future<GekaufterSupportAccess> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_keyProdukte) ?? const [];
    return GekaufterSupportAccess.ausProdukten(
      ids.map(SupporterProdukt.vonId).whereType<SupporterProdukt>(),
    );
  }

  @override
  Future<void> save(GekaufterSupportAccess access) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyProdukte, [
      for (final produkt in access.produkte) produkt.id,
    ]);
  }
}
