import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/data/maps/asset_diocese_boundary_repository.dart';
import 'package:nami/domain/maps/diocese_boundary.dart';
import 'package:nami/domain/maps/diocese_boundary_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/services/map_tile_cache_service.dart';
import 'package:nami/services/maps_env.dart';

class SettingsMapPage extends StatefulWidget {
  const SettingsMapPage({super.key, this.repository});

  final DioceseBoundaryRepository? repository;

  @override
  State<SettingsMapPage> createState() => _SettingsMapPageState();
}

class _SettingsMapPageState extends State<SettingsMapPage> {
  late Future<List<DioceseBoundary>> _future;
  final MapController _mapController = MapController();
  final LayerHitNotifier<String> _polygonHitNotifier = ValueNotifier(null);
  String? _selectedBoundaryId;

  @override
  void initState() {
    super.initState();
    _future = _loadBoundaries();
    _polygonHitNotifier.addListener(_handlePolygonHitChange);
  }

  @override
  void dispose() {
    _polygonHitNotifier
      ..removeListener(_handlePolygonHitChange)
      ..dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<List<DioceseBoundary>> _loadBoundaries() {
    final repository =
        widget.repository ?? const AssetDioceseBoundaryRepository();
    return repository.loadBoundaries();
  }

  void _handlePolygonHitChange() {
    final result = _polygonHitNotifier.value;
    final nextSelectedBoundaryId = result == null || result.hitValues.isEmpty
        ? null
        : result.hitValues.last;
    if (_selectedBoundaryId == nextSelectedBoundaryId) {
      return;
    }
    setState(() {
      _selectedBoundaryId = nextSelectedBoundaryId;
    });
  }

  void _recenterMap(List<LatLng> points) {
    if (points.isEmpty) {
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(28),
        maxZoom: 12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('settings_map_title'))),
      body: FutureBuilder<List<DioceseBoundary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(t.t('settings_map_loading')),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.t('settings_map_error'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final boundaries = snapshot.data ?? const <DioceseBoundary>[];
          if (boundaries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.t('settings_map_empty'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allPoints = boundaries
              .expand((boundary) => boundary.polygons)
              .expand((polygon) => polygon.points)
              .toList(growable: false);
          final boundariesById = {
            for (final boundary in boundaries) boundary.id: boundary,
          };
          final selectedBoundary = _selectedBoundaryId == null
              ? null
              : boundariesById[_selectedBoundaryId!];
          final initialCameraFit = CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(allPoints),
            padding: const EdgeInsets.all(28),
            maxZoom: 12,
          );

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: allPoints.first,
                              initialZoom: 6,
                              minZoom: 4,
                              maxZoom: 16,
                              initialCameraFit: initialCameraFit,
                              interactionOptions: const InteractionOptions(
                                flags:
                                    InteractiveFlag.all &
                                    ~InteractiveFlag.rotate,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: MapsEnv.mapTileUrlTemplate,
                                userAgentPackageName:
                                    MapTileCacheService.userAgentPackageName,
                                maxZoom: 19,
                              ),
                              PolygonLayer<String>(
                                polygons: _buildPolygons(
                                  boundaries,
                                  selectedBoundaryId: _selectedBoundaryId,
                                ),
                                polygonLabels: false,
                                hitNotifier: _polygonHitNotifier,
                              ),
                            ],
                          ),
                          if (selectedBoundary != null)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: _SelectedBoundaryCard(
                                boundaryName: selectedBoundary.name,
                                onClose: () {
                                  setState(() {
                                    _selectedBoundaryId = null;
                                  });
                                  _polygonHitNotifier.value = null;
                                },
                              ),
                            ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0.78),
                              elevation: 2,
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: t.t('settings_map_recenter'),
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _recenterMap(allPoints),
                                icon: const Icon(
                                  Icons.center_focus_strong,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Polygon<String>> _buildPolygons(
    List<DioceseBoundary> boundaries, {
    required String? selectedBoundaryId,
  }) {
    final colors = <Color>[
      const Color(0xFF00695C),
      const Color(0xFF1565C0),
      const Color(0xFFEF6C00),
      const Color(0xFF6A1B9A),
      const Color(0xFF2E7D32),
      const Color(0xFFAD1457),
    ];

    return boundaries
        .asMap()
        .entries
        .expand((entry) {
          final baseColor = colors[entry.key % colors.length];
          final isSelected = entry.value.id == selectedBoundaryId;
          final hasSelection = selectedBoundaryId != null;
          final fillColor = isSelected
              ? baseColor.withValues(alpha: 0.34)
              : hasSelection
              ? baseColor.withValues(alpha: 0.10)
              : baseColor.withValues(alpha: 0.18);
          final borderColor = isSelected
              ? baseColor.withValues(alpha: 1)
              : hasSelection
              ? baseColor.withValues(alpha: 0.45)
              : baseColor.withValues(alpha: 0.85);
          final borderStrokeWidth = isSelected ? 3.5 : 2.0;
          return entry.value.polygons.map(
            (polygon) => Polygon(
              points: polygon.points,
              holePointsList: polygon.holes,
              color: fillColor,
              borderColor: borderColor,
              borderStrokeWidth: borderStrokeWidth,
              hitValue: entry.value.id,
            ),
          );
        })
        .toList(growable: false);
  }
}

class _SelectedBoundaryCard extends StatelessWidget {
  const _SelectedBoundaryCard({
    required this.boundaryName,
    required this.onClose,
  });

  final String boundaryName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Text(boundaryName, style: theme.textTheme.titleMedium),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
