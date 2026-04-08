import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/data/maps/asset_diocese_boundary_repository.dart';
import 'package:nami/domain/maps/diocese_boundary.dart';
import 'package:nami/domain/maps/diocese_boundary_repository.dart';
import 'package:nami/domain/maps/stamm_map_marker.dart';
import 'package:nami/domain/maps/stamm_map_marker_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/stamm_cluster_layer.dart';
import 'package:nami/services/map_tile_cache_service.dart';
import 'package:nami/services/maps_env.dart';
import 'package:nami/services/stamm_map_sync_service.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalUrlOpener = Future<bool> Function(Uri uri);

class SettingsMapPage extends StatefulWidget {
  const SettingsMapPage({
    super.key,
    this.repository,
    this.stammRepository,
    this.stammMinVisibleZoom,
    this.externalUrlOpener,
    this.initialSelectedBoundaryId,
    this.initialSelectedStammMarkerId,
  });

  final DioceseBoundaryRepository? repository;
  final StammMapMarkerRepository? stammRepository;
  final double? stammMinVisibleZoom;
  final ExternalUrlOpener? externalUrlOpener;
  final String? initialSelectedBoundaryId;
  final String? initialSelectedStammMarkerId;

  @override
  State<SettingsMapPage> createState() => _SettingsMapPageState();
}

class _SettingsMapPageState extends State<SettingsMapPage> {
  late Future<List<DioceseBoundary>> _future;
  late final StammMapMarkerRepository _stammRepository;
  final MapController _mapController = MapController();
  final LayerHitNotifier<String> _polygonHitNotifier = ValueNotifier(null);
  String? _selectedBoundaryId;
  String? _selectedStammMarkerId;
  List<StammMapMarker> _stammMarkers = const [];
  double _currentZoom = 6;

  @override
  void initState() {
    super.initState();
    _stammRepository = widget.stammRepository ?? StammMapSyncService();
    _selectedBoundaryId = widget.initialSelectedBoundaryId;
    _selectedStammMarkerId = widget.initialSelectedStammMarkerId;
    _future = _loadBoundaries();
    _polygonHitNotifier.addListener(_handlePolygonHitChange);
    _loadStammMarkers();
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
      if (nextSelectedBoundaryId != null) {
        _selectedStammMarkerId = null;
      }
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

  Future<void> _loadStammMarkers() async {
    try {
      final snapshot = await _stammRepository.loadCachedOrFallback();
      if (!mounted) {
        return;
      }
      setState(() {
        _stammMarkers = snapshot.markers;
        if (!_hasSelectedStammMarker(snapshot.markers)) {
          _selectedStammMarkerId = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stammMarkers = const [];
        _selectedStammMarkerId = null;
      });
    }

    _refreshStammMarkersIfDue();
  }

  Future<void> _refreshStammMarkersIfDue() async {
    try {
      final snapshot = await _stammRepository.refreshIfDue();
      if (!mounted || snapshot == null) {
        return;
      }
      setState(() {
        _stammMarkers = snapshot.markers;
        if (!_hasSelectedStammMarker(snapshot.markers)) {
          _selectedStammMarkerId = null;
        }
      });
    } catch (_) {
      // Cache oder Asset bleiben aktiv, daher hier bewusst kein Fehler-UI.
    }
  }

  bool _hasSelectedStammMarker(List<StammMapMarker> markers) {
    final selectedId = _selectedStammMarkerId;
    if (selectedId == null) {
      return false;
    }
    return markers.any((marker) => marker.id == selectedId);
  }

  StammMapMarker? _selectedStammMarker() {
    final selectedId = _selectedStammMarkerId;
    if (selectedId == null) {
      return null;
    }

    for (final marker in _stammMarkers) {
      if (marker.id == selectedId) {
        return marker;
      }
    }
    return null;
  }

  String? _normalizedWebsite(String? rawWebsite) {
    final trimmed = rawWebsite?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed);
    final candidate = hasScheme ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    return uri.toString();
  }

  String? _selectedWebsite({
    StammMapMarker? selectedStammMarker,
    DioceseBoundary? selectedBoundary,
  }) {
    return _normalizedWebsite(selectedStammMarker?.website) ??
        _normalizedWebsite(selectedBoundary?.website);
  }

  String _websiteLabel(String normalizedWebsite) {
    return normalizedWebsite.replaceFirst(RegExp(r'^https?://'), '');
  }

  Future<void> _openWebsite(String normalizedWebsite) async {
    final opener = widget.externalUrlOpener ?? _launchExternalUrl;
    final didOpen = await opener(Uri.parse(normalizedWebsite));
    if (!didOpen && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kann Link nicht öffnen')));
    }
  }

  static Future<bool> _launchExternalUrl(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
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
          final selectedStammMarker = _selectedStammMarker();
          final selectedLabel =
              selectedStammMarker?.name ?? selectedBoundary?.name;
          final selectedWebsite = _selectedWebsite(
            selectedStammMarker: selectedStammMarker,
            selectedBoundary: selectedBoundary,
          );
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
                              onPositionChanged: (camera, hasGesture) {
                                final nextZoom = camera.zoom;
                                if ((_currentZoom - nextZoom).abs() < 0.01) {
                                  return;
                                }
                                setState(() {
                                  _currentZoom = nextZoom;
                                });
                              },
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
                              StammClusterLayer(
                                markers: _stammMarkers,
                                currentZoom: _currentZoom,
                                minVisibleZoom:
                                    widget.stammMinVisibleZoom ??
                                    MapsEnv.stammMinVisibleZoom,
                                onMarkerTap: (marker) {
                                  setState(() {
                                    _selectedBoundaryId = null;
                                    _selectedStammMarkerId = marker.id;
                                  });
                                },
                              ),
                            ],
                          ),
                          if (selectedLabel != null)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: _SelectedBoundaryCard(
                                title: selectedLabel,
                                websiteLabel: selectedWebsite == null
                                    ? null
                                    : _websiteLabel(selectedWebsite),
                                onOpenWebsite: selectedWebsite == null
                                    ? null
                                    : () => _openWebsite(selectedWebsite),
                                onClose: () {
                                  setState(() {
                                    _selectedBoundaryId = null;
                                    _selectedStammMarkerId = null;
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
    required this.title,
    required this.onClose,
    this.websiteLabel,
    this.onOpenWebsite,
  });

  final String title;
  final String? websiteLabel;
  final Future<void> Function()? onOpenWebsite;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (websiteLabel != null && onOpenWebsite != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextButton.icon(
                        onPressed: () => onOpenWebsite!(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          alignment: Alignment.centerLeft,
                        ),
                        icon: const Icon(Icons.link, size: 16),
                        label: Text(
                          websiteLabel!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
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
