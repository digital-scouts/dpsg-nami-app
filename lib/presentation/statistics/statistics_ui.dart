import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/map_recenter_button.dart';
import 'statistics_snapshot_builder.dart';
import '../widgets/karten_quellenangabe.dart';
import '../widgets/mobile_daten_hinweis.dart';

class StatisticsCard extends StatelessWidget {
  const StatisticsCard({
    super.key,
    required this.title,
    required this.child,
    this.padding,
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatisticsSectionHeader(title: title),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _StatisticsSectionHeader extends StatelessWidget {
  const _StatisticsSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 0.9,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class StatisticsKpiRow extends StatelessWidget {
  const StatisticsKpiRow({super.key, required this.items, this.dense = false});

  final List<StatisticsKpiItem> items;

  /// Flache, einzeilige Kacheln, die die vorgegebene Hoehe ausfuellen,
  /// z. B. im Seiten-Header.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: dense
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(
            child: _KpiTile(item: items[i], dense: dense),
          ),
          if (i < items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class StatisticsKpiItem {
  const StatisticsKpiItem({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.item, required this.dense});

  final StatisticsKpiItem item;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle =
        (dense ? theme.textTheme.titleMedium : theme.textTheme.headlineSmall)
            ?.copyWith(
              fontWeight: FontWeight.w700,
              color: item.highlight ? theme.colorScheme.primary : null,
            );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: dense
            ? const EdgeInsets.symmetric(horizontal: 8)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (dense)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(item.value, maxLines: 1, style: valueStyle),
              )
            else
              Text(item.value, style: valueStyle),
            if (!dense) const SizedBox(height: 4),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: dense ? 1 : null,
              overflow: dense ? TextOverflow.ellipsis : null,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class StatisticsLegendList extends StatelessWidget {
  const StatisticsLegendList({super.key, required this.items});

  final List<StatisticsLegendItem> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, item) => sum + item.value);
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final item in items) ...[
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.label, style: theme.textTheme.bodyMedium),
              ),
              Text(
                '${item.value} (${_percent(item.value, total)}%)',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          if (item != items.last) const SizedBox(height: 8),
        ],
      ],
    );
  }

  static int _percent(int value, int total) {
    if (total <= 0) {
      return 0;
    }
    return ((value / total) * 100).round();
  }
}

class StatisticsPieLegend extends StatelessWidget {
  const StatisticsPieLegend({super.key, required this.items});

  final List<StatisticsLegendItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 128,
          height: 128,
          child: CustomPaint(painter: _PieLegendPainter(items: items)),
        ),
        const SizedBox(width: 16),
        Expanded(child: StatisticsLegendList(items: items)),
      ],
    );
  }
}

class _PieLegendPainter extends CustomPainter {
  _PieLegendPainter({required this.items});

  final List<StatisticsLegendItem> items;

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold<int>(0, (sum, item) => sum + item.value);
    if (total <= 0) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide / 2;
    final innerRadius = outerRadius * 0.54;
    final rect = Rect.fromCircle(center: center, radius: outerRadius);
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    final paint = Paint()..style = PaintingStyle.fill;
    var startAngle = -1.57079632679;

    for (final item in items) {
      final sweep = (item.value / total) * 6.28318530718;
      paint.color = item.color;
      final path = ui.Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle, sweep, false)
        ..close();
      canvas.drawPath(path, paint);
      startAngle += sweep;
    }

    canvas.drawOval(
      innerRect,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _PieLegendPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}

class StatisticsBarList extends StatelessWidget {
  const StatisticsBarList({super.key, required this.items});

  final List<StatisticsLegendItem> items;

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<int>(0, (m, e) => e.value > m ? e.value : m);

    return Column(
      children: [
        for (final item in items) ...[
          _BarRow(item: item, maxValue: maxValue),
          if (item != items.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.item, required this.maxValue});

  final StatisticsLegendItem item;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final widthFactor = maxValue <= 0 ? 0.0 : (item.value / maxValue);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(item.label, style: theme.textTheme.bodyMedium),
            ),
            Text('${item.value}', style: theme.textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: widthFactor,
                  child: ColoredBox(color: item.color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class StatisticsGroupList extends StatelessWidget {
  const StatisticsGroupList({
    super.key,
    required this.items,
    required this.onOpenGroup,
  });

  final List<StatisticsGroupItem> items;
  final ValueChanged<String> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final item in items) ...[
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onOpenGroup(item.id),
            child: Ink(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: item.stageBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          item.icon,
                          size: 18,
                          color: item.stageColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 1),
                          Text(
                            item.stageLabel,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.memberCount}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (item != items.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class StatisticsMapCard extends StatelessWidget {
  const StatisticsMapCard({
    super.key,
    required this.title,
    required this.markers,
    this.stammLocation,
  });

  final String title;
  final List<LatLng> markers;
  final LatLng? stammLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatisticsSectionHeader(title: title),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 180,
              child: StatisticsMap(
                markers: markers,
                stammLocation: stammLocation,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Karte mit Wohnorten und Stammesheim; auch von der Standorte-Kachel genutzt.
class StatisticsMap extends StatefulWidget {
  const StatisticsMap({super.key, required this.markers, this.stammLocation});

  final List<LatLng> markers;
  final LatLng? stammLocation;

  @override
  State<StatisticsMap> createState() => _StatisticsMapState();
}

class _StatisticsMapState extends State<StatisticsMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenterMap(List<LatLng> points) {
    if (points.length > 1) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(28),
          maxZoom: 14,
        ),
      );
      return;
    }

    if (points.isNotEmpty) {
      _mapController.move(points.first, 12, id: 'recenter');
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      ...widget.markers,
      if (widget.stammLocation != null) widget.stammLocation!,
    ];
    final center = points.isEmpty
        ? const LatLng(51.2000, 6.6900)
        : points.first;
    final bounds = points.length > 1
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(24),
            maxZoom: 14,
          )
        : null;

    return Stack(
      children: [
        KartenKacheln(
          trigger: 'statistics_map_tiles',
          maxZoom: 17,
          builder: (context, kacheln) => FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12,
              minZoom: 3,
              maxZoom: 17,
              initialCameraFit: bounds,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              kacheln,
              MarkerLayer(
                markers: [
                  for (final point in widget.markers)
                    Marker(
                      point: point,
                      width: 34,
                      height: 34,
                      child: const _MarkerPin(),
                    ),
                  if (widget.stammLocation != null)
                    Marker(
                      point: widget.stammLocation!,
                      width: 38,
                      height: 38,
                      child: const _StammPin(),
                    ),
                ],
              ),
              const KartenQuellenangabe(),
            ],
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: MapRecenterButton(onTap: () => _recenterMap(points)),
        ),
      ],
    );
  }
}

class _MarkerPin extends StatelessWidget {
  const _MarkerPin();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.location_on, color: Color(0xFFCC1F2F), size: 26);
  }
}

class _StammPin extends StatelessWidget {
  const _StammPin();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.home, color: Color(0xFF1565C0), size: 22);
  }
}
