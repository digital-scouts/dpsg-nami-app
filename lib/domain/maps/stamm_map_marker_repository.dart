import 'stamm_map_marker.dart';

abstract class StammMapMarkerRepository {
  Future<StammMapMarkerSnapshot> loadCachedOrFallback();
  Future<StammMapMarkerSnapshot?> refreshIfDue();
  Future<StammMapMarkerSnapshot> forceRefresh();
}
