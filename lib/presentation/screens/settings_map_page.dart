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
    this.dvMaxVisibleZoom,
    this.externalUrlOpener,
    this.initialSelectedBoundaryId,
    this.initialSelectedStammMarkerId,
  });

  final DioceseBoundaryRepository? repository;
  final StammMapMarkerRepository? stammRepository;
  final double? stammMinVisibleZoom;
  final double? dvMaxVisibleZoom;
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
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String? _selectedBoundaryId;
  String? _selectedStammMarkerId;
  List<StammMapMarker> _stammMarkers = const [];
  double _currentZoom = 6;
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _stammRepository = widget.stammRepository ?? StammMapSyncService();
    _searchController = TextEditingController()
      ..addListener(_handleSearchTextChange);
    _searchFocusNode = FocusNode();
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
    _searchController
      ..removeListener(_handleSearchTextChange)
      ..dispose();
    _searchFocusNode.dispose();
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

  void _handleSearchTextChange() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  EdgeInsets get _mapViewportPadding {
    return const EdgeInsets.fromLTRB(28, 96, 28, 148);
  }

  void _recenterMap(List<LatLng> points) {
    if (points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 13, id: 'recenter');
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: _mapViewportPadding,
        maxZoom: 12,
      ),
    );
  }

  void _openSearch() {
    if (_isSearchOpen) {
      return;
    }
    setState(() {
      _isSearchOpen = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    if (!_isSearchOpen) {
      return;
    }
    setState(() {
      _isSearchOpen = false;
    });
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

  String? _selectedLabel({
    StammMapMarker? selectedStammMarker,
    DioceseBoundary? selectedBoundary,
  }) {
    if (selectedStammMarker != null) {
      return selectedStammMarker.category == StammMapMarkerCategory.standard
          ? 'Stamm ${selectedStammMarker.name}'
          : selectedStammMarker.name;
    }

    return selectedBoundary?.name;
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

  List<_MapSearchEntry> _buildSearchResults(List<DioceseBoundary> boundaries) {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return const [];
    }

    final entries = <_MapSearchEntry>[
      ...boundaries.map(_MapSearchEntry.boundary),
      ..._stammMarkers.map(_MapSearchEntry.marker),
    ];

    final matches =
        entries
            .map((entry) => (entry: entry, score: entry.matchScore(query)))
            .where((result) => result.score != null)
            .map((result) => (entry: result.entry, score: result.score!))
            .toList(growable: false)
          ..sort((left, right) {
            final scoreCompare = left.score.compareTo(right.score);
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            return left.entry.title.compareTo(right.entry.title);
          });

    return matches
        .take(8)
        .map((result) => result.entry)
        .toList(growable: false);
  }

  void _selectSearchEntry(_MapSearchEntry entry) {
    if (entry.boundary != null) {
      final points = entry.boundary!.polygons
          .expand((polygon) => polygon.points)
          .toList(growable: false);
      if (points.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: _mapViewportPadding,
            maxZoom: 12,
          ),
        );
      }
    } else if (entry.marker != null) {
      final marker = entry.marker!;
      _mapController.move(
        LatLng(marker.latitude, marker.longitude),
        _currentZoom < 13 ? 13 : _currentZoom,
        id: 'search-selection',
      );
    }

    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _isSearchOpen = false;
      _selectedBoundaryId = entry.boundary?.id;
      _selectedStammMarkerId = entry.marker?.id;
    });

    if (entry.marker != null) {
      _polygonHitNotifier.value = null;
    }
  }

  Widget _buildStandaloneState(BuildContext context, Widget child) {
    return Stack(
      children: [
        Center(child: child),
        Positioned.fill(
          child: SafeArea(
            minimum: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.topLeft,
              child: _MapOverlayButton(
                key: const ValueKey('settings-map-back-button'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icons.arrow_back,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: FutureBuilder<List<DioceseBoundary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _buildStandaloneState(
              context,
              Column(
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
            return _buildStandaloneState(
              context,
              Padding(
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
            return _buildStandaloneState(
              context,
              Padding(
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
          final selectedLabel = _selectedLabel(
            selectedStammMarker: selectedStammMarker,
            selectedBoundary: selectedBoundary,
          );
          final selectedWebsite = _selectedWebsite(
            selectedStammMarker: selectedStammMarker,
            selectedBoundary: selectedBoundary,
          );
          final searchResults = _buildSearchResults(boundaries);
          final dvMaxVisibleZoom =
              widget.dvMaxVisibleZoom ?? MapsEnv.dvMaxVisibleZoom;
          final initialCameraFit = CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(allPoints),
            padding: _mapViewportPadding,
            maxZoom: 12,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: allPoints.first,
                    initialZoom: 6,
                    minZoom: 4,
                    maxZoom: 16,
                    initialCameraFit: initialCameraFit,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onPositionChanged: (camera, hasGesture) {
                      final nextZoom = camera.zoom;
                      final zoomChanged =
                          (_currentZoom - nextZoom).abs() >= 0.01;
                      final shouldDisableBoundarySelection =
                          nextZoom >= dvMaxVisibleZoom &&
                          _selectedBoundaryId != null;

                      if (!zoomChanged && !shouldDisableBoundarySelection) {
                        return;
                      }

                      setState(() {
                        _currentZoom = nextZoom;
                        if (shouldDisableBoundarySelection) {
                          _selectedBoundaryId = null;
                        }
                      });

                      if (shouldDisableBoundarySelection) {
                        _polygonHitNotifier.value = null;
                      }
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
                        showBorderOnly: _currentZoom >= dvMaxVisibleZoom,
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
                        _polygonHitNotifier.value = null;
                      },
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableSearchWidth = constraints.maxWidth - 64;
                      final searchPanelWidth = switch (availableSearchWidth) {
                        <= 0 => constraints.maxWidth,
                        > 420 => 420.0,
                        _ => availableSearchWidth,
                      };

                      return Stack(
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: _MapOverlayButton(
                              key: const ValueKey('settings-map-back-button'),
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).backButtonTooltip,
                              icon: Icons.arrow_back,
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topRight,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _MapSearchControl(
                                  isOpen: _isSearchOpen,
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  hintText: t.t('settings_map_search_hint'),
                                  openTooltip: t.t('settings_map_search'),
                                  closeTooltip: t.t(
                                    'settings_map_search_close',
                                  ),
                                  expandedWidth: searchPanelWidth,
                                  onOpen: _openSearch,
                                  onClose: _closeSearch,
                                ),
                                const SizedBox(height: 8),
                                _MapOverlayButton(
                                  key: const ValueKey(
                                    'settings-map-recenter-button',
                                  ),
                                  tooltip: t.t('settings_map_recenter'),
                                  icon: Icons.center_focus_strong,
                                  onPressed: () => _recenterMap(allPoints),
                                ),
                                if (_isSearchOpen &&
                                    _searchController.text.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: _SearchResultsCard(
                                      maxWidth: searchPanelWidth,
                                      results: searchResults,
                                      noResultsLabel: t.t(
                                        'settings_map_search_no_results',
                                      ),
                                      typeLabelBuilder: (entry) => switch (entry
                                          .kind) {
                                        _MapSearchEntryKind.stamm => t.t(
                                          'settings_map_search_type_stamm',
                                        ),
                                        _MapSearchEntryKind.district => t.t(
                                          'settings_map_search_type_district',
                                        ),
                                        _MapSearchEntryKind.boundary => t.t(
                                          'settings_map_search_type_diocese',
                                        ),
                                        _MapSearchEntryKind.dioceseMarker =>
                                          t.t('settings_map_search_type_dv'),
                                        _MapSearchEntryKind.federal => t.t(
                                          'settings_map_search_type_federal',
                                        ),
                                      },
                                      onSelected: _selectSearchEntry,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (selectedLabel != null)
                            Align(
                              alignment: Alignment.bottomCenter,
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
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Polygon<String>> _buildPolygons(
    List<DioceseBoundary> boundaries, {
    required String? selectedBoundaryId,
    required bool showBorderOnly,
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
          final fillColor = showBorderOnly
              ? null
              : isSelected
              ? baseColor.withValues(alpha: 0.34)
              : hasSelection
              ? baseColor.withValues(alpha: 0.10)
              : baseColor.withValues(alpha: 0.18);
          final borderColor = showBorderOnly
              ? baseColor.withValues(alpha: 0.85)
              : isSelected
              ? baseColor.withValues(alpha: 1)
              : hasSelection
              ? baseColor.withValues(alpha: 0.45)
              : baseColor.withValues(alpha: 0.85);
          final borderStrokeWidth = showBorderOnly
              ? 2.0
              : isSelected
              ? 3.5
              : 2.0;
          return entry.value.polygons.map(
            (polygon) => Polygon(
              points: polygon.points,
              holePointsList: polygon.holes,
              color: fillColor,
              borderColor: borderColor,
              borderStrokeWidth: borderStrokeWidth,
              hitValue: showBorderOnly ? null : entry.value.id,
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

class _MapOverlayButton extends StatelessWidget {
  const _MapOverlayButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
      elevation: 3,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
      ),
    );
  }
}

class _MapSearchControl extends StatelessWidget {
  const _MapSearchControl({
    required this.isOpen,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.openTooltip,
    required this.closeTooltip,
    required this.expandedWidth,
    required this.onOpen,
    required this.onClose,
  });

  final bool isOpen;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String openTooltip;
  final String closeTooltip;
  final double expandedWidth;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topRight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: isOpen
            ? Material(
                key: const ValueKey('settings-map-search-open'),
                elevation: 3,
                color: theme.colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: expandedWidth,
                  height: 48,
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('settings-map-search-close-button'),
                        tooltip: closeTooltip,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: onClose,
                        icon: const Icon(Icons.close, size: 24),
                      ),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('settings-map-search-field'),
                          controller: controller,
                          focusNode: focusNode,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: hintText,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.only(right: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _MapOverlayButton(
                key: const ValueKey('settings-map-search-button'),
                tooltip: openTooltip,
                icon: Icons.search,
                onPressed: onOpen,
              ),
      ),
    );
  }
}

class _SearchResultsCard extends StatelessWidget {
  const _SearchResultsCard({
    required this.maxWidth,
    required this.results,
    required this.noResultsLabel,
    required this.typeLabelBuilder,
    required this.onSelected,
  });

  final double maxWidth;
  final List<_MapSearchEntry> results;
  final String noResultsLabel;
  final String Function(_MapSearchEntry entry) typeLabelBuilder;
  final ValueChanged<_MapSearchEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 280),
        child: results.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Text(noResultsLabel, style: theme.textTheme.bodyMedium),
              )
            : ListView.separated(
                key: const ValueKey('settings-map-search-results'),
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: results.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = results[index];
                  return ListTile(
                    key: ValueKey('settings-map-search-result-${entry.id}'),
                    dense: true,
                    title: Text(entry.title),
                    subtitle: entry.subtitle == null
                        ? Text(typeLabelBuilder(entry))
                        : Text(
                            '${typeLabelBuilder(entry)} · ${entry.subtitle!}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => onSelected(entry),
                  );
                },
              ),
      ),
    );
  }
}

enum _MapSearchEntryKind { stamm, district, boundary, dioceseMarker, federal }

class _MapSearchEntry {
  _MapSearchEntry.boundary(DioceseBoundary boundary)
    : this._(boundary: boundary, kind: _MapSearchEntryKind.boundary);

  _MapSearchEntry.marker(StammMapMarker marker)
    : this._(marker: marker, kind: _kindFromMarker(marker));

  const _MapSearchEntry._({this.boundary, this.marker, required this.kind});

  final DioceseBoundary? boundary;
  final StammMapMarker? marker;
  final _MapSearchEntryKind kind;

  String get id => boundary?.id ?? marker!.id;

  String get title => boundary?.name ?? marker!.name;

  String? get subtitle {
    if (marker == null) {
      return null;
    }

    final address = marker!.formattedAddress.trim();
    if (address.isNotEmpty) {
      return address;
    }

    final city = marker!.city.trim();
    if (city.isNotEmpty) {
      return city;
    }

    return null;
  }

  int? matchScore(String query) {
    final titleScore = _scoreText(title, query);
    if (titleScore != null) {
      return titleScore;
    }

    int? bestScore;
    for (final text in _additionalSearchTexts) {
      final score = _scoreText(text, query);
      if (score == null) {
        continue;
      }
      final nextScore = score + 2;
      if (bestScore == null || nextScore < bestScore) {
        bestScore = nextScore;
      }
    }
    return bestScore;
  }

  Iterable<String> get _additionalSearchTexts sync* {
    if (boundary != null) {
      final website = boundary!.website?.trim() ?? '';
      if (website.isNotEmpty) {
        yield website;
      }
      return;
    }

    if (marker == null) {
      return;
    }

    final markerValue = marker!;
    final address = markerValue.formattedAddress.trim();
    if (address.isNotEmpty) {
      yield address;
    }

    final city = markerValue.city.trim();
    if (city.isNotEmpty) {
      yield city;
    }

    final postalCode = markerValue.postalCode.trim();
    if (postalCode.isNotEmpty) {
      yield postalCode;
    }

    final website = markerValue.website.trim();
    if (website.isNotEmpty) {
      yield website;
    }
  }

  static int? _scoreText(String candidate, String query) {
    final normalizedCandidateVariants = _searchVariants(candidate);
    final normalizedQueryVariants = _searchVariants(query);

    for (final normalizedQuery in normalizedQueryVariants) {
      for (final normalizedCandidate in normalizedCandidateVariants) {
        if (normalizedCandidate.startsWith(normalizedQuery)) {
          return 0;
        }
      }
    }

    for (final normalizedQuery in normalizedQueryVariants) {
      for (final normalizedCandidate in normalizedCandidateVariants) {
        if (normalizedCandidate.contains(normalizedQuery)) {
          return 1;
        }
      }
    }

    return null;
  }

  static _MapSearchEntryKind _kindFromMarker(StammMapMarker marker) {
    switch (marker.category) {
      case StammMapMarkerCategory.district:
        return _MapSearchEntryKind.district;
      case StammMapMarkerCategory.diocese:
        return _MapSearchEntryKind.dioceseMarker;
      case StammMapMarkerCategory.federal:
        return _MapSearchEntryKind.federal;
      case StammMapMarkerCategory.standard:
        return _MapSearchEntryKind.stamm;
    }
  }

  static Set<String> _searchVariants(String raw) {
    final variants = <String>{};

    void addVariant(String value) {
      final collapsed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (collapsed.isEmpty) {
        return;
      }
      variants.add(collapsed);

      final withoutSpaces = collapsed.replaceAll(' ', '');
      if (withoutSpaces.isNotEmpty) {
        variants.add(withoutSpaces);
      }
    }

    addVariant(_normalizeSearchText(raw, expandUmlauts: true));
    addVariant(_normalizeSearchText(raw, expandUmlauts: false));
    return variants;
  }

  static String _normalizeSearchText(
    String raw, {
    required bool expandUmlauts,
  }) {
    var normalized = raw.trim().toLowerCase();

    const expandedReplacements = {'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss'};
    const compactReplacements = {'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss'};

    final replacements = expandUmlauts
        ? expandedReplacements
        : compactReplacements;
    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });

    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return normalized;
  }
}
