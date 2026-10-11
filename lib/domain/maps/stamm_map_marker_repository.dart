import 'stamm_map_marker.dart';

abstract class StammMapMarkerRepository {
  Future<StammMapMarkerSnapshot> loadCachedOrFallback();

  /// Laedt neu, wenn der Cache faellig ist. Bei „Mobile Daten einschränken“
  /// ohne WLAN nur mit [allowMobileDataOverride].
  Future<StammMapMarkerSnapshot?> refreshIfDue({
    bool allowMobileDataOverride = false,
  });
  Future<StammMapMarkerSnapshot> forceRefresh();
}
