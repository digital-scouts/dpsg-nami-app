import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/maps/stamm_map_marker.dart';

class StammClusterLayer extends StatelessWidget {
  const StammClusterLayer({
    super.key,
    required this.markers,
    required this.currentZoom,
    this.minVisibleZoom = 0,
    this.onMarkerTap,
  });

  final List<StammMapMarker> markers;
  final double currentZoom;
  final double minVisibleZoom;
  final ValueChanged<StammMapMarker>? onMarkerTap;

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty || currentZoom < minVisibleZoom) {
      return const SizedBox.shrink();
    }

    final markersById = {for (final marker in markers) marker.id: marker};

    final clusterMarkers = markers
        .map((marker) {
          return Marker(
            key: ValueKey(marker.id),
            point: LatLng(marker.latitude, marker.longitude),
            width: 28,
            height: 28,
            child: _StammMarkerPin(color: _colorFor(marker.category)),
          );
        })
        .toList(growable: false);

    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        markers: clusterMarkers,
        maxClusterRadius: 48,
        size: const Size(31, 31),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(48),
        maxZoom: 18,
        disableClusteringAtZoom: 17,
        showPolygon: false,
        onMarkerTap: onMarkerTap == null
            ? null
            : (marker) {
                final tappedMarker = _resolveMarker(marker, markersById);
                if (tappedMarker != null) {
                  onMarkerTap!(tappedMarker);
                }
              },
        builder: (context, markers) {
          final category = _resolveClusterCategory(markers, markersById);
          final color = _colorFor(category);
          return _ClusterBubble(
            count: markers.length,
            color: color,
            foregroundColor: _foregroundColorFor(color),
          );
        },
      ),
    );
  }

  StammMapMarker? _resolveMarker(
    Marker marker,
    Map<String, StammMapMarker> markersById,
  ) {
    final key = marker.key;
    if (key is ValueKey<String>) {
      return markersById[key.value];
    }
    if (key is ValueKey) {
      return markersById[key.value?.toString() ?? ''];
    }
    return null;
  }

  StammMapMarkerCategory _resolveClusterCategory(
    List<Marker> markers,
    Map<String, StammMapMarker> markersById,
  ) {
    var hasFederal = false;
    var hasDiocese = false;
    var hasDistrict = false;
    var hasStandard = false;

    for (final marker in markers) {
      final stammMarker = _resolveMarker(marker, markersById);
      switch (stammMarker?.category) {
        case StammMapMarkerCategory.federal:
          hasFederal = true;
        case StammMapMarkerCategory.diocese:
          hasDiocese = true;
        case StammMapMarkerCategory.district:
          hasDistrict = true;
        case StammMapMarkerCategory.standard:
        case null:
          hasStandard = true;
      }
    }

    if (hasStandard) {
      return StammMapMarkerCategory.standard;
    }

    if (hasDistrict) {
      return StammMapMarkerCategory.district;
    }

    if (hasDiocese) {
      return StammMapMarkerCategory.diocese;
    }

    if (hasFederal) {
      return StammMapMarkerCategory.federal;
    }

    return StammMapMarkerCategory.standard;
  }

  Color _colorFor(StammMapMarkerCategory category) {
    switch (category) {
      case StammMapMarkerCategory.district:
        return const Color(0xFFF9A825);
      case StammMapMarkerCategory.diocese:
        return const Color(0xFFC62828);
      case StammMapMarkerCategory.federal:
        return const Color(0xFF2E7D32);
      case StammMapMarkerCategory.standard:
        return const Color(0xFF1565C0);
    }
  }

  Color _foregroundColorFor(Color color) {
    return color.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;
  }
}

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({
    required this.count,
    required this.color,
    required this.foregroundColor,
  });

  final int count;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        count.toString(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StammMarkerPin extends StatelessWidget {
  const _StammMarkerPin({required this.color});

  static const String _assetPath = 'assets/images/lilie.svg';

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SvgPicture.asset(
        _assetPath,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
