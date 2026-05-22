import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/map_tile_cache_service.dart';
import 'statistics_dummy_data.dart';

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
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.7,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class StatisticsKpiRow extends StatelessWidget {
  const StatisticsKpiRow({super.key, required this.items});

  final List<StatisticsKpiItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(child: _KpiTile(item: items[i])),
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
  const _KpiTile({required this.item});

  final StatisticsKpiItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Text(
              item.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: item.highlight ? theme.colorScheme.primary : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              textAlign: TextAlign.center,
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

  final List<LegendDatum> items;

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

  final List<LegendDatum> items;

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
          child: CustomPaint(
            painter: _PieLegendPainter(items: items),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: StatisticsLegendList(items: items)),
      ],
    );
  }
}

class _PieLegendPainter extends CustomPainter {
  _PieLegendPainter({required this.items});

  final List<LegendDatum> items;

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

  final List<LegendDatum> items;

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

  final LegendDatum item;
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
            Expanded(child: Text(item.label, style: theme.textTheme.bodyMedium)),
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

  final List<StammGroupItem> items;
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        child: Icon(item.icon, size: 18, color: item.stageColor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 1),
                          Text(item.stageLabel, style: theme.textTheme.bodySmall),
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

class StatisticsOptInCard extends StatelessWidget {
  const StatisticsOptInCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.public,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bundesweite Statistik',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Noch nicht freigeschaltet. Fuer diesen Bereich ist ein explizites Opt-in erforderlich.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Was dein Stamm spaeter beitraegt:',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const _BulletLine(text: 'Anzahl aktiver Mitglieder pro Stufe'),
            const _BulletLine(text: 'Altersverteilung in Gruppen (keine Einzeldaten)'),
            const _BulletLine(text: 'Anzahl Leitende'),
            const SizedBox(height: 12),
            Text(
              'Hinweis: Kein Skip-Pfad. Ohne Opt-in bleibt dieser Bereich gesperrt.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.lock),
                label: const Text('Opt-in folgt in Phase 2'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

class StatisticsMapCard extends StatelessWidget {
  const StatisticsMapCard({
    super.key,
    required this.title,
    required this.markers,
  });

  final String title;
  final List<LatLng> markers;

  @override
  Widget build(BuildContext context) {
    return StatisticsCard(
      title: title,
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 180,
          child: _StatisticsPlaceholderMap(markers: markers),
        ),
      ),
    );
  }
}

class _StatisticsPlaceholderMap extends StatelessWidget {
  const _StatisticsPlaceholderMap({required this.markers});

  final List<LatLng> markers;

  @override
  Widget build(BuildContext context) {
    final center = markers.isEmpty
        ? const LatLng(51.2000, 6.6900)
        : markers.first;
    final bounds = markers.length > 1
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(markers),
            padding: const EdgeInsets.all(24),
            maxZoom: 14,
          )
        : null;

    return Stack(
      children: [
        FlutterMap(
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
            TileLayer(
              urlTemplate: MapTileCacheService.tileUrlTemplate,
              userAgentPackageName: MapTileCacheService.userAgentPackageName,
              maxZoom: 17,
            ),
            MarkerLayer(
              markers: [
                for (final point in markers)
                  Marker(
                    point: point,
                    width: 34,
                    height: 34,
                    child: const _MarkerPin(),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('Dummy-Marker', style: TextStyle(fontSize: 11)),
            ),
          ),
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
