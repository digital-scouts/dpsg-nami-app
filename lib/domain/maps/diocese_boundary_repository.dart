import 'diocese_boundary.dart';

abstract class DioceseBoundaryRepository {
  Future<List<DioceseBoundary>> loadBoundaries();
}
