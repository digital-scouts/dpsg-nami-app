import 'package:flutter/material.dart';

class GroupFilterItem {
  final String keyName;
  final Color? chipColor;
  final IconData? iconData;
  final String? semanticLabel;
  final String label;

  const GroupFilterItem({
    required this.keyName,
    required this.label,
    this.chipColor,
    this.iconData,
    this.semanticLabel,
  });
}

class GroupFilterBar extends StatefulWidget {
  final List<GroupFilterItem> items;
  final Set<String> selectedKeys;
  final ValueChanged<Set<String>> onChanged;
  final EdgeInsetsGeometry padding;

  const GroupFilterBar({
    super.key,
    required this.items,
    required this.selectedKeys,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8),
  });

  @override
  State<GroupFilterBar> createState() => _GroupFilterBarState();
}

class _GroupFilterBarState extends State<GroupFilterBar> {
  /// Hoehe ausserhalb des Headers, wenn der Aufrufer keine vorgibt.
  static const double _chipHeight = 34;
  static const double _chipSpacing = 8;
  static const double _fadeWidth = 24;

  bool _fadeStart = false;
  bool _fadeEnd = false;

  /// Blendet die Raender aus, an denen weitere Chips folgen.
  bool _handleMetrics(ScrollMetrics metrics) {
    final fadeStart = metrics.extentBefore > 0.5;
    final fadeEnd = metrics.extentAfter > 0.5;
    if (fadeStart != _fadeStart || fadeEnd != _fadeEnd) {
      setState(() {
        _fadeStart = fadeStart;
        _fadeEnd = fadeEnd;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Eine Zeile, horizontal scrollbar: die Header-Hoehe bleibt unabhaengig
    // von Anzahl und Laenge der Chips gleich.
    final list = ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      itemCount: widget.items.length,
      separatorBuilder: (_, _) => const SizedBox(width: _chipSpacing),
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return Center(
          child: _buildChip(
            context,
            item,
            isActive: widget.selectedKeys.contains(item.keyName),
          ),
        );
      },
    );

    return Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Im Header gibt die Zeile die Hoehe fest vor, sonst Chip-Hoehe.
          return SizedBox(
            height: constraints.hasTightHeight
                ? constraints.maxHeight
                : _chipHeight,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (notification) =>
                  _handleMetrics(notification.metrics),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) =>
                    _handleMetrics(notification.metrics),
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => _fadeShader(bounds),
                  child: list,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Shader _fadeShader(Rect bounds) {
    final fade = bounds.width <= 0
        ? 0.0
        : (_fadeWidth / bounds.width).clamp(0.0, 0.5);
    return LinearGradient(
      colors: [
        _fadeStart ? Colors.transparent : Colors.black,
        Colors.black,
        Colors.black,
        _fadeEnd ? Colors.transparent : Colors.black,
      ],
      stops: [0, fade, 1 - fade, 1],
    ).createShader(bounds);
  }

  Widget _buildChip(
    BuildContext context,
    GroupFilterItem item, {
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    final semanticLabel = item.semanticLabel ?? '${item.keyName} Filter';
    final accentColor = item.chipColor ?? theme.colorScheme.primary;
    final chipBackgroundColor = isActive
        ? accentColor.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.3 : 0.12,
          )
        : theme.colorScheme.surface;
    final chipBorderColor = isActive
        ? accentColor
        : theme.colorScheme.outline.withValues(alpha: 0.55);
    final chipTextColor = isActive ? accentColor : theme.colorScheme.onSurface;

    return Semantics(
      label: semanticLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          final next = Set<String>.from(widget.selectedKeys);
          if (isActive) {
            next.remove(item.keyName);
          } else {
            next.add(item.keyName);
          }
          widget.onChanged(next);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: chipBackgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: chipBorderColor, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.iconData != null) ...[
                Icon(item.iconData, size: 15, color: chipTextColor),
              ] else ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              // In der scrollbaren Zeile ist die Breite unbegrenzt; sehr
              // lange Namen kuerzt die Obergrenze.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: chipTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
